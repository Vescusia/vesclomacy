const std = @import("std");

pub const rl = @import("raylib");
pub const rg = @import("raygui");

const lib =  @import("root.zig");


/// `rl.getColor` only accepts a `u32`. Performing `@intCast` on the return value
/// of `rg.getStyle` invokes checked undefined behavior from Zig when passed to
/// `rl.getColor`, hence the custom implementation here...
fn getColor(hex: i32) rl.Color {
    var color: rl.Color = .black;
    // zig fmt: off
    color.r = @intCast((hex >> 24) & 0xFF);
    color.g = @intCast((hex >> 16) & 0xFF);
    color.b = @intCast((hex >>  8) & 0xFF);
    color.a = @intCast((hex >>  0) & 0xFF);
    // zig fmt: on
    return color;
}

fn loadDefaultBoard(alloc: std.mem.Allocator) !lib.board.Board {
    const Builder = lib.Board.StringParser(
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
    return Builder.parse(alloc);
}

pub fn main() !void {
    // load diplomacy map
    const map_image = try rl.loadImage("./map_c.gif");

    // define screen size
    const screen_width = map_image.width;
    const screen_add_width: c_int = @divFloor(map_image.width, 10);
    const screen_height = map_image.height;
    const screen_add_height: c_int = @divFloor(map_image.height, 10);

    // initialize Window
    rl.initWindow(screen_width + screen_add_width, screen_height + screen_add_height, "Vesclomacy - Diplomacy Calculator");
    defer rl.closeWindow();

    // convert map to Texture
    const map = try map_image.toTexture();

    // set defaults
    rl.setTargetFPS(30);
    const color_int = rg.getStyle(.default, .{ .default = .background_color });
    const tile_circle_radius = 15;

    // main loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        // draw map
        rl.clearBackground(getColor(color_int));
        rl.drawTextureEx(map, .{.x = 10, .y = @as(f32, @floatFromInt(screen_add_height)) - 10 }, 0, 1, getColor(color_int));

        // get mouse position
        const mouse_postion = rl.getMousePosition();


        if (rl.isMouseButtonDown(.left)) {
            rl.drawCircleLinesV(mouse_postion, tile_circle_radius, getColor(color_int));
            std.debug.print("{}\n", .{mouse_postion});
        }
    }
}