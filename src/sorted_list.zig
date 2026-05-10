const std = @import("std");


/// The identity function for Integers.
pub fn id(comptime T: type) fn (T) T {
    if (@typeInfo(T) != .int) {
        @compileError("Type 'T' has to be an Integer.");
    }

    const ctx = struct {
        fn id(x: T) T {
            return x;
        }
    };

    return ctx.id;
}


/// A List that continuously retains the property of being sorted.
///
/// This means, that finding the smallest/largest element that has been inserted is O(1).
///
/// Searching for items and inserting them (in the correct position)
/// can be done with binary search in O(log(n)).
/// However, when inserting or deleting, the underlying array has to be memmoved, which is slow.
///
/// For very small amount of items, <100, it will probably outperform the standard library HashMaps.
/// For more items, please use HashMaps.
pub fn SortedList(comptime T: type, comptime HashT: type, comptime asInt: fn(T) HashT) type {
    if (@typeInfo(HashT) != .int) {
        @compileError("Type 'IntT' has to be an Integer.");
    }

    return struct {
        items: []T,
        capacity: usize,

        const Self = @This();

        pub const empty: Self = .{
            .items = &[_]T{},
            .capacity = 0
        };

        pub fn init(alloc: std.mem.Allocator, initial_capacity: usize) std.mem.Allocator.Error!Self {
            const self = Self{
                .capacity = initial_capacity,
                .items = (try alloc.alloc(T, initial_capacity)).ptr[0..0],
            };

            return self;
        }

        fn hashAt(self: Self, idx: usize) HashT {
            return asInt(self.items[idx]);
        }

        pub fn at(self: Self, idx: usize) *T {
            return &self.items[idx];
        }

        pub fn get(self: Self, hash: HashT) ?*T {
            const search_result = self.searchRaw(hash);
            return switch (search_result) {
                .FoundAt => |idx| &self.items[idx],
                .WouldBeAt => null,
            };
        }

        /// Removes and returns the last (largest) element of the List.
        ///
        /// Asserts that at least one item is in the List.
        pub fn pop(self: *Self) T {
            std.debug.assert(self.items.len > 0);

            const item = self.items[self.items.len-1];
            self.items.len -= 1;

            return item;
        }

        pub fn removeAt(self: *Self, idx: usize) T {
            const item = self.items[idx];

            @memmove(self.items.ptr + idx, self.items[idx+1..]);
            self.items.len -= 1;

            return item;
        }

        pub fn remove(self: *Self, hash: HashT) T {
            const idx = self.contains(hash) orelse return null;

            return removeAt(idx);
        }

        /// Returns the index of 'item' if it is present in the List, otherwise 'null'.
        pub fn contains(self: Self, hash: HashT) ?usize {
            const search_result = self.searchRaw(hash);
            switch (search_result) {
                .FoundAt => |idx| return idx,
                .WouldBeAt => return null,
            }
        }

        /// Insert an Item to the list.
        /// The Item will be swapped down to its proper position (a bit like Insertion Sort).
        /// This method can be equally as performant as ``.insertBS`` for smaller lists (~< 1000 Items).
        pub fn insertIS(self: *Self, alloc: std.mem.Allocator, item: T) std.mem.Allocator.Error!void {
            try self.ensureCapacity(alloc, self.items.len + 1);

            self.items.len += 1;

            if (self.items.len == 1) {
                self.items[0] = item;
                return;
            }

            const hash = asInt(item);

            var i = self.items.len - 1;
            while (i > 0 and hash < self.hashAt(i)) : ({ i -= 1; }) {
                self.items[i] = self.items[i-1];
            }

            self.items[i] = item;
        }

        fn searchRaw(self: Self, hash: HashT)
            union(enum) { FoundAt: usize, WouldBeAt: usize }
        {
            var start_i: usize = 0;
            var end_i = self.items.len;
            var mid_i = end_i / 2;

            while (start_i < end_i) : ({ mid_i = start_i + ((end_i - start_i) / 2); }) {
                const mid = self.hashAt(mid_i);

                if (mid < hash) {
                    start_i = mid_i + 1;
                }
                else if (mid > hash) {
                    end_i = mid_i;
                }
                if (mid == hash) {
                    return .{ .FoundAt = mid_i };
                }
            }

            return .{ .WouldBeAt = mid_i };
        }

        /// Insert an Item into the List.
        /// The proper position of the Item will be determined using Binary Search,
        /// after which all items with an index greater than the determined index of the new item
        /// will be mem-moved to make space for the new item.
        pub fn insertBS(self: *Self, alloc: std.mem.Allocator, item: T) std.mem.Allocator.Error!void {
            try self.ensureCapacity(alloc, self.items.len+1);

            const pos = switch (self.searchRaw(asInt(item))) {
                .FoundAt => unreachable,
                .WouldBeAt => |idx| idx,
            };

            @memmove(self.items.ptr + pos + 1, self.items[pos..]);
            self.items.len += 1;

            self.items[pos] = item;
        }

        fn ensureCapacity(self: *Self, alloc: std.mem.Allocator, capacity: usize) std.mem.Allocator.Error!void {
            if (capacity <= self.capacity) return;

            const new_capacity = capacity * 2;
            const old_memory = self.items.ptr[0..self.capacity];

            // try to simply resize the old allocation, which would simply preserve the pointer
            if (alloc.remap(old_memory, new_capacity)) |new_memory| {
                self.items.ptr = new_memory.ptr;
                self.capacity = new_capacity;
            }
            // allocate a new array and copy over
            else {
                var new_memory = try alloc.alloc(T, new_capacity);

                @memcpy(new_memory[0..self.items.len], self.items);
                alloc.free(old_memory);

                self.items.ptr = new_memory.ptr;
                self.capacity = new_capacity;
            }
        }

        pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
            alloc.free(self.items.ptr[0..self.capacity]);
        }
    };
}

test "search" {
    const alloc = std.testing.allocator;

    var list = try SortedList(u64, u64, id(u64)).init(alloc, 16);
    defer list.deinit(alloc);

    for (0..16) |i| {
        try list.insertIS(alloc, 18-i);
    }

    for (0..16) |i| {
        try std.testing.expectEqual(i, list.contains(i+3));
    }
}

test "insertBS" {
    const alloc = std.testing.allocator;

    var list = try SortedList(u64, u64, id(u64)).init(alloc, 16);
    defer list.deinit(alloc);

    for (0..16) |i| {
        try list.insertBS(alloc, 18-i);
    }

    for (0..16) |i| {
        try std.testing.expectEqual(i, list.contains(i+3));
    }
}

test "insertIS" {
    const alloc = std.testing.allocator;

    var list = try  SortedList(u64, u64, id(u64)).init(alloc, 16);
    defer list.deinit(alloc);

    for (0..16) |i| {
        try list.insertIS(alloc, 18-i);
    }

    for (0..16) |i| {
        try std.testing.expectEqual(i, list.contains(i+3));
    }
}

test "hashedString" {
    const AsInt = struct {
        fn map(item: [3]u8) u24 {
            return @bitCast(item);
        }
    };

    const alloc = std.testing.allocator;

    var list = try SortedList([3]u8, u24, AsInt.map).init(alloc, 8);
    defer list.deinit(alloc);

    const items = [_]*const [3]u8{"txt", "pop", "bat", "xdd"};
    for (items) |item| {
        try list.insertIS(alloc, item.*);
    }
}
