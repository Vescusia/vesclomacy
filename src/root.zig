const std = @import("std");

pub const Name = packed struct {
    int: u24,

    pub const Self = @This();

    pub fn asStr(self: Self) [3]u8 {
        return @bitCast(self.int);
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.asInt() == other.asInt();
    }

    pub fn fromStr(str: []u8) Self {
        return .{ .int = str.ptr[0..3] };
    }

    pub fn fromInt(int: u24) Self {
        return .{ .int = @bitCast(int) };
    }

    pub fn fromArr(arr: [3]u8) Self {
        return .{ .int = @bitCast(arr) };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void
    {
        try writer.writeAll(&self.asStr());
    }
};

pub const Action = union(enum(u3)) {
    Move: struct { to: Name },
    Support: struct { who: Name },
    Hold,
    Convoy: struct { from: Name },
    Aborted: struct { who: Name, },
    Flee: struct {  who: Name },

    pub fn abort(by: Name) @This() {
        return .{ .Aborted = .{ .who = by } };
    }

    pub fn flee(by: Name) @This() {
        return .{ .Flee = .{ .who = by } };
    }
};

pub const Cell = struct {
    name: Name,
    action: Action,

    const Self = @This();

    pub fn asInt(self: Self) u24 {
        return self.name.int;
    }

    pub fn wantToBeAt(self: Self) Name {
        return switch (self.action) {
            .Move => |mv| mv.to,
            else  => self.name
        };
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.asInt() == other.asInt();
    }

    pub fn abort(self: *Self, by: Name) void {
        self.action = .abort(by);
    }

    pub fn flee(self: *Self, by: Name) void {
        self.action = .flee(by);
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void
    {
    try writer.writeAll(&self.name.asStr());

    try switch (self.action) {
        .Move => |move| writer.print(" move {f}", .{move.to}),
        .Support => |sup| writer.print(" supp {f}",.{sup.who}),
        .Hold => writer.print(" hold", .{}),
        .Convoy => |conv| writer.print(" conv {f}", .{conv.from}),
        .Aborted => |by| writer.print(" stop (by {f})", .{by.who}),
        .Flee => |by| writer.print(" flee (by {f})", .{by.who}),
    };
    }
};
