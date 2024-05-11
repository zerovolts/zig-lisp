const std = @import("std");
const mem = std.mem;

const Lexer = @import("Lexer.zig");
const ast = @import("ast.zig");
const Value = ast.Value;
const Cons = ast.Cons;

const Parser = @This();

lexer: *Lexer,
alloc: mem.Allocator,

pub fn next(self: Parser) !?Value {
    if (try self.lexer.next()) |token| {
        switch (token) {
            // Outermost parens don't have any effect on the output.
            .open_paren => {
                const res = try self.parseExpr();
                // Eat the matching closing paren.
                _ = try self.lexer.next();
                return res;
            },
            .int, .ident, .str => return try tokenToValue(token),
            else => return error.InvalidToken,
        }
    } else {
        return null;
    }
}

fn parseExpr(self: Parser) !Value {
    while (try self.lexer.next()) |token| {
        switch (token) {
            .open_paren => {
                const cell = try self.alloc.create(Cons);
                cell.* = Cons.init(try self.parseExpr(), try self.parseExpr());
                return Value{ .cons = cell };
            },
            .close_paren => return Value.nil,
            .int, .ident, .str => {
                const cell = try self.alloc.create(Cons);
                cell.* = Cons.init(try tokenToValue(token), try self.parseExpr());
                return Value{ .cons = cell };
            },
        }
    }
    return error.NoMoreTokens;
}

fn tokenToValue(token: Lexer.Token) !Value {
    switch (token) {
        .ident => |value| return Value{ .ident = value },
        .str => |value| return Value{ .string = value },
        .int => |value| return Value{ .int = value },
        else => return error.UnsupportedTokenType,
    }
}

const testing = std.testing;
const heap = std.heap;

fn testParser(src: []const u8, expected: Value) !void {
    // TODO: use testing.allocator
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer = Lexer{ .buffer = src, .alloc = alloc };
    var parser = Parser{ .lexer = &lexer, .alloc = alloc };
    try testing.expect(Value.eql(try parser.next() orelse Value.nil, expected));
}

test "parse integer" {
    try testParser("123", Value{ .int = 123 });
}

test "parse list" {
    var cell3 = Cons.init(Value{ .int = 3 }, Value.nil);
    var cell2 = Cons.init(Value{ .int = 2 }, Value{ .cons = &cell3 });
    var cell1 = Cons.init(Value{ .int = 1 }, Value{ .cons = &cell2 });
    const expected = Value{ .cons = &cell1 };

    try testParser("(1 2 3)", expected);
}

test "parse nested list tail" {
    var cell3 = Cons.init(Value{ .int = 3 }, Value.nil);
    var cell2 = Cons.init(Value{ .int = 2 }, Value{ .cons = &cell3 });
    var cellNested = Cons.init(Value{ .cons = &cell2 }, Value.nil);
    var cell1 = Cons.init(Value{ .int = 1 }, Value{ .cons = &cellNested });
    const expected = Value{ .cons = &cell1 };

    try testParser("(1 (2 3))", expected);
}

test "parse nested list head" {
    var cell3 = Cons.init(Value{ .int = 3 }, Value.nil);
    var cell2 = Cons.init(Value{ .int = 2 }, Value.nil);
    var cell1 = Cons.init(Value{ .int = 1 }, Value{ .cons = &cell2 });
    var cellNested = Cons.init(Value{ .cons = &cell1 }, Value{ .cons = &cell3 });
    const expected = Value{ .cons = &cellNested };

    try testParser("((1 2) 3)", expected);
}
