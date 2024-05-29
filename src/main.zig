const std = @import("std");
const heap = std.heap;
const debug = std.debug;
const process = std.process;
const fs = std.fs;

const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const Evaluator = @import("Evaluator.zig");
const ast = @import("ast.zig");
const Cons = ast.Cons;
const Value = ast.Value;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var args = process.args();
    _ = args.skip();
    const file_path = args.next().?;
    // TODO: use std.io.bufferedReader
    const src = try fs.cwd().readFileAlloc(alloc, file_path, 1024);

    var lexer = Lexer{
        .buffer = src,
        .alloc = alloc,
    };
    var parser = Parser{ .lexer = &lexer, .alloc = alloc };
    var evaluator = try Evaluator.init(alloc);

    while (try parser.next()) |value| {
        debug.print("> {}\n", .{value});
        debug.print("{!}\n\n", .{evaluator.evaluate(value)});
    }
}
