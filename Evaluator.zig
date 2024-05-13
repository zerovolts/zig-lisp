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

const Evaluator = @This();

alloc: mem.Allocator,
env: std.StringHashMap(Value),

pub fn init(alloc: mem.Allocator) !Evaluator {
    var env = std.StringHashMap(Value).init(alloc);

    try env.put("nil", Value.nil);

    try env.put("+", Value{ .builtin = &builtin.add });
    try env.put("head", Value{ .builtin = &builtin.head });
    try env.put("tail", Value{ .builtin = &builtin.tail });
    try env.put("cons", Value{ .builtin = &builtin.cons });
    try env.put("list", Value{ .builtin = &builtin.list });

    try env.put("def", Value{ .specialform = &builtin.def });

    return .{
        .alloc = alloc,
        .env = env,
    };
}

pub fn evaluate(self: *Evaluator, value: Value) RuntimeError!Value {
    switch (value) {
        .string, .int, .nil, .builtin, .specialform => return value,
        .ident => |ident| return self.env.get(ident.items) orelse Value.nil,
        .cons => |cons| {
            const op = try self.evaluate(cons.head);
            var args: Value = Value.nil;

            if (op == .specialform) {
                return op.specialform(self, cons.tail);
            }

            var cur = cons;
            while (true) {
                if (cur.tail == .nil) break;
                if (cur.tail != .cons) return RuntimeError.ListExpected;

                const res = try self.evaluate(cur.tail.cons.head);
                const cell = try self.alloc.create(Cons);
                cell.* = Cons.init(res, Value.nil);
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

            if (op != .builtin) return RuntimeError.FunctionExpected;
            return op.builtin(self, args);
        },
    }
}

fn testEvaluator(src: []const u8, expected: Value) !void {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer = Lexer{ .buffer = src, .alloc = alloc };
    var parser = Parser{ .lexer = &lexer, .alloc = alloc };
    var evaluator = try Evaluator.init(alloc);
    try testing.expect(Value.eql(try evaluator.evaluate(try parser.next() orelse Value.nil), expected));
}

fn testEvaluatorStrings(src1: []const u8, src2: []const u8) !void {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer1 = Lexer{ .buffer = src1, .alloc = alloc };
    var parser1 = Parser{ .lexer = &lexer1, .alloc = alloc };
    var evaluator1 = try Evaluator.init(alloc);

    var lexer2 = Lexer{ .buffer = src2, .alloc = alloc };
    var parser2 = Parser{ .lexer = &lexer2, .alloc = alloc };
    var evaluator2 = try Evaluator.init(alloc);

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

    var lexer = Lexer{ .buffer = "(def a 123)", .alloc = alloc };
    var parser = Parser{ .lexer = &lexer, .alloc = alloc };
    var evaluator = try Evaluator.init(alloc);

    _ = try evaluator.evaluate(try parser.next() orelse Value.nil);
    try testing.expectEqual(evaluator.env.get("a"), Value{ .int = 123 });
}
