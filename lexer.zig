const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const meta = std.meta;

pub const Token = union(enum) {
    open_paren,
    close_paren,
    int: i32,
    str: std.ArrayList(u8),
    ident: std.ArrayList(u8),

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        switch (self) {
            .ident => try writer.print("Ident({s})", .{self.ident.items}),
            .str => try writer.print("Str(\"{s}\")", .{self.str.items}),
            .int => try writer.print("Int({})", .{self.int}),
            .open_paren => try writer.print("OpenParen", .{}),
            .close_paren => try writer.print("CloseParen", .{}),
        }
    }
};

pub const Lexer = struct {
    buffer: []const u8,
    index: usize = 0,
    alloc: mem.Allocator,

    pub fn next(self: *Lexer) !?Token {
        while (self.index < self.buffer.len) : (self.index += 1) {
            const ch = self.currentChar();
            switch (ch) {
                '(' => {
                    self.index += 1;
                    return Token.open_paren;
                },
                ')' => {
                    self.index += 1;
                    return Token.close_paren;
                },
                ' ', '\n' => {},
                '0'...'9' => {
                    var value: i32 = 0;
                    while (self.index < self.buffer.len) {
                        const digitValue = self.currentChar() - '0';
                        value = value * 10 + digitValue;
                        self.index += 1;
                        if (self.index >= self.buffer.len) break;
                        if (!isDigit(self.currentChar())) break;
                    }
                    return Token{ .int = value };
                },
                '"' => {
                    var value = std.ArrayList(u8).init(self.alloc);
                    self.index += 1;
                    while (self.index < self.buffer.len and self.currentChar() != '"') : (self.index += 1) {
                        try value.append(self.currentChar());
                    }
                    // Skip the closing paren.
                    self.index += 1;
                    return Token{ .str = value };
                },
                else => {
                    if (isIdentStart(ch)) {
                        var value = std.ArrayList(u8).init(self.alloc);
                        while (self.index < self.buffer.len) {
                            try value.append(self.currentChar());
                            self.index += 1;
                            if (self.index >= self.buffer.len) break;
                            if (!isIdent(self.currentChar())) break;
                        }
                        return Token{ .ident = value };
                    } else {
                        debug.print("unhandled: {c}\n", .{ch});
                        return null;
                    }
                },
            }
        }
        return null;
    }

    fn currentChar(self: Lexer) u8 {
        return self.buffer[self.index];
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlphaLower(c: u8) bool {
    return c >= 'a' and c <= 'z';
}

fn isAlphaUpper(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}

fn isAlpha(c: u8) bool {
    return isAlphaLower(c) or isAlphaUpper(c);
}

fn isAlphanumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

fn isIdentSymbol(c: u8) bool {
    return switch (c) {
        '+', '-', '.', '*', '/', '<', '=', '>', '!', '?', ':', '$', '%', '_', '&', '~', '^' => true,
        else => false,
    };
}

fn isIdentStart(c: u8) bool {
    return isAlpha(c) or isIdentSymbol(c);
}

fn isIdent(c: u8) bool {
    return isAlphanumeric(c) or isIdentSymbol(c);
}

fn testLexer(src: []const u8, expected_tokens: []const Token) !void {
    var lexer = Lexer{ .buffer = src, .alloc = testing.allocator };
    var i: usize = 0;
    while (try lexer.next()) |next| : (i += 1) {
        try testing.expect(meta.eql(next, expected_tokens[i]));
    }
}

test "lex integer" {
    try testLexer("123", &[_]Token{.{ .int = 123 }});
}

test "lex list" {
    try testLexer("(1 2 3)", &[_]Token{
        .open_paren,
        .{ .int = 1 },
        .{ .int = 2 },
        .{ .int = 3 },
        .close_paren,
    });
}

test "lex nested list" {
    try testLexer("((1 2) (3 4))", &[_]Token{
        .open_paren,
        .open_paren,
        .{ .int = 1 },
        .{ .int = 2 },
        .close_paren,
        .open_paren,
        .{ .int = 3 },
        .{ .int = 4 },
        .close_paren,
        .close_paren,
    });
}
