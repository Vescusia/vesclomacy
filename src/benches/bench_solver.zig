const std = @import("std");

const vesclomacy = @import("vesclomacy");
const parser = vesclomacy.parser;
const solver = vesclomacy.solver;


pub fn main(init: std.process.Init) !void {
    // const perm_alloc = init.arena.allocator();
    const gpa = init.gpa;
    const io = init.io;

    // get args
    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();  // skip program path
    const cwd = std.Io.Dir.cwd();

    // check if a file path is specified
    const file_path = args.next().?;

    // open file
    std.log.info("Opening file '{s}'", .{file_path});
    const file = try cwd.openFile(io, file_path, .{});

    // get file size
    const size: u32 = @truncate(
        (try file.stat(io)).size
    );
    if (size > (1 << 10)) std.log.warn("File size is {} B!", .{size});

    // read file completely into memory :)
    const buf = try gpa.alloc(u8, size);
    defer gpa.free(buf);

    var reader = file.reader(io, buf);
    try reader.interface.fill(size);

    // parse text
    const parsed = try parser.parseActions(buf, gpa);
    defer parsed.deinit(gpa);

    // buffer for solving
    var to_solve = try parser.Cells.init(gpa, parsed.items.len);
    defer to_solve.deinit(gpa);

    // solve positions
    for (0..(1 << 16)) |_| {
        @memcpy(to_solve.items.ptr, parsed.items);
        to_solve.items.len = parsed.items.len;

        solver.solve(parsed);
        _ = to_solve.at(0);
    }
}