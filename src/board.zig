const std = @import("std");

const lib = @import("root.zig");


pub const Tile = struct {
    pub const Kind = enum {
        Water,
        Coast,
        Inland
    };

    name: []const u8,
    kind: Kind,
    nation: lib.Nation,
    neighbors: std.ArrayList(*@This()),
    is_supply_center: bool,

    pub fn init(alloc: std.mem.Allocator, name: []const u8, kind: Kind, nation: lib.Nation, is_supply_center: bool, capacity: ?usize) !@This() {
        return .{
            .name = name,
            .kind = kind,
            .nation = nation,
            .is_supply_center = is_supply_center,
            .neighbors = try std.ArrayList(*@This()).initCapacity(alloc, capacity orelse 16)
        };
    }

    pub fn addNeighbor(self: *@This(), alloc: std.mem.Allocator, neighbor: *@This()) !void {
        return self.neighbors.append(alloc, neighbor);
    }

    /// Link two nodes together, adding each other as neighbors.
    pub fn link(self: *@This(), alloc: std.mem.Allocator, other: *@This()) !void {
        try self.addNeighbor(alloc, other);
        try other.addNeighbor(alloc, self);
    }

    pub fn getNeighbor(self: @This(), idx: usize) *@This() {
        return self.neighbors.items[idx];
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        if (self.is_supply_center) {
            try writer.writeAll("^");
        }
        try writer.print("{s} ({}, {})", .{self.name, self.kind, self.nation});

        if (self.neighbors.items.len > 0) {
            try writer.writeAll(" -> ");
            for (self.neighbors.items) |neighbor| {
                try writer.print("{s} ", .{neighbor.name});
            }
        }
    }
};


pub const Board = struct {
    tiles: []Tile,
    capacity: usize,

    pub fn init(alloc: std.mem.Allocator, max_tiles: usize) !@This() {
        return @This(){
            .capacity = max_tiles,
            .tiles = (try alloc.alloc(Tile, max_tiles)).ptr[0..0],
        };
    }

    /// Parse a comptime string to a board.
    ///
    /// Format:
    ///
    /// ``<'^' if supply base><NAME> -> <KIND> <NATION> [ <NEIGHBOR_NAME0> <NEIGHBOR_NAME1> ]``
    ///
    /// Neighbors have to be defined above already.
    ///
    /// Example:
    ///
    /// ```
    /// ^NewYork -> Inland Neutral                          // '^' means that it is a supply hub
    ///
    /// Berlin -> Coast Germany [ NewYork ]                 // adding London to the Neighbors here would error, as London is not yet defined
    ///
    /// ^London -> Water AustriaHungary [ NewYork Berlin ]  // London gets linked to Berlin
    /// ```
    pub fn StringParser(comptime buildstr: []const u8) type {
        return struct {
            i: usize = 0,
            wordbuf_i: usize = 0,

            pub fn parse(alloc: std.mem.Allocator) !Board {
                var self = @This(){};

                var board = try Board.init(alloc, 20);
                errdefer board.deinit(alloc);

                while (!self.isLast()) {
                    // determine if the Tile is a supply hub and the name of the Tile
                    self.skipWhitespace();
                    const supply = buildstr[self.i] == '^';
                    if (supply) {
                        self.step();
                    }
                    const name = self.word();

                    // skip arrow
                    self.step(); self.skipWhitespace();
                    std.debug.assert(buildstr[self.i] == '-'); self.step();
                    std.debug.assert(buildstr[self.i] == '>'); self.step();

                    // determine the tile kind
                    self.step(); self.skipWhitespace();
                    const kind_name = self.word();
                    const kind = matchEnum(Tile.Kind, kind_name) orelse {
                        std.log.err("{s}: Tile.Kind.{s} is not defined.\n", .{name, kind_name});
                        return error.UndefinedTileKind;
                    };

                    // determine the tile nation
                    self.step(); self.skipWhitespace();
                    const nation_name = self.word();
                    const nation = matchEnum(lib.Nation, nation_name) orelse {
                        std.log.err("{s}: lib.Nation.{s} is not defined.\n", .{name, nation_name});
                        return error.UndefinedNation;
                    };

                    // build tile
                    try board.append(
                        try Tile.init(alloc, name, kind, nation, supply, null)
                    );

                    // iterate over link list
                    self.step(); self.skipWhitespace();
                    if (buildstr[self.i] == '[') {
                        self.step(); self.skipWhitespace();

                        while (!self.isLast() and buildstr[self.i] != ']') {
                            const link_name = self.word();
                            if (board.getTile(link_name)) |other| {
                                // link newest (current) tile of board with with the other one
                                try board.getLast().link(alloc, other);
                            }
                            else {
                                std.log.err("Cannot link Tile {s} to neighbor '{s}'. '{s}' does not exist.\n", .{name, link_name, link_name});
                                return error.UndefinedNeighbor;
                            }
                            self.step(); self.skipWhitespace();
                        }

                        self.step(); self.skipWhitespace();
                    }
                }

                return board;
            }

            /// Skip one character and then
            /// any spaces or newlines in incrementing ``self.i`` until a non space, non newline
            /// character is at ``buildstr[self.i]``
            fn skipWhitespace(self: *@This()) void {
                var c = buildstr[self.i];
                while (!self.isLast() and (c == ' ' or c == '\n')) {
                    self.i += 1;
                    c = buildstr[self.i];
                }
            }

            /// Increment ``self.i`` by 1 if ``self.i < builtstr.len - 1``
            fn step(self: *@This()) void {
                self.i += 1 * @intFromBool(!self.isLast());
            }

            fn isLast(self: @This()) bool {
                return self.i == buildstr.len - 1;
            }

            fn matchEnum(comptime EnumT: type, name: []const u8) ?EnumT {
                inline for (@typeInfo(EnumT).@"enum".fields) |possible_kind| {
                    if (std.mem.eql(u8, name, @as([]const u8, possible_kind.name))) {
                        return @enumFromInt(possible_kind.value);
                    }
                }
                return null;
            }

            /// Gets the current word, as in a string of non whitespace ended by whitespace.
            /// This increments ``self.i`` to the last character of the word.
            fn word(self: *@This()) []const u8 {
                const start_i = self.i;

                while (!self.isLast()) : ({ self.i += 1; }) {
                    const c = buildstr[self.i];
                    if (c == ' ' or c == '\n') {
                        self.i -= 1;
                        break;
                    }
                }

                return buildstr[start_i..self.i+1];
            }
        };
    }

    /// Append a ``Tile`` to ``.tiles``.
    pub fn append(self: *@This(), tile: Tile) !void {
        std.debug.assert(self.tiles.len < self.capacity);

        self.tiles.len += 1;
        self.getLast().* = tile;
    }

    pub fn link(self: @This(), alloc: std.mem.Allocator, name0: []const u8, name1: []const u8) !void {
        var tile0 = self.getTile(name0) orelse return error.NotFound;
        const tile1 = self.getTile(name1) orelse return error.NotFound;
        try tile0.link(alloc, tile1);
    }

    pub fn getTile(self: @This(), name: []const u8) ?*Tile {
        for (self.tiles) |*tile| {
            if (std.mem.eql(u8,tile.name, name)) {
                return tile;
            }
        }
        return null;
    }

    /// Frees all Memory allocated by this Board and all contained Tiles
    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        // dealloc neighbor ArrayLists of nodes
        for (self.tiles) |*node| {
            node.neighbors.deinit(alloc);
        }

        // dealloc nodes
        alloc.free(self.tiles.ptr[0..self.capacity]);
    }

    /// Gets the last entry of ``.tiles``
    pub fn getLast(self: @This()) *Tile {
        return &self.tiles[self.tiles.len-1];
    }
};


