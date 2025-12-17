// ber hold
// lon move wes
//
// tur supp lon
//
// bal conv pet den
//
// # comment
//

const std = @import("std");

const lib = @import("root.zig");
const sorted_list = @import("sorted_list.zig");


const Text = struct {
    txt: []u8,

    const Self = @This();

    pub const empty: Self = .{ .txt = &[_]u8 {} };

    pub fn from(text: []u8) Self {
        return .{
            .txt = text
        };
    }

    pub fn isEmpty(self: Self) bool {
        return self.txt.len == 0;
    }

    pub fn skipWhitespace(self: Self) Self {
        for (0.., self.txt) |i, char| {
            switch (char) {
                ' ', '\t', '\n', '\r' => continue,
                else => return from(self.txt[i..])
            }
        }
        return empty;
    }

    pub fn skipLine(self: Self) Self {
        for (0.., self.txt) |i, char| {
            if (char == '\n') {
                return from(self.txt[i+1..]);
            }
        }
        return empty;
    }

    pub fn skip(self: Self, n: usize) Self {
        return from(self.txt[n..]);
    }

    pub fn take(self: Self, comptime n: usize) [n]u8 {
        return self.txt.ptr[0..n].*;
    }

    pub fn first(self: Self) u8 {
        return self.txt[0];
    }

    pub fn lower(self: Self) void {
        for (self.txt) |*char| {
            if (char.* >= 'A' and char.* <= 'Z') char.* += ('a' - 'A');
        }
    }
};


fn acToI(action_name: [4]u8) u32 {
    return @bitCast(action_name);
}


pub const Cells = sorted_list.SortedList(lib.Cell, u24, lib.Cell.asInt);


pub fn parseActions(bytes: []u8, alloc: std.mem.Allocator) !Cells {
    var txt = Text.from(bytes).skipWhitespace();
    txt.lower();

    var cells = Cells.empty;
    errdefer cells.deinit(alloc);

    while(!txt.isEmpty()) : ({ txt = txt.skipWhitespace(); }) {
        switch (txt.first()) {
            '#' => {
                txt = txt.skipLine();
            },
            'a'...'z' => {
                const name = txt.take(3);
                txt = txt.skip(3).skipWhitespace();

                const action_str = txt.take(4);
                txt = txt.skip(4).skipWhitespace();

                // cannot switch on [4]u8 ???
                // guess we switch on u32's instead...
                const action = switch (acToI(action_str)) {
                    acToI("move".*) => mv: {
                        const to = txt.take(3); txt = txt.skip(3);
                        break :mv lib.Action{ .Move = .{ .to = to } };
                    },
                    acToI("hold".*) => lib.Action.Hold,
                    acToI("supp".*) => sup: {
                        const who = txt.take(3); txt = txt.skip(3);
                        break :sup lib.Action{ .Support = .{ .who = who } };
                    },
                    acToI("conv".*) => cv: {
                        const from = txt.take(3); txt = txt.skip(3);
                        break :cv lib.Action{ .Convoy = .{ .from = from } };
                    },
                    else => {
                        std.log.err("InvalidAction: '{s}'\n", .{&action_str});
                        return error.InvalidAction;
                    }
                };

                const cell = lib.Cell{
                    .name = name,
                    .action = action,
                };

                try cells.insertBS(alloc, cell);
            },
            else => {
                std.log.err("Unknown character: '{c}'\n", .{txt.first()});
                return error.InvalidFormat;
            }
        }
    }

    return cells;
}


test "basics" {
    const alloc = std.testing.allocator;

    const text = \\ bul move ind
                \\ # sdsdds
                \\
                \\ tur supp bul
                \\
                \\ kor
                \\ hold
                \\
                \\ pet move pak
                \\ blk conv pet
    ;

    const mod_text = try alloc.dupe(u8, text);
    defer alloc.free(mod_text);

    var cells = try parseActions(mod_text, alloc);

    cells.deinit(alloc);
}
