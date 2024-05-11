const std = @import("std");
const heap = std.heap;
const debug = std.debug;

const lexer = @import("lexer.zig");
const Parser = @import("Parser.zig");
const evaluator = @import("evaluator.zig");
const ast = @import("ast.zig");
const Cons = ast.Cons;
const Value = ast.Value;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();

    var tokenIter = lexer.TokenIterator{
        .buffer = "(+ 3 4 5)",
        .alloc = gpa_alloc,
    };
    var parser = Parser{ .tokenIter = &tokenIter, .alloc = gpa_alloc };
    var r = evaluator.Runtime{ .alloc = gpa_alloc };
    while (try parser.next()) |value| {
        debug.print("{!}\n", .{r.evaluate(value)});
        // debug.print("{}", .{value});
    }
}
