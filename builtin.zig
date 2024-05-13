const std = @import("std");

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
