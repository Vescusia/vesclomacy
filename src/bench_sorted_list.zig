const std = @import("std");

const sorted_list = @import("sorted_list.zig");


pub fn main() !void {
    // define consts for bench
    const num_items = 1 << 14;
    const num_inserts = 1 << 20;

    // define gpa
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const alloc = gpa.allocator();

    // get args for the benched function
    const args = try std.process.argsAlloc(alloc);
    const operand = args[1];

    // define the type we will collect
    const Item = u64;
    
    // and an rng
    var rng = std.crypto.random;
    
    // for the lists
    if (!std.mem.eql(u8, operand, "MAP")) {
        // define the sorted list type
        const SortedList = sorted_list.SortedList(Item, Item, sorted_list.id(Item));
        //var list = try SortedList.init(alloc, num_items);
        var list = SortedList.empty;
    
        // define the benched function
        var run_fn = &SortedList.insertBS;
        if (std.mem.eql(u8, operand, "IS")) {
            run_fn = SortedList.insertIS;
        }
        
        // fill array with random numbers
        for (0..num_items) |_| {
            try run_fn(&list, alloc, rng.int(Item));
        }
    
        // benchmark insert
        for (0..num_inserts) |_| {
            _ = list.pop();
            try run_fn(&list, alloc, rng.int(Item));
        }
    }
    // for the map
    else {
        const context = struct {
            pub fn hash(_: anytype, val: Item) u32 {
                return @truncate(val);
            }

            pub fn eql(_: anytype, val0: Item, val1: Item, _: usize) bool {
                return val0 == val1;
            }
        };

        const Map = std.ArrayHashMap(Item, void, context, false);
        var map = Map.init(alloc);

        // fill with random numbers
        for (0..num_items) |_| {
            try map.put(rng.int(Item), {});
        }

        // benchmark insert
        for (0..num_inserts) |_| {
            var iter = map.iterator();
            const key = iter.next().?.key_ptr.*;
            _ = map.swapRemove(key);
            try map.put(rng.int(Item), {});
        }
    }
}