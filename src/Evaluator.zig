const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const ast = @import("ast.zig");
const Value = ast.Value;
const Cons = ast.Cons;
const RuntimeError = ast.RuntimeError;
const builtin = @import("builtin.zig");
const Memory = @import("Memory.zig");

const Evaluator = @This();

memory: *Memory,
current_scope: *Scope,

pub fn init(memory: *Memory) !Evaluator {
    var global_scope = try memory.createScope(null);

    try global_scope.put("nil", Value.nil);
    try global_scope.put("true", Value{ .boolean = true });
    try global_scope.put("false", Value{ .boolean = false });

    try global_scope.put("+", Value{ .builtin = &builtin.add });
    try global_scope.put("*", Value{ .builtin = &builtin.mul });
    try global_scope.put("-", Value{ .builtin = &builtin.sub });
    try global_scope.put("/", Value{ .builtin = &builtin.div });
    try global_scope.put(">", Value{ .builtin = &builtin.gt });
    try global_scope.put("<", Value{ .builtin = &builtin.lt });
    try global_scope.put(">=", Value{ .builtin = &builtin.gte });
    try global_scope.put("<=", Value{ .builtin = &builtin.lte });
    try global_scope.put("head", Value{ .builtin = &builtin.head });
    try global_scope.put("tail", Value{ .builtin = &builtin.tail });
    try global_scope.put("cons", Value{ .builtin = &builtin.cons });
    try global_scope.put("list", Value{ .builtin = &builtin.list });
    try global_scope.put("eval", Value{ .builtin = &builtin.eval });
    try global_scope.put("eq?", Value{ .builtin = &builtin.eq_pred });

    try global_scope.put("quote", Value{ .specialform = &builtin.quote });
    try global_scope.put("apply", Value{ .specialform = &builtin.apply });
    try global_scope.put("def", Value{ .specialform = &builtin.def });
    try global_scope.put("cond", Value{ .specialform = &builtin.cond });
    try global_scope.put("fn", Value{ .specialform = &builtin.function });

    return .{
        .memory = memory,
        .current_scope = global_scope,
    };
}

pub fn evaluate(self: *Evaluator, value: Value) RuntimeError!Value {
    switch (value) {
        .boolean, .string, .int, .nil, .builtin, .specialform, .function => return value,
        .ident => |ident| return self.current_scope.get(ident.items) orelse Value.nil,
        .cons => |cons| {
            const op = try self.evaluate(cons.head);

            if (op == .specialform) {
                return op.specialform(self, cons.tail);
            }

            // Evaluate function arguments into a new cons list
            var args: Value = Value.nil;
            var cur = cons;
            while (true) {
                if (cur.tail == .nil) break;
                if (cur.tail != .cons) return RuntimeError.ListExpected;

                const res = try self.evaluate(cur.tail.cons.head);
                const cell = try self.memory.createCons(res, Value.nil);
                switch (args) {
                    .nil => {
                        args = Value{ .cons = cell };
                    },
                    .cons => |c| {
                        // TODO: keep a reference to the last element instead
                        c.pushBack(Value{ .cons = cell });
                    },
                    else => return RuntimeError.ListExpected,
                }
                cur = cur.tail.cons;
            }

            if (op == .function) {
                const return_scope = self.current_scope;
                const scope = try self.memory.createScope(op.function.parent_scope);
                self.current_scope = scope;
                // TODO: Destroy old scope (if not part of a closure)
                defer self.current_scope = return_scope;

                var curParam = op.function.parameters;
                var curArg = args;
                while (true) {
                    if (curParam != .cons and curArg != .cons) {
                        // End of args
                        break;
                    } else if (curParam != .cons or curArg != .cons) {
                        // Wrong number of args
                        return RuntimeError.InvalidArguments;
                    } else {
                        if (curParam.cons.head != .ident) return RuntimeError.InvalidArguments;
                        try self.current_scope.put(curParam.cons.head.ident.items, curArg.cons.head);
                    }
                    curParam = curParam.cons.tail;
                    curArg = curArg.cons.tail;
                }

                return self.evaluate(op.function.body);
            }

            if (op == .builtin) return op.builtin(self, args);

            return RuntimeError.FunctionExpected;
        },
    }
}

pub const Scope = struct {
    symbol_table: std.StringHashMap(Value),
    parent: ?*Scope,

    pub fn init(alloc: std.mem.Allocator, parent: ?*Scope) !Scope {
        return Scope{ .symbol_table = std.StringHashMap(Value).init(alloc), .parent = parent };
    }

    pub fn get(self: *Scope, key: []const u8) ?Value {
        var cur = self;
        while (true) {
            const res = cur.symbol_table.get(key);
            if (res != null) return res;
            if (cur.parent == null) return null;
            cur = cur.parent.?;
        }
    }

    pub fn put(self: *Scope, key: []const u8, value: Value) !void {
        try self.symbol_table.put(key, value);
    }

    pub fn format(self: Scope, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        var iter = self.symbol_table.iterator();
        while (iter.next()) |entry| {
            try writer.print("- {s}: {}\n", .{ entry.key_ptr.*, entry.value_ptr });
        }
        // Uncomment for recursive printing
        // try writer.print("\n{?}", .{self.parent});
    }
};

fn testEvaluator(src: []const u8, expected: Value) !void {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var memory = Memory.init(alloc);
    var lexer = Lexer{ .buffer = src, .alloc = alloc };
    var parser = Parser{ .lexer = &lexer, .memory = &memory };
    var evaluator = try Evaluator.init(&memory);
    try testing.expect(Value.eql(try evaluator.evaluate(try parser.next() orelse Value.nil), expected));
}

fn testEvaluatorStrings(src1: []const u8, src2: []const u8) !void {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var memory1 = Memory.init(alloc);
    var lexer1 = Lexer{ .buffer = src1, .alloc = alloc };
    var parser1 = Parser{ .lexer = &lexer1, .memory = &memory1 };
    var evaluator1 = try Evaluator.init(&memory1);

    var memory2 = Memory.init(alloc);
    var lexer2 = Lexer{ .buffer = src2, .alloc = alloc };
    var parser2 = Parser{ .lexer = &lexer2, .memory = &memory2 };
    var evaluator2 = try Evaluator.init(&memory2);

    try testing.expect(Value.eql(
        try evaluator1.evaluate(try parser1.next() orelse Value.nil),
        try evaluator2.evaluate(try parser2.next() orelse Value.nil),
    ));
}

test "evaluate cons" {
    try testEvaluatorStrings("(list 1 2 3)", "(cons 1 (cons 2 (cons 3 nil)))");
}

test "evaluate head/tail" {
    try testEvaluator("(head (tail (list 1 2 3)))", Value{ .int = 2 });
}

test "evaluate add" {
    try testEvaluator("(+ 1 2 3)", Value{ .int = 6 });
}

test "evaluate def" {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var memory = Memory.init(alloc);
    var lexer = Lexer{ .buffer = "(def a 123)", .alloc = alloc };
    var parser = Parser{ .lexer = &lexer, .memory = &memory };
    var evaluator = try Evaluator.init(&memory);

    _ = try evaluator.evaluate(try parser.next() orelse Value.nil);
    try testing.expectEqual(evaluator.current_scope.get("a"), Value{ .int = 123 });
}
