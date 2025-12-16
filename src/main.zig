const std = @import("std");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    _ = args;


    std.debug.print("Hello World!", .{});
}