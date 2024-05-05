const std = @import("std");
const mem = std.mem;
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
