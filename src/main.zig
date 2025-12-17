const std = @import("std");

const parser = @import("parser.zig");
const solver = @import("solver.zig");


pub fn main() !void {
    // create gpa
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // get stdout
    var stdout_buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buf);

    // get args
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    const cwd = std.fs.cwd();

    // check if a file path is specified
    const file_path = if (args.len > 1) args[1]
    else {
        std.log.err(
            \\First Argument has to be a valid path to the text file containing a Diplomacy state.
            \\Usage: vesclomancy <FILE_PATH>
        ,
            .{});
        return error.MissingArgument;
    };

    // open file
    std.log.info("Opening file '{s}'", .{file_path});
    const file = fd: {
        if (!std.fs.path.isAbsolute(file_path)) {
            break :fd cwd.openFile(file_path, .{});
        }
        else {
            break :fd std.fs.openFileAbsolute(file_path, .{});
        }
    } catch |err| {
        std.log.err("Provided path '{s}' could not be opened: {}", .{file_path, err});
        return err;
    };

    // read file completely into memory :)
    const size = (try file.stat()).size;
    if (size > 1 << 10) std.log.warn("File size is {} B!", .{size});

    const buf = try alloc.alloc(u8, size);
    defer alloc.free(buf);

    var reader = file.reader(buf);
    try reader.interface.fill(size);

    // parse text
    var parsed = try parser.parseActions(buf, alloc);
    defer parsed.deinit(alloc);

    try stdout.interface.print("\nIN:\n", .{});
    for (parsed.items) |cell| {
        try stdout.interface.print("  {f}\n", .{cell});
    }

    // solve positions
    try solver.solve(parsed, alloc);

    // print results
    try stdout.interface.print("\nOUT:\n", .{});
    for (parsed.items) |cell| {
        switch (cell.action) {
            .Aborted => |by| try stdout.interface.print("  [STOP] {s}  by  {s}\n", .{cell.name, by.who}),
            .Flee => |by| try stdout.interface.print("  [FLEE] {s}  by  {s}\n", .{cell.name, by.who}),
            else => try stdout.interface.print("  [DONE] {f}\n", .{cell})
        }
    }
    try stdout.interface.flush();
}