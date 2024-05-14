const std = @import("std");
const meta = std.meta;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const Evaluator = @import("Evaluator.zig");

pub const RuntimeError = error{
    OutOfMemory,
    InvalidArguments,
    ListExpected,
    FunctionExpected,
};

pub const Value = union(enum) {
    nil,
    boolean: bool,
    ident: std.ArrayList(u8),
    string: std.ArrayList(u8),
    int: i64,
    cons: *Cons,
    builtin: *const fn (*Evaluator, Value) RuntimeError!Value,
    // A builtin that takes unevaluated arguments.
    specialform: *const fn (*Evaluator, Value) RuntimeError!Value,

    pub fn eql(a: Value, b: Value) bool {
        const TagType = meta.Tag(Value);
        if (@as(TagType, a) != @as(TagType, b)) return false;

        switch (a) {
            .nil => return true,
            .boolean => return a.boolean == b.boolean,
            .ident => return meta.eql(a.ident.items, b.ident.items),
            .string => return meta.eql(a.string.items, b.string.items),
            .int => return a.int == b.int,
            .cons => return Cons.eql(a.cons, b.cons),
            .builtin => return a.builtin == b.builtin,
            .specialform => return a.specialform == b.specialform,
        }
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) anyerror!void {
        _ = fmt;
        _ = options;
        switch (self) {
            .nil => try writer.print("Nil", .{}),
            .boolean => try writer.print("Boolean[{}]", .{self.boolean}),
            .ident => try writer.print("Ident[{s}]", .{self.ident.items}),
            .string => try writer.print("String[\"{s}\"]", .{self.string.items}),
            .int => try writer.print("Int[{}]", .{self.int}),
            .builtin => try writer.print("<builtin>", .{}),
            .specialform => try writer.print("<specialform>", .{}),
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

pub fn list(alloc: mem.Allocator, items: []const Value) !Value {
    var root: Value = Value.nil;
    var i = items.len;
    while (i > 0) {
        i -= 1;
        const item = items[i];
        const cell = try alloc.create(Cons);
        cell.* = Cons.init(item, root);
        root = Value{ .cons = cell };
    }
    return root;
}

test list {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const actual = try list(
        arena.allocator(),
        &[_]Value{ Value{ .int = 1 }, Value{ .int = 2 }, Value{ .int = 3 } },
    );

    var cell3 = Cons.init(Value{ .int = 3 }, Value.nil);
    var cell2 = Cons.init(Value{ .int = 2 }, Value{ .cons = &cell3 });
    var cell1 = Cons.init(Value{ .int = 1 }, Value{ .cons = &cell2 });
    const expected = Value{ .cons = &cell1 };

    try testing.expect(Value.eql(actual, expected));
}
