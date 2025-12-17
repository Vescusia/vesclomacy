const std = @import("std");

const lib = @import("root.zig");

const parser = @import("parser.zig");
const sorted_list = @import("sorted_list.zig");


pub fn solve(cells: parser.Cells, alloc: std.mem.Allocator) !void {
    // create a singly linked list that stores each cell by the action that it wants to perform
    // WARNING: if cells is modified (remove or insert) these buckets will be invalid!
    var action_buckets = ActionBuckets{};
    defer action_buckets.deinit(alloc);

    // insert the initial state
    for (cells.items) |*cell|
        try action_buckets.add(alloc, cell);


    // check for moves that abort a convoy (and the move that should be convoyed)
    var movers = action_buckets.iter(.Move);
    while (movers.next()) |mover| {
        const to = lib.nToI(mover.action.Move.to);

        if (cells.get(to)) |convoyer| {
            if (convoyer.action != .Convoy) continue;

            // the move that wants to be convoyed will also be aborted
            const convoyed_name = lib.nToI(convoyer.action.Convoy.from);
            if (cells.get(convoyed_name)) |convoyed|{
                std.debug.assert(convoyed.action == .Move);
                action_buckets.moveSetTo(convoyed, .abort(mover.name));
            }

            action_buckets.moveSetTo(convoyer, .abort(mover.name));
        }
    }

    // check for moves that abort supports
    movers = action_buckets.iter(.Move);
    while (movers.next()) |mover| {
        const to = lib.nToI(mover.action.Move.to);

        if (cells.get(to)) |supporter|
            if (supporter.action == .Support)
                action_buckets.moveSetTo(supporter, .abort(mover.name));
    }

    // check for moves that try to move to the same cell
    movers = action_buckets.iter(.Move);
    main: while (movers.next()) |mover| {
        var other_movers = movers.iterFromNext();

        while (other_movers.next()) |other_mover| {
            if (lib.nToI(mover.action.Move.to) == lib.nToI(other_mover.action.Move.to)) {
                const supports = countSupport(&action_buckets, mover.name);
                const other_supports = countSupport(&action_buckets, other_mover.name);

                if (supports >= other_supports)
                    other_movers.moveSetCurrentTo(.abort(mover.name));

                if (other_supports >= supports) {
                    movers.moveSetCurrentTo(.abort(other_mover.name));
                    continue :main;  // an aborted cell cannot move anymore...
                }
            }
        }
    }

    // now, every support is valid.
    // count supports for moves, then
    //  bounce moves with too little support,
    //   reevaluate bounced moves as holds
    //    reevaluate bounced moves as holds
    //      ...
    //  flee holds/aborts with too little support,
    //  done

    var reevaluate = true;
    while (reevaluate) {
        reevaluate = false;

        movers = action_buckets.iter(.Move);
        while (movers.next()) |mover| {
            const to = lib.nToI(mover.action.Move.to);

            if (cells.get(to)) |holder| {
                if (holder.action != .Hold and holder.action != .Aborted) continue;

                const mover_support = countSupport(&action_buckets, mover.name);
                const holder_support = if (holder.action == .Aborted) 0 else countSupport(&action_buckets, holder.name);

                if (mover_support <= holder_support) {
                    movers.moveSetCurrentTo(.abort(holder.name));
                    // we have to reevaluate this new abort again (it might be moved upon!)
                    reevaluate = true;
                }
                else
                    action_buckets.moveSetTo(holder, .flee(mover.name));
            }
        }
    }
}


fn countSupport(buckets: *ActionBuckets, supported: lib.NameT) usize {
    var total: usize = 0;

    var supporters = buckets.iter(.Support);
    while (supporters.next()) |supporter| {
        if (lib.nToI(supporter.action.Support.who) == lib.nToI(supported))
            total += 1;
    }

    return total;
}


