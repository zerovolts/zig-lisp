const std = @import("std");
const heap = std.heap;
const debug = std.debug;

const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const evaluator = @import("evaluator.zig");
const ast = @import("ast.zig");
const Cons = ast.Cons;
const Value = ast.Value;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();

    var lexer = Lexer{
        .buffer = "(+ 3 4 5)",
        .alloc = gpa_alloc,
    };
    var parser = Parser{ .lexer = &lexer, .alloc = gpa_alloc };
    var r = evaluator.Runtime{ .alloc = gpa_alloc };
    while (try parser.next()) |value| {
        debug.print("{!}\n", .{r.evaluate(value)});
        // debug.print("{}", .{value});
    }
}
