pub const board = @import("board.zig");
pub const Tile = board.Tile;


pub const Nation = enum {
    AustriaHungary,
    GreatBritain,
    France,
    Germany,
    Italy,
    Russia,
    Turkey,
    Neutral,

    pub fn toStr(self: @This()) []const u8 {
        return @tagName(self);
    }
};

pub const Player = struct {
    nation: Nation,
};

pub const Army = struct {
    pub const Action = union(enum) {
        Stay: void,
        Move: *board.Tile,
        Convoy: struct { to: *board.Tile, with: *Fleet }
    };

    pos: *board.Tile,
    nation: Nation,

};

pub const Fleet = struct {
    pub const Action = union(enum) {
        Stay: void,
        Move: *board.Tile,
        Convoy: struct { army: *Army, to: *Tile }
    };

};


test "smd" {

}
