const std = @import("std");
const heap = std.heap;
const testing = std.testing;

const Evaluator = @import("Evaluator.zig");
const Memory = @import("Memory.zig");
const ast = @import("ast.zig");
const Value = ast.Value;
const Cons = ast.Cons;
const Function = ast.Function;
const RuntimeError = ast.RuntimeError;

pub fn head(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, null);
    return try arg0.expectListElement(0, null);
}

pub fn tail(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, null);
    if (arg0 != .cons) return RuntimeError.ListExpected;
    return arg0.cons.tail;
}

pub fn cons(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, null);
    const arg1 = try args.expectListElement(1, null);
    const cell = try evaluator.memory.createCons(arg0, arg1);
    return Value{ .cons = cell };
}

pub fn list(_: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();
    return args;
}

pub fn add(_: *Evaluator, args: Value) RuntimeError!Value {
    var arg = args;
    var total: i64 = 0;
    while (true) {
        if (arg == .nil) break;
        const value = try arg.expectListElement(0, .int);
        total += value.int;
        arg = arg.cons.tail;
    }
    return Value{ .int = total };
}

pub fn mul(_: *Evaluator, args: Value) RuntimeError!Value {
    var arg = args;
    var total: i64 = 1;
    while (true) {
        if (arg == .nil) break;
        const value = try arg.expectListElement(0, .int);
        total *= value.int;
        arg = arg.cons.tail;
    }
    return Value{ .int = total };
}

pub fn sub(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    return Value{ .int = arg0.int - arg1.int };
}

pub fn div(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    // TODO: Handle division by zero.
    return Value{ .int = @divTrunc(arg0.int, arg1.int) };
}

pub fn eval(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    return evaluator.evaluate(try args.expectListElement(0, null));
}

pub fn eq_pred(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, null);
    const arg1 = try args.expectListElement(1, null);
    return Value{ .boolean = Value.eql(arg0, arg1) };
}

pub fn gt(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    return Value{ .boolean = arg0.int > arg1.int };
}

pub fn lt(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    return Value{ .boolean = arg0.int < arg1.int };
}

pub fn gte(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    return Value{ .boolean = arg0.int >= arg1.int };
}

pub fn lte(_: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .int);
    const arg1 = try args.expectListElement(1, .int);
    return Value{ .boolean = arg0.int <= arg1.int };
}

pub fn apply(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    const arg1 = try args.expectListElement(1, null);
    // TODO: check args.cons (it was implicitly checked in previous check)
    args.cons.tail = try evaluator.evaluate(arg1);
    return try evaluator.evaluate(args);
}

pub fn quote(_: *Evaluator, args: Value) RuntimeError!Value {
    return try args.expectListElement(0, null);
}

test quote {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var memory = Memory.init(alloc);
    var evaluator = try Evaluator.init(&memory);
    const actual = try quote(&evaluator, try ast.list(alloc, &[_]Value{try ast.list(alloc, &[_]Value{ Value{ .int = 1 }, Value{ .int = 2 }, Value{ .int = 3 } })}));
    const expected = try ast.list(alloc, &[_]Value{ Value{ .int = 1 }, Value{ .int = 2 }, Value{ .int = 3 } });
    try testing.expect(Value.eql(actual, expected));
}

pub fn def(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    const arg0 = try args.expectListElement(0, .ident);
    const arg1 = try args.expectListElement(1, null);
    // TODO: Should this be global scope?
    try evaluator.current_scope.put(arg0.ident.items, try evaluator.evaluate(arg1));
    return Value.nil;
}

pub fn cond(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertList();
    var cur = args;
    while (cur == .cons) : (cur = cur.cons.tail) {
        const case = cur.getListElementUnsafe(0);
        try case.assertListLen(2);
        if (Value.eql(try evaluator.evaluate(case.getListElementUnsafe(0)), Value{ .boolean = true })) {
            return try evaluator.evaluate(case.getListElementUnsafe(1));
        }
    }
    return Value.nil;
}

pub fn function(evaluator: *Evaluator, args: Value) RuntimeError!Value {
    try args.assertListLen(2);
    const parameters = args.cons.head;
    // Parameters must be a list or nil
    if (parameters != .nil) try parameters.assertList();
    // TODO: assert that body is a well-formed list or primitive value
    const body = args.cons.tail.cons.head;

    const func = try evaluator.memory.createFunction(parameters, body, evaluator.current_scope);
    return Value{ .function = func };
}
