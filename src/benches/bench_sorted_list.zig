const std = @import("std");

const sorted_list = @import("sorted_list");


// define consts for bench
const NUM_ITEMS = 1 << 16;
const NUM_INSERTS = 1 << 20;


pub fn main(init: std.process.Init) !void {
    // define (permanent) allocator
    const arena = init.arena.allocator();

    // get args for the benched function
    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.next();  // skip path to program
    const operand = args.next().?;

    // define the type we will collect
    const Item = u64;
    
    // and an rng
    var prng = std.Random.DefaultPrng.init(981234081230872890);
    const random = prng.random();

    // for the lists
    if (!std.mem.eql(u8, operand, "MAP")) {
        // define the sorted list type
        const SortedList = sorted_list.SortedList(Item, Item, sorted_list.id(Item));
        //var list = try SortedList.init(alloc, NUM_ITEMS);
        var list = SortedList.empty;
    
        // define the benched function
        var run_fn = &SortedList.insertBS;
        if (std.mem.eql(u8, operand, "IS")) {
            run_fn = SortedList.insertIS;
        }
        
        // fill array with random numbers
        for (0..NUM_ITEMS) |_| {
            try run_fn(&list, arena, random.int(Item));
        }
    
        // benchmark insert
        for (0..NUM_ITEMS) |_| {
            _ = list.pop();
            try run_fn(&list, arena, random.int(Item));
        }
    }
    // for the map
    else {
        const context = struct {
            pub fn hash(_: anytype, val: Item) u32 {
                return @truncate(val);
            }

            pub fn eql(_: anytype, val0: Item, val1: Item) bool {
                return val0 == val1;
            }
        };

        const Map = std.HashMap(Item, void, context, 80);
        var map = Map.init(arena);

        // fill with random numbers
        for (0..NUM_ITEMS) |_| {
            try map.put(random.int(Item), {});
        }

        // benchmark insert
        for (0..NUM_ITEMS) |_| {
            var iter = map.keyIterator();
            const key = iter.next().?.*;
            _ = map.remove(key);
            try map.put(random.int(Item), {});
        }
    }
}