const ActionBuckets = struct {
    pub const Node = struct {
        cell: *lib.Cell,
        next: ?*Node,
    };

    pub const ActionTag = std.meta.Tag(lib.Action);

    pub const num_actions = @typeInfo(ActionTag).@"enum".fields.len;
    buckets: [num_actions]?*Node = .{null} ** num_actions,

    pub fn add(self: *@This(), alloc: std.mem.Allocator, cell: *lib.Cell) !void {
        const new_node = try alloc.create(Node);
        new_node.* = Node{ .cell = cell, .next = self.bucketOf(cell.action) };

        self.buckets[@intFromEnum(cell.action)] = new_node;
    }

    pub fn bucketOf(self: @This(), of: ActionTag) ?*Node {
        return self.buckets[@intFromEnum(of)];
    }

    pub const Iterator = struct {
        bucket: ActionTag,
        parent: *ActionBuckets,
        current: ?*Node,
        previous: ?*Node = null,
        stay_one: bool = true,

        pub fn next(self: *@This()) ?*lib.Cell {
            const old_current = self.current orelse return null;

            if (self.stay_one) {
                self.stay_one = false;
                return old_current.cell;
            }

            const new_current = old_current.next orelse return null;
            self.previous = old_current;
            self.current = new_current;
            return new_current.cell;
        }

        /// Move the current Cell (returned by .next()) to the bucket 'to'
        pub fn moveCurrentTo(self: *@This(), to: ActionTag) void {
            const node = self.current orelse unreachable;

            // make sure .next() does not follow into the to bucket
            self.current = node.next;
            self.stay_one = true;

            // remove from old bucket
            if (self.previous) |prev|
                prev.next = node.next
            else
                self.parent.buckets[@intFromEnum(self.bucket)] = node.next;

            // prepend current to the new bucket
            const new_next = self.parent.bucketOf(to);
            self.parent.buckets[@intFromEnum(to)] = node;
            node.next = new_next;
        }

        /// Moves the current Cell (returned by .next()) to the bucket of 'to' and sets it's action to 'to'
        pub fn moveSetCurrentTo(self: *@This(), to: lib.Action) void {
            self.current.?.cell.action = to;
            self.moveCurrentTo(to);
        }

        fn peekNextNode(self: @This()) ?*Node {
            return (self.current orelse return null).next;
        }

        pub fn peekNext(self: @This()) ?*lib.Cell {
            return (self.peekNextNode() orelse return null).cell;
        }

        /// Create a new iterator from the next Cell onwards.
        pub fn iterFromNext(self: @This()) @This() {
            return .{
                .parent = self.parent,
                .bucket = self.bucket,
                .current = self.peekNextNode(),
                .previous = self.current,
            };
        }
    };

    /// Moves an unknown Cell of address 'unknown' from the bucket 'from' to the bucket 'to'
    ///
    /// If you are already iterating over a bucket and want to move a Cell from that Iterator,
    /// use '.moveCurrentTo'.
    pub fn moveTo(self: *@This(), unknown: *lib.Cell, from: ActionTag, to: ActionTag) void {
        var nodes = self.iter(from);

        // search through the cells until we find it
        while (nodes.next()) |cell| {
            if (unknown == cell) {
                // and move it to the new bucket
                nodes.moveCurrentTo(to);
                break;
            }
        }
        else unreachable;
    }

    /// Moves Cell at address 'unknown' from the bucket of it's action to the bucket 'to'
    /// and set's it's action to 'to'
    ///
    /// If you are already iterating over a bucket and want to move a Cell from that Iterator,
    /// use '.moveSetCurrentTo'.
    pub fn moveSetTo(self: *@This(), unknown: *lib.Cell, to: lib.Action) void {
        self.moveTo(unknown, unknown.action, to);
        unknown.action = to;
    }

    pub fn iter(self: *@This(), of: ActionTag) Iterator {
        return .{
            .parent = self,
            .bucket = of,
            .current = self.bucketOf(of),
        };
    }

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        for (self.buckets) |start| {
            var current = start;
            while (current) |node| {
                current = node.next;
                alloc.destroy(node);
            }
        }
    }
};


test "basic0" {
    const alloc = std.testing.allocator;

    const text =
        \\# bel should be forced to run away
        \\pic move bel
        \\ruh supp pic
        \\bel hold
        \\
        \\# mun bounces
        \\mun move boh
        \\sil supp mun
        \\tyr supp boh
        \\boh hold
        \\ven move tyr
        \\
        \\# both happen
        \\gal move ukr
        \\ukr move war
        \\
        \\# convoy happens
        \\smy move gre
        \\aeg conv smy
        \\eas move aeg
    ;

    const mod_text = try alloc.dupe(u8, text);
    defer alloc.free(mod_text);

    var cells = try parser.parseActions(mod_text, alloc);
    defer cells.deinit(alloc);

    try solve(cells, alloc);
}
