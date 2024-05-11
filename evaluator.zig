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

pub const Evaluator = struct {
    alloc: mem.Allocator,

    pub fn evaluate(self: Evaluator, value: Value) RuntimeError!Value {
        switch (value) {
            .string, .int, .nil, .builtin => return value,
            .ident => |ident| {
                if (mem.eql(u8, ident.items, "+")) {
                    return Value{ .builtin = &builtin_add };
                }
                if (mem.eql(u8, ident.items, "head")) {
                    return Value{ .builtin = &builtin_head };
                }
                if (mem.eql(u8, ident.items, "tail")) {
                    return Value{ .builtin = &builtin_tail };
                }
                if (mem.eql(u8, ident.items, "list")) {
                    return Value{ .builtin = &builtin_list };
                }
                return Value.nil;
            },
            .cons => |cons| {
                const op = try self.evaluate(cons.head);
                var args: Value = Value.nil;

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
                return op.builtin(args);
            },
        }
    }
};

fn builtin_head(args: Value) RuntimeError!Value {
    if (args != .cons) return RuntimeError.ListExpected;
    if (args.cons.head != .cons) return RuntimeError.ListExpected;
    return args.cons.head.cons.head;
}

fn builtin_tail(args: Value) RuntimeError!Value {
    if (args != .cons) return RuntimeError.ListExpected;
    if (args.cons.head != .cons) return RuntimeError.ListExpected;
    return args.cons.head.cons.tail;
}

fn builtin_list(args: Value) RuntimeError!Value {
    return args;
}

fn builtin_add(args: Value) RuntimeError!Value {
    var arg = args;
    var total: i64 = 0;
    while (true) {
        if (arg == .nil) break;
        if (arg != .cons) return RuntimeError.ListExpected;
        if (arg.cons.head != .int) return RuntimeError.IntegerExpected;

        total += arg.cons.head.int;
        arg = arg.cons.tail;
    }
    return Value{ .int = total };
}

fn testEvaluator(src: []const u8, expected: Value) !void {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer = Lexer{ .buffer = src, .alloc = alloc };
    var expr_iter = Parser{ .lexer = &lexer, .alloc = alloc };
    var evaluator = Evaluator{ .alloc = alloc };
    try testing.expect(Value.eql(try evaluator.evaluate(try expr_iter.next() orelse Value.nil), expected));
}

test "evaluate head/tail" {
    try testEvaluator("(head (tail (list 1 2 3)))", Value{ .int = 2 });
}

test "evaluate add" {
    try testEvaluator("(+ 1 2 3)", Value{ .int = 6 });
}
