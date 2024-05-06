const std = @import("std");
const heap = std.heap;
const debug = std.debug;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const evaluator = @import("evaluator.zig");
const Cons = parser.Cons;
const Value = parser.Value;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();

    var tokenIter = lexer.TokenIterator{
        .buffer = "(+ 3 4 5)",
        .alloc = gpa_alloc,
    };
    var p = parser.Parser{ .tokenIter = &tokenIter, .alloc = gpa_alloc };
    var r = evaluator.Runtime{ .alloc = gpa_alloc };
    while (try p.next()) |value| {
        debug.print("{!}\n", .{r.evaluate(value)});
        // debug.print("{}", .{value});
    }
}
