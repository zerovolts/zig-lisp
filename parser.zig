const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const debug = std.debug;

const lexer = @import("lexer.zig");

pub const Value = union(enum) {
    nil,
    ident: std.ArrayList(u8),
    string: std.ArrayList(u8),
    int: i64,
    cons: *Cons,

    pub fn int(value: i64) Value {
        return .{
            .int = value,
        };
    }

    pub fn ident(value: std.ArrayList(u8)) Value {
        return .{
            .ident = value,
        };
    }

    pub fn string(value: std.ArrayList(u8)) Value {
        return .{
            .string = value,
        };
    }

    pub fn cons(value: *Cons) Value {
        return .{
            .cons = value,
        };
    }

    fn eql(a: Value, b: Value) bool {
        const TagType = meta.Tag(Value);
        if (@as(TagType, a) != @as(TagType, b)) return false;

        switch (a) {
            .nil => return true,
            .ident => return meta.eql(a.ident.items, b.ident.items),
            .string => return meta.eql(a.string.items, b.string.items),
            .int => return a.int == b.int,
            .cons => return Cons.eql(a.cons, b.cons),
        }
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        switch (self) {
            .nil => try writer.print("Nil", .{}),
            .ident => try writer.print("Ident[{s}]", .{self.ident.items}),
            .string => try writer.print("String[\"{s}\"]", .{self.string.items}),
            .int => try writer.print("Int[{}]", .{self.int}),
            .cons => try writer.print("({})", .{self.cons}),
        }
    }
};

pub const Cons = struct {
    value: Value,
    next: Value,

    pub fn init(value: Value, next: Value) Cons {
        return .{
            .value = value,
            .next = next,
        };
    }

    pub fn pushBack(self: *Cons, value: Value) void {
        var cursor = self;
        while (true) {
            switch (self.next) {
                .cons => cursor = self.next.cons,
                else => break,
            }
        }
        cursor.next = value;
    }

    pub fn eql(a: *Cons, b: *Cons) bool {
        return Value.eql(a.value, b.value) and Value.eql(a.next, b.next);
    }

    pub fn format(self: Cons, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        try writer.print("{} . {}", .{ self.value, self.next });
    }
};

pub const Parser = struct {
    tokenIter: *lexer.TokenIterator,
    alloc: mem.Allocator,

    pub fn next(self: Parser) !?Value {
        if (try self.tokenIter.next()) |token| {
            switch (token) {
                // Outermost parens don't have any effect on the output.
                .open_paren => {
                    const res = try self.parseExpr();
                    // Eat the matching closing paren.
                    _ = try self.tokenIter.next();
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
        while (try self.tokenIter.next()) |token| {
            switch (token) {
                .open_paren => {
                    const cell = try self.alloc.create(Cons);
                    cell.* = Cons.init(try self.parseExpr(), try self.parseExpr());
                    return Value.cons(cell);
                },
                .close_paren => return Value.nil,
                .int, .ident, .str => {
                    const cell = try self.alloc.create(Cons);
                    cell.* = Cons.init(try tokenToValue(token), try self.parseExpr());
                    return Value.cons(cell);
                },
            }
        }
        return error.NoMoreTokens;
    }
};

fn tokenToValue(token: lexer.Token) !Value {
    switch (token) {
        .ident => |value| return Value.ident(value),
        .str => |value| return Value.string(value),
        .int => |value| return Value.int(value),
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

    var token_iter = lexer.TokenIterator{ .buffer = src, .alloc = alloc };
    var parser = Parser{ .tokenIter = &token_iter, .alloc = alloc };
    try testing.expect(Value.eql(try parser.next() orelse Value.nil, expected));
}

test "parse integer" {
    try testParser("123", Value.int(123));
}

test "parse list" {
    var cell3 = Cons.init(Value.int(3), Value.nil);
    var cell2 = Cons.init(Value.int(2), Value.cons(&cell3));
    var cell1 = Cons.init(Value.int(1), Value.cons(&cell2));
    const expected = Value.cons(&cell1);

    try testParser("(1 2 3)", expected);
}

test "parse nested list tail" {
    var cell3 = Cons.init(Value.int(3), Value.nil);
    var cell2 = Cons.init(Value.int(2), Value.cons(&cell3));
    var cellNested = Cons.init(Value.cons(&cell2), Value.nil);
    var cell1 = Cons.init(Value.int(1), Value.cons(&cellNested));
    const expected = Value.cons(&cell1);

    try testParser("(1 (2 3))", expected);
}

test "parse nested list head" {
    var cell3 = Cons.init(Value.int(3), Value.nil);
    var cell2 = Cons.init(Value.int(2), Value.nil);
    var cell1 = Cons.init(Value.int(1), Value.cons(&cell2));
    var cellNested = Cons.init(Value.cons(&cell1), Value.cons(&cell3));
    const expected = Value.cons(&cellNested);

    try testParser("((1 2) 3)", expected);
}
