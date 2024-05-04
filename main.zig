const std = @import("std");
const heap = std.heap;
const debug = std.debug;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const Cons = parser.Cons;
const Value = parser.Value;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();

    var tokenIter = lexer.TokenIterator{
        .buffer = "(+ 1 (- 2 3))",
        .alloc = gpa_alloc,
    };
    var p = parser.Parser{ .tokenIter = &tokenIter, .alloc = gpa_alloc };
    while (try p.next()) |value| {
        debug.print("{}\n", .{value});
    }
}
