const std = @import("std");

const lib = @import("root.zig");

const parser = @import("parser.zig");
const sorted_list = @import("sorted_list.zig");


pub fn solve(cells: parser.Cells) void {
    var moves = ActionIterator{ .cells = cells, .filter = .Move };

    // check for moves that abort a convoy (and the move that should be convoyed)
    while (moves.next()) |mover| {
        const to = mover.action.Move.to;

        if (cells.get(to.int)) |convoyer| {
            if (convoyer.action != .Convoy) continue;

            const from = convoyer.action.Convoy.from;
            if (cells.get(from.int)) |convoyed| {
                std.debug.assert(convoyed.action == .Move);
                convoyed.abort(mover.name);
            }

            convoyer.abort(mover.name);
        }
    }

    // check for moves that abort supports
    moves.reset();
    while (moves.next()) |mover| {
        const to = mover.action.Move.to;

        if (cells.get(to.int)) |supporter|
            if (supporter.action == .Support)
                supporter.abort(mover.name);
    }

    // now, every support is valid.
    // count supports for moves, then
    //  bounce moves with too little support,
    //   reevaluate bounced moves as holds
    //    reevaluate bounced moves as holds
    //      ...
    //  flee holds/aborts with too little support,
    //  done

    // resolve moves where 2+ try to go to the same cell
    moves.reset();
    while (moves.next()) |main_mover| {
        const to = main_mover.action.Move.to;
        const main_supports = countSupport(cells, main_mover.name);

        var other_moves = moves.iterFromNext();
        while (other_moves.next()) |other_mover| {
            // skip if other mover is moving to different Cell
            if (other_mover.action.Move.to != to) continue;

            const other_supports = countSupport(cells, other_mover.name);

            if (main_supports >= other_supports)
                other_mover.abort(main_mover.name);

            if (other_supports >= main_supports)
                // still can bounce more movers! (this is correct because transitive)
                main_mover.abort(other_mover.name);
        }
    }

    // resolve moves to cells which are either held or aborted (forcefully held)
    var reevaluate = true;
    while (reevaluate) {
        reevaluate = false;
        moves.reset();

        while (moves.next()) |mover| {
            const to = mover.action.Move.to;

            if (cells.get(to.int)) |holder| {
                if (holder.action != .Hold and holder.action != .Aborted) continue;

                const mover_support = countSupport(cells, mover.name);
                const holder_support = if (holder.action == .Aborted) 0 else countSupport(cells, holder.name);

                if (mover_support <= holder_support) {
                    mover.abort(holder.name);
                    // we have to reevaluate this new abort again (it might be moved upon!)
                    reevaluate = true;
                }
                else
                    holder.flee(mover.name);
            }
        }
    }
}


const ActionIterator = struct {
    cells: parser.Cells,
    filter: ActionTag,
    pos: usize = 0,

    pub const ActionTag = std.meta.Tag(lib.Action);

    const Self = @This();

    pub fn next(self: *Self) ?*lib.Cell {
        while (self.pos < self.cells.items.len) {
            const cell = &self.cells.items[self.pos];
            self.pos += 1;

            if (cell.action == self.filter)
                return cell;
        }
        else return null;
    }

    pub fn reset(self: *Self) void {
        self.pos = 0;
    }

    pub fn iterFromNext(self: Self) Self {
        var new_self = self;

        // calling .next() will already increment to the next one
        // so we just do it for the initial state manually
        if (new_self.pos == 0) new_self.pos = 1;

        return new_self;
    }
};


fn countSupport(cells: parser.Cells, supported: lib.Name) usize {
    var total: usize = 0;

    var supporters = ActionIterator{.cells = cells, .filter = .Support};
    while (supporters.next()) |supporter| {
        if (supporter.action.Support.who == supported)
            total += 1;
    }

    return total;
}


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

    solve(cells);
}
