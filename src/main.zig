const rg = @import("raygui");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Jumper = @import("jumper.zig").Jumper;
const Platform = @import("platform.zig").Platform;
const std = @import("std");
const DevMenu = @import("devtools/devmenu.zig").DevMenu;
const GameState = @import("gamestate.zig").GameState;

const PLAYFIELD_WIDTH: i32 = 100;
const PLAYFIELD_HEIGHT: i32 = 400;
const JUMPER_SIZE: i32 = 20;
const JUMPER_FLOOR_POS: f32 = PLAYFIELD_HEIGHT - JUMPER_SIZE;
const JUMP_HEIGHT: f32 = 40;
const GRAVITY: f32 = -20;
const rand = std.crypto.random;

const Experiment = struct {
    first: i32,
    second: i64,
    name: []const u8,
    fourth: f32,
    foods: [][]const u8,
    inner: struct {
        abcd: i32,
        k: u8,
        l: []const u8,
        another: struct {
            new: f32,
            stringed: []const u8,
        },
    },
};

pub fn updateJumper(jumper: *Jumper) void {
    if (rl.isKeyDown(rl.KeyboardKey.right)) {
        jumper.rec.x += 1;
    }
    if (rl.isKeyDown(rl.KeyboardKey.left)) {
        jumper.rec.x -= 1;
    }
    const leftStart: f32 = 0;
    const rightStart: f32 = PLAYFIELD_WIDTH - JUMPER_SIZE;
    if (jumper.rec.x < 0) {
        jumper.rec.x = rightStart;
    } else if (jumper.rec.x > rightStart) {
        jumper.rec.x = leftStart;
    }
    jumper.bounce();
}

fn getNextPlatform(jumper: *const Jumper, lastPlatform: *const Platform) Platform {
    const width: f32 = @floatFromInt(50 - jumper.bounces % 20);
    const bouncesf32: f32 = @floatFromInt(jumper.bounces);
    return Platform.init(Vector2{
        .x = @floatFromInt(rand.intRangeAtMost(i32, 0, @intFromFloat(PLAYFIELD_WIDTH - width))),
        .y = @floatFromInt(rand.intRangeAtMost(i32, @intFromFloat(lastPlatform.rec.y - 100 - bouncesf32), @intFromFloat(lastPlatform.rec.y - 20 - bouncesf32)))
    }, width);
}


pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = PLAYFIELD_WIDTH;
    const screenHeight = PLAYFIELD_HEIGHT;
    
    var devMenuEnabled = false;
    var jumper = Jumper.init(
        rl.Vector2{ .x = (PLAYFIELD_WIDTH - JUMPER_SIZE) / 2, .y = (PLAYFIELD_HEIGHT - JUMPER_SIZE) },
        JUMPER_FLOOR_POS,
        JUMPER_SIZE
    );
    var state = GameState{
        .jumper = &jumper
    };
    const gpaConfig = std.heap.DebugAllocatorConfig{
        .verbose_log = false,
    };
    var gpa = std.heap.DebugAllocator(gpaConfig){};
    const allocator = gpa.allocator();
    // const allocator = std.heap.page_allocator;
    // defer {
        // const leaked = allocator.deinit();
        // if (leaked != std.heap.Check.leak) {
            // std.debug.print("Memory leaked!\n", .{});
        // }
    // }
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const floorPlatform = Platform.init(rl.Vector2{.x = 0, .y = PLAYFIELD_HEIGHT - 10 }, PLAYFIELD_WIDTH);
    // const platform1 = Platform.init(rl.Vector2{.x = 40, .y = PLAYFIELD_HEIGHT - 100}, 50);
    // const platform2 = Platform.init(rl.Vector2{.x = 20, .y = PLAYFIELD_HEIGHT - 200}, 50);
    // const platform3 = Platform.init(rl.Vector2{.x = 10, .y = PLAYFIELD_HEIGHT - 300}, 50);
    var platforms = std.array_list.Managed(Platform).init(std.heap.page_allocator);
    var platformsToRemove = std.array_list.Managed(usize).init(std.heap.page_allocator);
    defer platforms.deinit();
    // try platforms.append(platform1);
    // try platforms.append(platform2);
    // try platforms.append(platform3);
    try platforms.append(floorPlatform);
    for (0..10) |_| {
        const last = platforms.getLast();
        const nextPlatform = getNextPlatform(&jumper, &last);
        try platforms.append(nextPlatform);
    }

    var camera = rl.Camera2D{
        .target = Vector2{
            .x = jumper.rec.x + jumper.rec.width / 2,
            .y = jumper.rec.y + jumper.rec.height / 2
        },
        .zoom = 1,
        .rotation = 0,
        .offset = Vector2{.x = PLAYFIELD_WIDTH / 2, .y = 0}
    };

    // const devMenu = DevMenu.init(
        // GameState, screenWidth, screenHeight, state
    // );
    var devMenu = DevMenu(GameState).init(
        &state,
        PLAYFIELD_HEIGHT,
        PLAYFIELD_WIDTH,
        allocator
    );
    defer devMenu.deinit();
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        camera.target.x = PLAYFIELD_WIDTH / 2;
        camera.target.y = @min(jumper.rec.y + jumper.rec.height / 2, camera.target.y);
        camera.offset.y = @max(PLAYFIELD_HEIGHT / 2, camera.target.y);
        platformsToRemove.clearAndFree();
        for (platforms.items, 0..) |platform, index| {
            if (!jumper.settled and jumper.rec.y < platform.rec.y and jumper.vel.y < 0) {
                jumper.settled = rl.checkCollisionRecs(platform.rec, jumper.rec);
                if (jumper.settled) {
                    jumper.bounces += 1;
                }
            }
            if (platform.rec.y > camera.target.y + PLAYFIELD_HEIGHT / 2) {
                try platformsToRemove.append(index);
                try platforms.append(getNextPlatform(&jumper, &platforms.getLast()));
                std.debug.print("Removing platform\n", .{});
            }
        }
        for (platformsToRemove.items) |remove| {
            _ = platforms.orderedRemove(remove);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.comma)) {
            devMenuEnabled = !devMenuEnabled;
        }
        updateJumper(&jumper);
        // if (jumper.rec.y > camera.target.y) {
//
        // }

        // Draw
        //----------------------------------------------------------------------------------
        //

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);
        rl.beginMode2D(camera);
            rl.drawRectangleRec(
                jumper.rec,
                rl.Color.red,
            );

            for (platforms.items) |platform| {
                rl.drawRectangleRec(platform.rec, rl.Color.black);

            }

        rl.endMode2D();

        if (devMenuEnabled) {
            devMenu.draw();
        }

    }
}
