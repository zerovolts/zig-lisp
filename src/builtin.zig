const std = @import("std");
const heap = std.heap;
const testing = std.testing;

const Evaluator = @import("Evaluator.zig");
const ast = @import("ast.zig");
const Value = ast.Value;
const Cons = ast.Cons;
const Function = ast.Function;
const RuntimeError = ast.RuntimeError;

pub fn head(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(1);
    return args.cons.head.cons.head;
}

pub fn tail(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(1);
    return args.cons.head.cons.tail;
}

pub fn cons(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    const cell = try evaluator.alloc.create(Cons);
    cell.* = Cons.init(args.cons.head, args.cons.tail.cons.head);
    return Value{ .cons = cell };
}

pub fn list(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();
    return args;
}

pub fn add(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();

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

pub fn mul(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();

    var arg = args;
    var total: i64 = 1;
    while (true) {
        if (arg == .nil) break;
        if (arg.cons.head != .int) return RuntimeError.InvalidArguments;

        total *= arg.cons.head.int;
        arg = arg.cons.tail;
    }
    return Value{ .int = total };
}

pub fn sub(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    return Value{ .int = args.cons.head.int - args.cons.tail.cons.head.int };
}

pub fn div(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    // TODO: Handle division by zero.
    return Value{ .int = @divTrunc(args.cons.head.int, args.cons.tail.cons.head.int) };
}

pub fn eval(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(1);
    return evaluator.evaluate(args.cons.head);
}

pub fn eq_pred(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    return Value{ .boolean = Value.eql(args.cons.head, args.cons.tail.cons.head) };
}

pub fn gt(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    return Value{ .boolean = args.cons.head.int > args.cons.tail.cons.head.int };
}

pub fn lt(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    return Value{ .boolean = args.cons.head.int < args.cons.tail.cons.head.int };
}

pub fn gte(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    return Value{ .boolean = args.cons.head.int >= args.cons.tail.cons.head.int };
}

pub fn lte(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    if (args.cons.head != .int) return RuntimeError.InvalidArguments;
    if (args.cons.tail.cons.head != .int) return RuntimeError.InvalidArguments;
    return Value{ .boolean = args.cons.head.int <= args.cons.tail.cons.head.int };
}

pub fn apply(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    args.cons.tail = try evaluator.evaluate(args.cons.tail.cons.head);
    return try evaluator.evaluate(args);
}

pub fn quote(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(1);
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
    try args.assertListLen(2);
    if (args.cons.head != .ident) return RuntimeError.InvalidArguments;
    const value = try evaluator.evaluate(args.cons.tail.cons.head);

    // TODO: Should this be global scope?
    try evaluator.current_scope.put(args.cons.head.ident.items, value);
    return Value.nil;
}

pub fn cond(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();
    var cur = args;
    while (cur == .cons) : (cur = cur.cons.tail) {
        const case = cur.cons.head;
        try case.assertListLen(2);
        if (Value.eql(try evaluator.evaluate(case.cons.head), Value{ .boolean = true })) {
            return try evaluator.evaluate(case.cons.tail.cons.head);
        }
    }
    return Value.nil;
}

pub fn function(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    const parameters = args.cons.head;
    // TODO: assert that params is a list of symbols or nil
    const body = args.cons.tail.cons.head;
    // TODO: assert that body is a list or value

    const func = try evaluator.alloc.create(Function);
    func.* = .{ .parameters = parameters, .body = body, .parent_scope = evaluator.current_scope };
    return Value{ .function = func };
}
