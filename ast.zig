const std = @import("std");
const meta = std.meta;

const Evaluator = @import("Evaluator.zig");

pub const RuntimeError = error{
    OutOfMemory,
    InvalidArguments,
    ListExpected,
    FunctionExpected,
};

pub const Value = union(enum) {
    nil,
    ident: std.ArrayList(u8),
    string: std.ArrayList(u8),
    int: i64,
    cons: *Cons,
    builtin: *const fn (*Evaluator, Value) RuntimeError!Value,

    pub fn eql(a: Value, b: Value) bool {
        const TagType = meta.Tag(Value);
        if (@as(TagType, a) != @as(TagType, b)) return false;

        switch (a) {
            .nil => return true,
            .ident => return meta.eql(a.ident.items, b.ident.items),
            .string => return meta.eql(a.string.items, b.string.items),
            .int => return a.int == b.int,
            .cons => return Cons.eql(a.cons, b.cons),
            .builtin => return a.builtin == b.builtin,
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
            .builtin => try writer.print("<builtin>", .{}),
            .cons => try writer.print("({})", .{self.cons}),
        }
    }
};

pub const Cons = struct {
    head: Value,
    tail: Value,

    pub fn init(head: Value, tail: Value) Cons {
        return .{ .head = head, .tail = tail };
    }

    pub fn pushBack(self: *Cons, value: Value) void {
        var cursor = self;
        while (true) {
            switch (cursor.tail) {
                .cons => cursor = cursor.tail.cons,
                else => break,
            }
        }
        cursor.tail = value;
    }

    pub fn eql(a: *Cons, b: *Cons) bool {
        return Value.eql(a.head, b.head) and Value.eql(a.tail, b.tail);
    }

    pub fn format(self: Cons, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        try writer.print("{} . {}", .{ self.head, self.tail });
    }
};