test "basicGraph" {
    const alloc = std.testing.allocator;

    var graph = try Board.init(alloc, 6);
    defer graph.deinit(alloc);

    try graph.append(try Tile.init(alloc, "Berlin", .Inland, .Neutral, false, null));
    try graph.append(try Tile.init(alloc, "Senegal", .Inland, .Neutral, false, null));
    try graph.append(try Tile.init(alloc, "Paris", .Inland, .Neutral, false, null));

    try std.testing.expectEqual(null, graph.getTile("NewYork"));

    {
        graph.getTile("Senegal").?.name = "Yugo";
    }
    try std.testing.expect(graph.getTile("Yugo") != null);

    try graph.link(alloc,  "Berlin", "Paris");

    try std.testing.expect(std.mem.eql(u8, "Paris", graph.getTile("Berlin").?.getNeighbor(0).name));

}

test "build from string" {
    const alloc = std.testing.allocator;

    const Builder = Board.StringParser(
        "^Edinburgh -> Coast GreatBritain " ++
        "York -> Coast GreatBritain [ Edinburgh ] " ++
        "^London -> Coast GreatBritain [ York ] " ++
        "Wales -> Coast GreatBritain [ London York ] " ++
        "^Liverpool -> Coast GreatBritain [ Wales York Edinburgh ] " ++
        "Clyde -> Coast GreatBritain [ Edinburgh Liverpool ] " ++
        "IrishSea -> Water Neutral [ Wales Liverpool ] " ++
        "EnglishChannel -> Water Neutral [ London ] " ++
        "NorthSea -> Water Neutral [ London York Edinburgh ] " ++
        "NorthAtlantic -> Water Neutral [ Clyde Liverpool ]"
    );
    var board = try Builder.parse(alloc);

    for (board.tiles) |tile| {
        std.debug.print("{f}\n", .{tile});
    }

    defer board.deinit(alloc);
}
