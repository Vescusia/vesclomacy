const std = @import("std");

pub const NameT = [3]u8;

pub fn nToI(name: NameT) u24 {
    return @bitCast(name);
}

pub const Action = union(enum) {
    Move: struct { to: NameT },
    Support: struct { who: NameT },
    Hold,
    Convoy: struct { from: NameT, to: NameT },
    Aborted: struct { who: NameT, },
    Flee: struct {  who: NameT },

    const Self = @This();
};

pub const Cell = struct {
    name: NameT,
    action: Action,

    const Self = @This();

    pub fn asInt(self: Self) u24 {
        return nToI(self.name);
    }

    pub fn wantToBeAt(self: Self) NameT {
        return switch (self.action) {
            .Move => |mv| mv.to,
            else  => self.name
        };
    }

    pub fn alsoWantsToBeAt(self: Self, other: Self) bool {
        return nToI(self.wantToBeAt()) == nToI(other.wantToBeAt());
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.asInt() == other.asInt();
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void
    {
        try writer.writeAll(&self.name);

        try switch (self.action) {
            .Move => |move| writer.print(" move {s}", .{move.to}),
            .Support => |sup| writer.print(" supp {s}",.{sup.who}),
            .Hold => writer.print(" hold", .{}),
            .Convoy => |conv| writer.print(" conv ({s} move {s})", .{conv.from, conv.to}),
            .Aborted => |abort| writer.print(" stop (by {s})", .{abort.who}),
            .Flee => |flee| writer.print(" flee (by {s})", .{flee.who}),
        };
    }
};
