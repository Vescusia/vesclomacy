const std = @import("std");

const lib = @import("root.zig");

const parser = @import("parser.zig");
const sorted_list = @import("sorted_list.zig");


fn countSupport(cells: parser.Cells, supported: lib.NameT) usize {
    var total: usize = 0;

    for (cells.items) |cell| {
        if (cell.action != .Support) continue;
        if (lib.nToI(cell.action.Support.who) == lib.nToI(supported)) total += 1;
    }

    return total;
}


pub fn solve(cells: parser.Cells) void {
    // check for moves that abort a convoy (and the move that should be convoyed)
    for (cells.items) |mover| {
        if (mover.action != .Move) continue;

        for (cells.items) |*convoyer| {
            if (convoyer.action != .Convoy or !mover.alsoWantsToBeAt(convoyer.*)) continue;

            // the move that wants to be convoyed will also be aborted
            const convoyed = convoyer.action.Convoy.from;
            if (cells.get(lib.nToI(convoyed))) |wants_convoy| {
                wants_convoy.action = .{ .Aborted = .{ .who = mover.name } };
            }

            convoyer.action = .{ .Aborted = .{ .who = mover.name } };
        }
    }

    // check for moves that abort supports
    for (cells.items) |mover| {
        if (mover.action != .Move) continue;

        for (cells.items) |*supporter| {
            if (supporter.action != .Support or !mover.alsoWantsToBeAt(supporter.*)) continue;

            supporter.action = .{ .Aborted = .{ .who = mover.name } };
        }
    }

    // now, every support is valid.
    // count supports for moves, then
    //  bounce moves with too little support,
    //   reevaluate bounced moves as holds
    //    reevaluate bounced moves as holds
    //      ...
    //  flee holds/aborted's with too little support,
    //  done
    var reevaluate = true;

    while (reevaluate) {
        reevaluate = false;

        for (cells.items) |*mover| {
            if (mover.action != .Move) continue;

            for (cells.items) |*holder| {
                if (!mover.alsoWantsToBeAt(holder.*) or mover.eq(holder.*)) continue;
                if (holder.action != .Hold and holder.action != .Aborted) continue;

                const mover_support = countSupport(cells, mover.name);
                const holder_support = if (holder.action == .Aborted) 0 else countSupport(cells, holder.name);

                if (mover_support <= holder_support) {
                    mover.action = .{ .Aborted = .{ .who = holder.name } };
                    // we have to reevaluate this new abort again (it might be moved upon!)
                    reevaluate = true;
                }
                else {
                    holder.action = .{ .Flee = .{ .who = mover.name } };
                }
            }
        }
    }
}

test "basic0" {
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
        \\aeg conv smy gre
        \\eas move aeg
    ;

    var cells = try parser.parseActions(text, std.testing.allocator);
    defer cells.deinit(std.testing.allocator);

    solve(cells);
}
