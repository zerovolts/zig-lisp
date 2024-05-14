const std = @import("std");
const heap = std.heap;
const testing = std.testing;

const Evaluator = @import("Evaluator.zig");
const ast = @import("ast.zig");
const Value = ast.Value;
const Cons = ast.Cons;
const RuntimeError = ast.RuntimeError;

pub fn head(_: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(1, args);
    return args.cons.head.cons.head;
}

pub fn tail(_: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(1, args);
    return args.cons.head.cons.tail;
}

pub fn cons(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(2, args);
    const cell = try evaluator.alloc.create(Cons);
    cell.* = Cons.init(args.cons.head, args.cons.tail.cons.head);
    return Value{ .cons = cell };
}

pub fn list(_: *Evaluator, args: Value) RuntimeError!Value {
    try assertList(args);
    return args;
}

pub fn add(_: *Evaluator, args: Value) RuntimeError!Value {
    try assertList(args);

    var arg = args;
    var total: i64 = 0;
    while (true) {
        if (arg == .nil) break;
        if (arg.cons.head != .int) return RuntimeError.InvalidArguments;

        total += arg.cons.head.int;
        arg = arg.cons.tail;
    }
    return Value{ .int = total };
}

pub fn eval(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(1, args);
    return evaluator.evaluate(args.cons.head);
}

pub fn apply(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(2, args);
    args.cons.tail = try evaluator.evaluate(args.cons.tail.cons.head);
    return try evaluator.evaluate(args);
}

pub fn quote(_: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(1, args);
    return args.cons.head;
}

test quote {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var evaluator = try Evaluator.init(alloc);
    const actual = try quote(&evaluator, try ast.list(alloc, &[_]Value{try ast.list(alloc, &[_]Value{ Value{ .int = 1 }, Value{ .int = 2 }, Value{ .int = 3 } })}));
    const expected = try ast.list(alloc, &[_]Value{ Value{ .int = 1 }, Value{ .int = 2 }, Value{ .int = 3 } });
    try testing.expect(Value.eql(actual, expected));
}

pub fn def(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try assertListLen(2, args);
    if (args.cons.head != .ident) return RuntimeError.InvalidArguments;
    const value = try evaluator.evaluate(args.cons.tail.cons.head);

    try evaluator.env.put(args.cons.head.ident.items, value);
    return Value.nil;
}

fn assertList(value: Value) !void {
    if (value != .cons) return RuntimeError.InvalidArguments;
    var cur = value.cons;
    while (cur.tail == .cons) {
        cur = cur.tail.cons;
    }
    if (cur.tail != Value.nil) return RuntimeError.InvalidArguments;
}

fn assertListLen(n: usize, value: Value) !void {
    // Verify that the value is a list at all.
    if (value != .cons) return RuntimeError.InvalidArguments;
    var cur = value.cons;
    for (1..n) |_| {
        if (cur.tail != .cons) return RuntimeError.InvalidArguments;
        cur = cur.tail.cons;
    }
    if (cur.tail != Value.nil) return RuntimeError.InvalidArguments;
}
