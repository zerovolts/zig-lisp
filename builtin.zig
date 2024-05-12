const std = @import("std");

const ast = @import("ast.zig");
const Value = ast.Value;
const RuntimeError = ast.RuntimeError;

pub fn head(args: Value) RuntimeError!Value {
    if (args != .cons) return RuntimeError.ListExpected;
    if (args.cons.head != .cons) return RuntimeError.ListExpected;
    return args.cons.head.cons.head;
}

pub fn tail(args: Value) RuntimeError!Value {
    if (args != .cons) return RuntimeError.ListExpected;
    if (args.cons.head != .cons) return RuntimeError.ListExpected;
    return args.cons.head.cons.tail;
}

pub fn list(args: Value) RuntimeError!Value {
    return args;
}

pub fn add(args: Value) RuntimeError!Value {
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
