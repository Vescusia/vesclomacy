const std = @import("std");

const lib = @import("root.zig");


pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("{}\n", .{lib.board.Board});
    std.debug.print("{s}\n", .{lib.Nation.GreatBritain.toStr()});
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
