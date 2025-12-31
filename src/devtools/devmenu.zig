const std = @import("std");

const rg = @import("raygui");
const rl = @import("raylib");
const Rectangle = rl.Rectangle;

const mi = @import("menuitem.zig");
const MenuItem = mi.MenuItem;
const ItemDef = mi.ItemDef;
const MenuItemType = mi.MenuItemType;
const MenuItemTypeError = mi.MenuItemTypeError;
const IntMenuItem = mi.IntMenuItem;
const FloatMenuItem = mi.FloatMenuItem;
const StringMenuItem = mi.StringMenuItem;

const Ymlz = @import("ymlz").Ymlz;

pub const DevMenuError = error{
    StateFieldNotFound
};

pub fn DevMenu(comptime T: type) type {
    return struct {
        const Self = @This();

        state: *T,
        windowHeight: f32,
        windowWidth: f32,
        menuItems: []*mi.MenuItem,
        allocator: std.mem.Allocator,

        pub fn init(
            state: *T,
            windowHeight: f32,
            windowWidth: f32,
            allocator: std.mem.Allocator
        ) Self {
            // const itemDefs = mi.GetItemDefsFromFile("src/devtools/menu.txt", allocator) catch |err| {
            //     std.log.err("failed, {}", .{err});
            //     std.array_list.Managed(*mi.ItemDef);
            // };
            const filePath = "src/devtools/menu.yaml";
            // var menuItems: []*mi.MenuItem = &.{};
            // if (GetMenuItemsFromFile(filePath, state, allocator)) |menu_items| {
            //     menuItems = menu_items;
            // } else |err| {
            //     std.log.err("Failed getting menu items from file {s}: {any}", .{filePath, err});
            // }
            const menuItems = GetMenuItemsFromFile(filePath, state, allocator) catch |err| {
                std.log.err("Failed getting menu items from file {s}: {any}", .{filePath, err});
                return Self{
                    .state = state,
                    .windowWidth = windowWidth,
                    .windowHeight = windowHeight,
                    .menuItems = &.{},
                    .allocator = allocator,
                };
            };
            // if (fieldPtrByPathExpect(f32, state, "jumper.gravity")) |jumperGravityPtr| {
            //     menuItems.append(mi.MenuItem{
            //         .float = mi.FloatMenuItem.init(
            //             mi.UiElementType.SLIDER,
            //             jumperGravityPtr,
            //             .{ .x = 50, .y = 1, .width = 120, .height = 10 },
            //             "Gravity: ",
            //             "jumper.gravity"
            //         )
            //     }) catch {
            //         std.log.err("asdf ", .{});
            //     };
            // }
            return Self{
                .state = state,
                .windowHeight = windowHeight,
                .windowWidth = windowWidth,
                .menuItems = menuItems,
                .allocator = allocator
            };
        }

        pub fn draw(self: Self) void {
            _ = rl.Rectangle.init(
                0, 0,
                self.windowWidth, self.windowHeight
            );
            // _ = rg.windowBox(bounds, "dev menu");

            // if () |p_gravity| {
            //     var label_buf: [64]u8 = undefined;
            //     const text = std.fmt.bufPrintZ(&label_buf, "Gravity: {d:.1}", .{p_gravity.*}) catch "Gravity";
            //     _ = rg.sliderBar( .{ .x = 50, .y = 1, .width = 120, .height = 10 }, text, "", p_gravity, -400, 0 );
            // }
            for (self.menuItems) |menuItem| {
                var label_buf: [64]u8 = undefined;
                const range = menuItem.float.range;
                if (menuItem.float.menuProperties.displayValuePrefix.len > 0) {
                    const text = std.fmt.bufPrintZ(&label_buf, "{s}: {d:.1}", .{menuItem.float.menuProperties.displayValuePrefix, menuItem.float.valuePtr.*}) catch "Gravity";
                    _ = rg.sliderBar( menuItem.float.menuProperties.bounds, text, "", menuItem.float.valuePtr, range.lower, range.upper);
                } else {
                    _ = rg.sliderBar( menuItem.float.menuProperties.bounds, "", "", menuItem.float.valuePtr, range.lower, range.upper);
                }
            }

            // if (fieldPtrByPathExpect(f32, self.state, "jumper.jumpPower")) |p_jumpPower| {
            //     var label_buf: [64]u8 = undefined;
            //     const text = std.fmt.bufPrintZ(&label_buf, "Power: {d:.1}", .{p_jumpPower.*}) catch "Gravity";
            //     _ = rg.sliderBar( .{ .x = 50, .y = 11, .width = 120, .height = 10 }, text, "", p_jumpPower, 0, 400 );
            // }
        }

        pub fn deinit(self: *Self) void {
            for (self.menuItems) |menuItem| {
                menuItem.deinit(self.allocator);
            }
            self.allocator.free(self.menuItems);
        }

        pub fn GetMenuItem(
            itemDefPtr: *ItemDef,
            bounds: Rectangle,
            state: *T,
            allocator: std.mem.Allocator
        ) !*MenuItem {
            const menuItemTypeString: []u8 = itemDefPtr.menuItemType;
            const statePath: []u8 = itemDefPtr.statePath;
            std.log.info("statePath {s}", .{statePath});
            std.log.info("menuItemTypeString {s}", .{menuItemTypeString});

            const menuItemType = std.meta.stringToEnum(MenuItemType, menuItemTypeString);
            if (menuItemType == null) {
                std.log.err("{s} did not parse to enum", .{menuItemTypeString});
                return MenuItemTypeError.MenuItemTypeUnknown;
            }

            const ret = try allocator.create(MenuItem);
            switch (menuItemType.?) {
            .int => {
                ret.* = .{ .int = try allocator.create(IntMenuItem) };
                ret.int.*.menuProperties.bounds = bounds;
                ret.int.*.menuProperties.statePath = try allocator.dupe(u8, statePath);
                ret.int.*.menuProperties.elementType = .SLIDER;
                ret.int.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDefPtr.displayValuePrefix);
                ret.int.*.range = itemDefPtr.range;
                if(fieldPtrByPathExpect(i32, state, statePath)) |valuePtr| {
                    ret.int.*.valuePtr = valuePtr;
                } else {
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .float => {
                ret.* = .{ .float = try allocator.create(FloatMenuItem) };
                ret.float.*.menuProperties.bounds = bounds;
                ret.float.*.menuProperties.statePath = try allocator.dupe(u8, statePath);
                ret.float.*.menuProperties.elementType = .SLIDER;
                ret.float.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDefPtr.displayValuePrefix);
                ret.float.*.range = itemDefPtr.range;
                if(fieldPtrByPathExpect(f32, state, statePath)) |valuePtr| {
                    ret.float.*.valuePtr = valuePtr;
                } else {
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .string => {
                ret.* = .{ .string = try allocator.create(StringMenuItem) };
                ret.string.*.menuProperties.bounds = bounds;
                ret.string.*.menuProperties.statePath = try allocator.dupe(u8, statePath);
                ret.string.*.menuProperties.elementType = .SLIDER; // obv wrong but only enum atm
                ret.string.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDefPtr.displayValuePrefix);
                if(fieldPtrByPathExpect([]const u8, state, statePath)) |valuePtr| {
                    ret.string.*.valuePtr = valuePtr;
                } else {
                    return DevMenuError.StateFieldNotFound;
                }
            },
            else => {},
            }
            return ret;
        }

        const ITEM_WIDTH = 50;
        const ITEM_HEIGHT = 10;
        const ITEM_PADDING = 4;

        pub fn BuildMenuItems(
            itemDefs: []*ItemDef,
            state: *T,
            allocator: std.mem.Allocator
        ) ![]*MenuItem {
            var ret = std.array_list.Managed(*MenuItem).init(allocator);
            var y: f32 = ITEM_PADDING;
            for (itemDefs) |itemDefPtr| {
                const menuItem = try GetMenuItem(
                    itemDefPtr,
                    Rectangle{ .width = ITEM_WIDTH, .height = ITEM_HEIGHT, .x = ITEM_PADDING + 20, .y = y },
                    state,
                    allocator
                );
                try ret.append(menuItem);
                y = ITEM_HEIGHT + ITEM_PADDING;
            }
            return try ret.toOwnedSlice();
        }

        pub fn GetMenuItemsFromFile(
            filePath: []const u8,
            state: *T,
            allocator: std.mem.Allocator
        ) ![]*MenuItem {
            const menuDef = try mi.GetMenuDefFromFile(filePath, allocator);
            defer menuDef.deinit(allocator);

            return BuildMenuItems(menuDef.itemDefs, state, allocator);
        }
    };
}


pub fn fieldPtrByPathExpect(comptime Leaf: type, root_ptr: anytype, path: []const u8) ?*Leaf {
    // root_ptr must be a pointer to a struct
    const RootPtrT = @TypeOf(root_ptr);
    comptime {
        const info = @typeInfo(RootPtrT);
        switch (info) {
            .pointer => |pinfo| {
                const ChildT = pinfo.child;
                if (@typeInfo(ChildT) != .@"struct") {
                    @compileError("fieldPtrByPathExpect: root_ptr must point to a struct");
                }
            },
            else => @compileError("fieldPtrByPathExpect: root_ptr must be a pointer"),
        }
    }
    return fieldPtrByPathExpectInner(Leaf, @TypeOf(root_ptr.*), root_ptr, path);
}

fn fieldPtrByPathExpectInner(comptime Leaf: type, comptime S: type, base_ptr: *S, path: []const u8) ?*Leaf {
    // Split path into head and tail on first '.'
    const dot_idx = std.mem.indexOfScalar(u8, path, '.');
    const head = if (dot_idx) |i| path[0..i] else path;
    const tail = if (dot_idx) |i| path[i+1..] else path[path.len..path.len];

    // Find the "head" field in S
    inline for (std.meta.fields(S)) |field| {
        if (std.mem.eql(u8, field.name, head)) {
            // Pointer to that field
            const field_ptr = &@field(base_ptr.*, field.name);
            const FieldT = @TypeOf(field_ptr.*);

            if (tail.len == 0) {
                // Last segment — it must match the expected leaf type
                if (FieldT == Leaf) {
                    return @ptrCast(field_ptr);
                } else {
                    return null; // wrong leaf type
                }
            }

            // More segments — continue traversal
            const ti = @typeInfo(FieldT);
            switch (ti) {
                .@"struct" => {
                    // Field is an inline struct, keep pointer to field
                    return fieldPtrByPathExpectInner(Leaf, FieldT, field_ptr, tail);
                },
                .pointer => |pinfo| {
                    const Child = pinfo.child;
                    // Only proceed if the pointee is a struct
                    if (@typeInfo(Child) != .@"struct") return null;
                    // field_ptr: *FieldT (i.e., **Child). Dereference once to get *Child.
                    return fieldPtrByPathExpectInner(Leaf, Child, field_ptr.*, tail);
                },
                else => return null,
            }
        }
    }

    // Field not found
    return null;
}

test "devmenu struct is correct" {
    const TestState = struct {
        jumper: struct {
            gravity: f32,
            jumpPower: f32,
        },
    };
    var state = TestState{ .jumper = .{ .gravity = 1, .jumpPower = 2 } };
    var devMenu = DevMenu(TestState).init(&state, 100, 200, std.testing.allocator);
    defer devMenu.deinit();
}

const testing = std.testing;

test "Get IntMenuItem and access field" {
    const intValue: i32 = 1234;
    const TestState = struct {
        player: struct {
            score: i32,
        },
    };
    var state = TestState{ .player = .{ .score = 1234 } };
    _ = intValue;

    var itemDef = ItemDef{
        .menuItemType = @constCast("int"),
        .statePath = @constCast("player.score"),
        .elementType = @constCast("SLIDER"),
        .bounds = Rectangle{ .height = 0, .width = 1, .x = 2, .y = 3 },
        .displayValuePrefix = @constCast("Score"),
        .range = .{ .lower = 0, .upper = 100 },
    };

    var menuItem = try DevMenu(TestState).GetMenuItem(
        &itemDef,
        Rectangle{ .height = 0, .width = 1, .x = 2, .y = 3 },
        &state,
        std.testing.allocator,
    );
    defer menuItem.deinit(std.testing.allocator);

    // Using the new helper functions
    try testing.expect(menuItem.isInt());
    try testing.expectEqual(MenuItemType.int, menuItem.getType());

    // 1. Using switch to access the active field and its value (Preferred)
    switch (menuItem.*) {
        .int => |intItem| {
            try testing.expectEqual(@as(i32, 1234), intItem.valuePtr.*);
        },
        .float => return error.WrongType,
        .string => return error.WrongType,
        .none => return error.NoItem,
    }
}
