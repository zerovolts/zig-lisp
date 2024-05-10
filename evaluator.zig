const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const Cons = parser.Cons;
const Value = parser.Value;

pub const Runtime = struct {
    alloc: mem.Allocator,

    pub fn evaluate(self: Runtime, value: Value) !Value {
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
                const op = try self.evaluate(cons.value);
                var args: Value = Value.nil;

                var cur = cons;
                while (true) {
                    switch (cur.next) {
                        .cons => |next| {
                            const res = try self.evaluate(next.value);
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
                                else => return error.ArgsMustBeAList,
                            }
                            cur = next;
                        },
                        .nil => break,
                        else => return error.MustBeAList,
                    }
                }
                switch (op) {
                    .builtin => |builtin| return builtin(args),
                    else => return error.FirstElementMustBeAFunction,
                }
            },
        }
    }
};

fn builtin_head(args: Value) !Value {
    switch (args) {
        .cons => |cons| {
            switch (cons.value) {
                .cons => |v| return v.value,
                else => return error.RuntimeError,
            }
        },
        else => return error.RuntimeError,
    }
}

fn builtin_tail(args: Value) !Value {
    switch (args) {
        .cons => |cons| {
            switch (cons.value) {
                .cons => |v| return v.next,
                else => return error.RuntimeError,
            }
        },
        else => return error.RuntimeError,
    }
}

fn builtin_list(args: Value) !Value {
    return args;
}

fn builtin_add(args: Value) !Value {
    var arg = args;
    var total: i64 = 0;
    while (true) {
        switch (arg) {
            .cons => |cons| {
                switch (cons.value) {
                    .int => |i| {
                        total += i;
                    },
                    else => return error.RuntimeError,
                }
                arg = cons.next;
            },
            .nil => break,
            else => return error.RuntimeError,
        }
    }
    return Value.int(total);
}

fn testEvaluator(src: []const u8, expected: Value) !void {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var token_iter = lexer.TokenIterator{ .buffer = src, .alloc = alloc };
    var expr_iter = parser.Parser{ .tokenIter = &token_iter, .alloc = alloc };
    var runtime = Runtime{ .alloc = alloc };
    try testing.expect(Value.eql(try runtime.evaluate(try expr_iter.next() orelse Value.nil), expected));
}

test "evaluate head/tail" {
    try testEvaluator("(head (tail (list 1 2 3)))", Value.int(2));
}

test "evaluate add" {
    try testEvaluator("(+ 1 2 3)", Value.int(6));
}
