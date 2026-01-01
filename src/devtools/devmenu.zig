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

            const filePath = "src/devtools/menu.yaml";

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
            return Self{
                .state = state,
                .windowHeight = windowHeight,
                .windowWidth = windowWidth,
                .menuItems = menuItems,
                .allocator = allocator
            };
        }

        pub fn reloadMenuItems(self: Self) !Self {
            const filePath = "src/devtools/menu.yaml";

            for(self.menuItems) |menuItem| {
                self.allocator.destroy(menuItem);
            }
            self.allocator.free(self.menuItems);

            const menuItems = try GetMenuItemsFromFile(filePath, self.state, self.allocator);

            return Self{
                .state = self.state,
                .windowHeight = self.windowHeight,
                .windowWidth = self.windowWidth,
                .menuItems = menuItems,
                .allocator = self.allocator
            };

        }

        pub fn draw(self: Self) void {
            _ = rl.Rectangle.init(
                0, 0,
                self.windowWidth, self.windowHeight
            );
            for (self.menuItems) |menuItem| {
                switch(menuItem.*) {
                    .float => |active| {
                        drawFloatElements(menuItem, active.valuePtr);
                    },
                    .int => |active| {
                        // std.log.info("int menu item {s}\n", .{menuItem.int.menuProperties.displayValuePrefix});
                        drawIntElements(menuItem, active.valuePtr);
                    },
                    .string => std.log.warn("String not implemented yet", .{}),
                }
            }
        }

        fn drawFloatElements(menuItem: *mi.MenuItem, valuePtr: anytype) void {
            const menuProperties = menuItem.getMenuProperties();
            switch(menuProperties.elementType.?) {
                .SLIDER => {
                    const range = menuItem.getRange();
                    drawSlideBar(menuProperties, range, valuePtr);
                },
                else => {}
            }
        }

        fn drawIntElements(menuItem: *mi.MenuItem, valuePtr: *i32) void {
            const menuProperties = menuItem.getMenuProperties();
            if (menuProperties.elementType) |elementType| {
                switch(elementType) {
                    .VALUE_BOX => {
                        const range = menuItem.getRange();
                        drawValueBox(menuProperties, range, valuePtr);
                    },
                    else => {}
                }
            }
        }

        fn formatLabel(buf: []u8, prefix: []const u8, value: anytype) [:0]const u8 {
            if (prefix.len == 0) return "";
            return std.fmt.bufPrintZ(buf, "{s}: {d:.1}", .{ prefix, value }) catch "Gravity";
        }

        fn drawSlideBar(menuProperties: mi.MenuProperties, range: mi.Range, valuePtr: anytype) void {
            var label_buf: [64]u8 = undefined;
            const text = formatLabel(&label_buf, menuProperties.displayValuePrefix, valuePtr.*);
            _ = rg.sliderBar(menuProperties.bounds, text, "", valuePtr, range.lower, range.upper);
        }

        fn drawValueBox(menuProperties: mi.MenuProperties, range: mi.Range, valuePtr: *i32) void {
            var label_buf: [64]u8 = undefined;
            const text = formatLabel(&label_buf, menuProperties.displayValuePrefix, valuePtr.*);
            _ = rg.valueBox(menuProperties.bounds, text, valuePtr, @intFromFloat(range.lower), @intFromFloat(range.upper), true);
        }

        pub fn deinit(self: *Self) void {
            for (self.menuItems) |menuItem| {
                menuItem.deinit(self.allocator);
            }
            self.allocator.free(self.menuItems);
        }

        pub fn GetMenuItem(
            itemDef: mi.YamlItemDef,
            bounds: Rectangle,
            state: *T,
            allocator: std.mem.Allocator
        ) !*MenuItem {
            const menuItemTypeString = itemDef.menuItemType;
            const statePath = itemDef.statePath;
            std.log.info("statePath {s}", .{statePath});
            std.log.info("menuItemTypeString {s}", .{menuItemTypeString});
            std.log.info("elementType {s}", .{itemDef.elementType});

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
                // ret.int.*.menuProperties.elementType = try getValidUiElementTypeByMenuType(.int, itemDefPtr.elementType);
                ret.int.*.menuProperties.elementType = std.meta.stringToEnum(mi.UiElementType, itemDef.elementType);
                ret.int.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDef.displayValuePrefix);
                ret.int.*.range = itemDef.range;
                if(fieldPtrByPathExpect(i32, state, statePath)) |valuePtr| {
                    ret.int.*.valuePtr = valuePtr;
                } else {
                    std.log.err("State path {s} not found or not parseable to i32", .{statePath});
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .float => {
                ret.* = .{ .float = try allocator.create(FloatMenuItem) };
                ret.float.*.menuProperties.bounds = bounds;
                ret.float.*.menuProperties.statePath = try allocator.dupe(u8, statePath);
                // ret.float.*.menuProperties.elementType = try getValidUiElementTypeByMenuType(.float, itemDefPtr.elementType);
                ret.float.*.menuProperties.elementType = std.meta.stringToEnum(mi.UiElementType, itemDef.elementType);
                ret.float.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDef.displayValuePrefix);
                ret.float.*.range = itemDef.range;
                if(fieldPtrByPathExpect(f32, state, statePath)) |valuePtr| {
                    ret.float.*.valuePtr = valuePtr;
                } else {
                    std.log.err("State path {s} not found or not parseable to f32", .{statePath});
                    return DevMenuError.StateFieldNotFound;
                }
            },
            .string => {
                ret.* = .{ .string = try allocator.create(StringMenuItem) };
                ret.string.*.menuProperties.bounds = bounds;
                ret.string.*.menuProperties.statePath = try allocator.dupe(u8, statePath);
                // ret.string.*.menuProperties.elementType = try getValidUiElementTypeByMenuType(.string, itemDefPtr.elementType);
                ret.string.*.menuProperties.elementType = std.meta.stringToEnum(mi.UiElementType, itemDef.elementType);
                ret.string.*.menuProperties.displayValuePrefix = try allocator.dupe(u8, itemDef.displayValuePrefix);
                if(fieldPtrByPathExpect([]const u8, state, statePath)) |valuePtr| {
                    ret.string.*.valuePtr = valuePtr;
                } else {
                    std.log.err("State path {s} not found or not parseable to string", .{statePath});
                    return DevMenuError.StateFieldNotFound;
                }
            },
            }
            return ret;
        }

        // const VALID_INT_UI_ELEMENTS = [_]mi.UiElementType{mi.UiElementType.SLIDER, mi.UiElementType.VALUE_BOX};
        // const VALID_FLOAT_UI_ELEMENTS = [_]mi.UiElementType{mi.UiElementType.SLIDER};
        // const VALID_STRING_UI_ELEMENTS = [_]mi.UiElementType{};

        // fn getValidUiElementType(uiElementType: []const u8, validOnes: []mi.UiElementType) !mi.UiElementType {
        //     const optionalParse = std.meta.stringToEnum(mi.UiElementType, uiElementType);
        //     if (optionalParse) |parsed|  {
        //         std.mem.containsAtLeast(mi.UiElementType, validOnes, 1, parsed);
        //     } else {
        //         return mi.UiElementError.DoesNotExist;
        //     }
        // }
        // fn getValidUiElementTypeByMenuType(menuItemType: MenuItemType, uiElementType: []const u8) !mi.UiElementType {
        //     switch(menuItemType) {
        //         .int => {
        //            return try getValidUiElementType(uiElementType, &VALID_INT_UI_ELEMENTS);
        //         },
        //         .float => {
        //             return try getValidUiElementType(uiElementType, &VALID_FLOAT_UI_ELEMENTS);
        //         },
        //         .string => {
        //             return try getValidUiElementType(uiElementType, &VALID_STRING_UI_ELEMENTS);
        //         },
        //
        //     }
        // }

        const ITEM_WIDTH = 50;
        const ITEM_HEIGHT = 10;
        const ITEM_PADDING = 4;

        pub fn BuildMenuItems(
            itemDefs: []mi.YamlItemDef,
            state: *T,
            allocator: std.mem.Allocator
        ) ![]*MenuItem {
            var ret = std.array_list.Managed(*MenuItem).init(allocator);
            var y: f32 = ITEM_PADDING;
            var menuError: ?anyerror = undefined;
            for (itemDefs) |itemDef| {
                if(GetMenuItem(
                    itemDef,
                    Rectangle{ .width = ITEM_WIDTH, .height = ITEM_HEIGHT, .x = ITEM_PADDING + 20, .y = y },
                    state,
                    allocator
                )) |menuItem| {
                    try ret.append(menuItem);
                } else |err| {
                    menuError = err;
                }
                y = y + ITEM_HEIGHT + ITEM_PADDING;
            }

            return try ret.toOwnedSlice();
        }

        pub fn GetMenuItemsFromFile(
            filePath: []const u8,
            state: *T,
            allocator: std.mem.Allocator
        ) ![]*MenuItem {
            const yml_location = filePath;
            const yml_path = try std.fs.cwd().realpathAlloc(
                allocator,
                yml_location,
            );
            defer allocator.free(yml_path);

            var ymlz = try Ymlz(mi.YamlMenuDef).init(allocator);
            const result = try ymlz.loadFile(yml_path);
            defer ymlz.deinit(result);
            for(result.itemDefs, 0..) |itemDef, index| {
                std.debug.print("{d}\n", .{index});
                std.debug.print("display {s}\n", .{itemDef.displayValuePrefix});
                std.debug.print("elementType {s}\n", .{itemDef.elementType});
                std.debug.print("menuItem {s}\n", .{itemDef.menuItemType});
                std.debug.print("statePath {s}\n", .{itemDef.statePath});
            }

            return BuildMenuItems(result.itemDefs, state, allocator);
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
