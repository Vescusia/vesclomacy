const std = @import("std");

const parser = @import("parser.zig");
const solver = @import("solver.zig");


pub fn main(init: std.process.Init) !void {
    // const perm_alloc = init.arena.allocator();
    const gpa = init.gpa;
    const io = init.io;

    // get stdout
    var stdout_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &stdout_buf);

    // get args
    var args = try init.minimal.args.iterateAllocator(gpa);
    _ = args.next();  // skip path to program
    defer args.deinit();
    const cwd = std.Io.Dir.cwd();

    // check if a file path is specified
    const file_path = if (args.next()) |fp| fp
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
            break :fd cwd.openFile(io, file_path, .{});
        }
        else {
            break :fd std.Io.Dir.openFileAbsolute(io, file_path, .{});
        }
    } catch |err| {
        std.log.err("File '{s}' could not be opened.", .{file_path});
        return err;
    };

    // get file size
    const size: usize = @truncate(
        (try file.stat(io)).size
    );
    if (size > (1 << 10)) std.log.warn("File size is {} B!", .{size});

    // read file completely into memory :)
    const buf = try gpa.alloc(u8, size);
    defer gpa.free(buf);

    var reader = file.reader(io, buf);
    try reader.interface.fill(size);

    // parse text
    var parsed = try parser.parseActions(buf, gpa);
    defer parsed.deinit(gpa);

    try stdout.interface.print("\nIN:\n", .{});
    for (parsed.items) |cell| {
        try stdout.interface.print("  {f}\n", .{cell});
    }

    // solve positions
    solver.solve(parsed);

    // print results
    try stdout.interface.print("\nOUT:\n", .{});
    for (parsed.items) |cell| {
        switch (cell.action) {
            .Aborted => |by| try stdout.interface.print("  [STOP] {f}  by  {f}\n", .{cell.name, by.who}),
            .Flee => |by| try stdout.interface.print("  [FLEE] {f}  by  {f}\n", .{cell.name, by.who}),
            else => try stdout.interface.print("  [DONE] {f}\n", .{cell})
        }
    }
    try stdout.interface.flush();
}