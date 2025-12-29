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
            if (readYaml("src/devtools/menu.yaml", allocator)) {
            } else |err| {
                std.log.err("Failed to parse menu.yml: {any}", .{err});
            }
            const filePath = "src/devtools/menu.txt";
            var menuItems: []*mi.MenuItem = undefined;
            if (GetMenuItemsFromFile(filePath, state, allocator)) |menu_items| {
                menuItems = menu_items;
            } else |err| {
                std.log.err("Failed getting menu items from file {s}: {any}", .{filePath, err});
            }
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


        fn readYaml(filePath: []const u8, allocator: std.mem.Allocator) !void {
            const yml_location = filePath;

            const yml_path = try std.fs.cwd().realpathAlloc(
                allocator,
                yml_location,
            );
            defer allocator.free(yml_path);

            var ymlz = try Ymlz(mi.YamlMenuDef).init(allocator);
            const result = try ymlz.loadFile(yml_path);
            defer ymlz.deinit(result);

            // We can print and see that all the fields have been loaded
            std.debug.print("Experiment: {any}\n", .{result});
            // Lets try accessing the first field and printing it
            std.debug.print("First: {any}\n", .{result});
            // same goes for the array that we've defined `foods`
            for (result.itemDefs) |itemDef| {
                std.debug.print("{any}", .{itemDef});
            }
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
                if (menuItem.float.menuProperties.displayValuePrefix.len == 0) {
                    const text = std.fmt.bufPrintZ(&label_buf, "{s}: {d:.1}", .{menuItem.float.menuProperties.displayValuePrefix, menuItem.float.valuePtr.*}) catch "Gravity";
                    _ = rg.sliderBar( menuItem.float.menuProperties.bounds, text, "", menuItem.float.valuePtr, -400, 0 );
                } else {
                    _ = rg.sliderBar( menuItem.float.menuProperties.bounds, "", "", menuItem.float.valuePtr, -400, 0 );
                }
            }

            // if (fieldPtrByPathExpect(f32, self.state, "jumper.jumpPower")) |p_jumpPower| {
            //     var label_buf: [64]u8 = undefined;
            //     const text = std.fmt.bufPrintZ(&label_buf, "Power: {d:.1}", .{p_jumpPower.*}) catch "Gravity";
            //     _ = rg.sliderBar( .{ .x = 50, .y = 11, .width = 120, .height = 10 }, text, "", p_jumpPower, 0, 400 );
            // }
        }

        pub fn GetMenuItem(
            itemDefPtr: *ItemDef,
            bounds: Rectangle,
            state: *T,
            allocator: std.mem.Allocator
        ) !*MenuItem {
            const itemDef = itemDefPtr.*;
            const menuItemTypeString: []const u8 = itemDef.menuItemTypeString;
            const statePath: []const u8 = itemDef.statePath;
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
                ret.int.*.menuProperties.statePath = statePath;
                ret.int.*.menuProperties.elementType = .SLIDER;
                if(fieldPtrByPathExpect(i32, state, statePath)) |valuePtr| {
                    ret.int.*.valuePtr = valuePtr;
                } else {
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .float => {
                ret.* = .{ .float = try allocator.create(FloatMenuItem) };
                ret.float.*.menuProperties.bounds = bounds;
                ret.float.*.menuProperties.statePath = statePath;
                ret.float.*.menuProperties.elementType = .SLIDER;
                if(fieldPtrByPathExpect(f32, state, statePath)) |valuePtr| {
                    ret.float.*.valuePtr = valuePtr;
                } else {
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .string => {
                ret.* = .{ .string = try allocator.create(StringMenuItem) };
                ret.string.*.menuProperties.bounds = bounds;
                ret.string.*.menuProperties.statePath = statePath;
                ret.string.*.menuProperties.elementType = .SLIDER; // obv wrong but only enum atm
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
                    Rectangle{ .width = ITEM_WIDTH, .height = ITEM_HEIGHT, .x = ITEM_PADDING, .y = y },
                    state,
                    allocator
                );
                try ret.append(menuItem);
                y = ITEM_HEIGHT + ITEM_PADDING;
            }
            return ret.items;
        }

        pub fn GetMenuItemsFromFile(
            filePath: []const u8,
            state: *T,
            allocator: std.mem.Allocator
        ) ![]*MenuItem {
            const menuItems = try mi.GetItemDefsFromFile(filePath, allocator);

            return BuildMenuItems(menuItems, state, allocator);
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
        x: f32,
        y: f32,
    };
    var state = TestState{.x = 1, .y = 2};
    const devMenu = DevMenu(TestState).init(&state, 100, 200);

    devMenu.draw();
}

const testing = std.testing;

test "Get IntMenuItem and access field" {
    var intValue: i32 = 1234;
    const menuItemPtr = mi.MenuItemValuePtr{ .int = &intValue };
    const menuItem = mi.GetMenuItem(ItemDef{
        .menuItemTypeString = "int",
        .statePath = "player.score",
        .valuePtr = menuItemPtr,
    }, Rectangle{ .height = 0, .width = 1, .x = 2, .y = 3 });

    // Using the new helper functions
    try testing.expect(menuItem.isInt());
    try testing.expectEqual(MenuItemType.int, menuItem.getType());

    // 1. Using switch to access the active field and its value (Preferred)
    switch (menuItem) {
        .int => |intItem| {
            try testing.expectEqual(@as(i32, 1234), intItem.valuePtr.*);
        },
        .float => return error.WrongType,
        .string => return error.WrongType,
        .none => return error.NoItem,
    }
}
