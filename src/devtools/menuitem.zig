const std = @import("std");

const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

const Ymlz = @import("ymlz").Ymlz;

pub const UiElementType = enum {
    SLIDER,
};

pub const MenuItemType = enum { int, float, string, none };

pub const MenuItemValuePtr = union(MenuItemType) { int: *i32, float: *f32, string: *[]const u8, none: void };

const BaseMenuItem = struct {
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
        return BaseMenuItem{ .elementType = elementType, .bounds = bounds, .displayValuePrefix = displayValuePrefix, .statePath = statePath };
    }
};

pub const IntMenuItem = struct {
    valuePtr: *i32,
    menuProperties: BaseMenuItem,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *i32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8) Self {
        return IntMenuItem{
            .valuePtr = valuePtr,
            .menuProperties = BaseMenuItem.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }
};

pub const FloatMenuItem = struct {
    valuePtr: *f32,
    menuProperties: BaseMenuItem,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *f32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8) Self {
        return FloatMenuItem{
            .valuePtr = valuePtr,
            .menuProperties = BaseMenuItem.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }
};

pub const StringMenuItem = struct {
    valuePtr: *[]const u8,
    menuProperties: BaseMenuItem,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *[]const u8, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8) Self {
        return StringMenuItem{
            .valuePtr = valuePtr,
            .menuProperties = BaseMenuItem.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }
};

pub const MenuItem = union(MenuItemType) {
    int: *IntMenuItem,
    float: *FloatMenuItem,
    string: *StringMenuItem,
    none: void,

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

    pub fn isNone(self: MenuItem) bool {
        return self == .none;
    }
};

pub const ItemDef = struct {
    menuItemType: []u8,
    statePath: []u8,
    elementType: []u8,
    bounds: Rectangle, // Not implemented
    displayValuePrefix: []u8,
};

pub const MenuDef = struct {
    itemDefs: []*ItemDef,

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


fn duplicateString(string: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // std.debug.print("{s}:{d}\n", .{@src().fn_name, @src().line});
    // std.debug.print("{s}:{d} {s} len: {d}\n", .{@src().fn_name, @src().line, string, string.len});
    // std.debug.print("{s}:{d}\n", .{@src().fn_name, @src().line});
    if(allocator.alloc(u8, string.len)) |stringCopy| {
        @memcpy(stringCopy, string);
        return stringCopy;
    } else |err| {
        std.log.err("{s}:{d} Failed to copy string {s}\n", .{@src().fn_name, @src().line, string});
        return err;
    }
}

pub fn GetMenuDefFromFile(filePath: []const u8, allocator: std.mem.Allocator) !*MenuDef {
    const IntermediateItemDef = struct {
        menuItemType: []const u8,
        statePath: []const u8,
        elementType: []const u8,
        displayValuePrefix: []const u8,
    };
    const IntermediateMenuDef = struct {
        itemDefs: []IntermediateItemDef
    };
    const yml_location = filePath;

    const yml_path = try std.fs.cwd().realpathAlloc(
        allocator,
        yml_location,
    );
    defer allocator.free(yml_path);

    var ymlz = try Ymlz(IntermediateMenuDef).init(allocator);
    const result = try ymlz.loadFile(yml_path);
    defer ymlz.deinit(result);

    const ret = try allocator.create(MenuDef);

    ret.*.itemDefs = try allocator.alloc(*ItemDef, result.itemDefs.len);

    for (result.itemDefs, 0..) |itemDef, index| {
        const newItemDef = try allocator.create(ItemDef);
        newItemDef.displayValuePrefix = try duplicateString(itemDef.displayValuePrefix, allocator);
        newItemDef.elementType = try duplicateString(itemDef.elementType, allocator);
        newItemDef.menuItemType = try duplicateString(itemDef.menuItemType, allocator);
        newItemDef.statePath = try duplicateString(itemDef.statePath, allocator);
        newItemDef.bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
        ret.*.itemDefs[index] = newItemDef;
    }

    return ret;
}

pub const MenuItemTypeError = error{MenuItemTypeUnknown};

const testing = std.testing;
const expect = testing.expect;

test "IntMenuItem can build" {
    var intValue: i32 = 420;
    const menuItem = IntMenuItem.init(UiElementType.SLIDER, &intValue, Rectangle{ .width = 1, .height = 2, .y = 3, .x = 4 }, "player.points", "player.points");
    const returnedIntValue = menuItem.valuePtr.*;

    try testing.expectEqual(intValue, returnedIntValue);
}
