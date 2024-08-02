const std = @import("std");
const mem = std.mem;

const ast = @import("ast.zig");
const Cons = ast.Cons;
const Value = ast.Value;
const Function = ast.Function;
const Scope = @import("Evaluator.zig").Scope;

const Memory = @This();

alloc: mem.Allocator,

pub fn init(alloc: mem.Allocator) Memory {
    return .{
        .alloc = alloc,
    };
}

pub fn createCons(self: Memory, head: Value, tail: Value) !*Cons {
    const cell = try self.alloc.create(Cons);
    cell.* = Cons.init(head, tail);
    return cell;
}

pub fn createScope(self: Memory, parent: ?*Scope) !*Scope {
    const scope = try self.alloc.create(Scope);
    scope.* = try Scope.init(self.alloc, parent);
    return scope;
}

pub fn createFunction(
    self: Memory,
    parameters: Value,
    body: Value,
    parent_scope: *Scope,
) !*Function {
    const func = try self.alloc.create(Function);
    func.* = .{ .parameters = parameters, .body = body, .parent_scope = parent_scope };
    return func;
}
