const std = @import("std");

const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

const Ymlz = @import("ymlz").Ymlz;

pub const UiElementType = enum {
    SLIDER,
};

pub const MenuItemType = enum { int, float, string };

pub const MenuItemValuePtr = union(MenuItemType) { int: *i32, float: *f32, string: *[]const u8 };

pub const Range = struct {
    upper: f32,
    lower: f32,
    pub const Error = error {
        InvalidRange
    };
    pub fn init(
        lower: f32,
        upper: f32,
    ) !Range {
       if (lower >= upper) {
          return Error.InvalidRange;
       } else {
           return .{.upper = upper, .lower = lower};
       }
    }
};

pub const MenuProperties = struct {
    elementType: UiElementType,
    bounds: Rectangle, // Not implemented
    statePath: []const u8, // NotImplemented
    displayValuePrefix: []const u8,
    const Self = @This();

    pub fn init(
        elementType: UiElementType,
        bounds: Rectangle,
        displayValuePrefix: []const u8,
        statePath: []const u8,
    ) Self {
        return MenuProperties{ .elementType = elementType, .bounds = bounds, .displayValuePrefix = displayValuePrefix, .statePath = statePath };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.displayValuePrefix);
        allocator.free(self.statePath);
    }
};

pub const IntMenuItem = struct {
    valuePtr: *i32,
    menuProperties: MenuProperties,
    range: Range,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *i32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8, range: Range) Self {
        return IntMenuItem{
            .valuePtr = valuePtr,
            .range = range,
            .menuProperties = MenuProperties.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const FloatMenuItem = struct {
    valuePtr: *f32,
    menuProperties: MenuProperties,
    range: Range,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *f32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8, range: Range) Self {
        return FloatMenuItem{
            .valuePtr = valuePtr,
            .range = range,
            .menuProperties = MenuProperties.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const StringMenuItem = struct {
    valuePtr: *[]const u8,
    menuProperties: MenuProperties,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *[]const u8, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8) Self {
        return StringMenuItem{
            .valuePtr = valuePtr,
            .menuProperties = MenuProperties.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const MenuItem = union(MenuItemType) {
    int: *IntMenuItem,
    float: *FloatMenuItem,
    string: *StringMenuItem,

    pub fn getType(self: MenuItem) MenuItemType {
        return @as(MenuItemType, self);
    }

    pub fn isInt(self: MenuItem) bool {
        return self == .int;
    }

    pub fn isFloat(self: MenuItem) bool {
        return self == .float;
    }

    pub fn isString(self: MenuItem) bool {
        return self == .string;
    }

    pub fn getMenuProperties(self: *MenuItem) MenuProperties {
        switch (self.*) {
            .int => |active| return active.*.menuProperties,
            .float => |active| return active.*.menuProperties,
            .string => |active| return active.*.menuProperties,
        }
    }

    pub fn getRange(self: *MenuItem) Range {
        switch (self.*) {
            .int => |active| return active.*.range,
            .float => |active| return active.*.range,
            .string => {
                std.log.err("String menuItem does not have range", .{});
                unreachable;
            },
        }
    }

    pub fn deinit(self: *MenuItem, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .int => |val| val.deinit(allocator),
            .float => |val| val.deinit(allocator),
            .string => |val| val.deinit(allocator),
        }
        allocator.destroy(self);
    }
};

pub const MenuDef = struct {
    itemDefs: []ItemDef,

    pub fn deinit(self: *MenuDef, allocator: std.mem.Allocator) void {
        for (self.itemDefs) |itemDef| {
            allocator.free(itemDef.menuItemType);
            allocator.free(itemDef.statePath);
            allocator.free(itemDef.elementType);
            allocator.free(itemDef.displayValuePrefix);
            allocator.destroy(itemDef);
        }
        allocator.free(self.itemDefs);
        allocator.destroy(self);
    }
};


pub const ItemDef = struct {
    menuItemType: []const u8,
    statePath: []const u8,
    elementType: []const u8,
    bounds: Rectangle,
    displayValuePrefix: []const u8,
    range: Range,
};

pub const MenuItemTypeError = error{MenuItemTypeUnknown};

const testing = std.testing;
const expect = testing.expect;

test "IntMenuItem can build" {
    var intValue: i32 = 420;
    const menuItem = IntMenuItem.init(UiElementType.SLIDER, &intValue, Rectangle{ .width = 1, .height = 2, .y = 3, .x = 4 }, "player.points", "player.points", try Range.init(0, 100));
    const returnedIntValue = menuItem.valuePtr.*;

    try testing.expectEqual(intValue, returnedIntValue);
}
