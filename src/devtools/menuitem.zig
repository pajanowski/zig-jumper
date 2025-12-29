const std = @import("std");

const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

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
    menuItemTypeString: []u8,
    statePath: []u8,
};

// rename
pub const YamlItemDef = struct {
    elementType: []const u8,
    bounds: Rectangle, // Not implemented
    statePath: []const u8, // NotImplemented
    displayValuePrefix: []const u8,
    menuItemType: []const u8,
};

pub const YamlMenuDef = struct {
    itemDefs: []YamlItemDef
};

pub fn GetItemDefsFromFile(filePath: []const u8, allocator: std.mem.Allocator) ![]*ItemDef {
    var ret = std.array_list.Managed(*ItemDef).init(allocator);
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    var file_buffer: [1024]u8 = undefined;
    var reader = file.reader(&file_buffer);

    var line_no: usize = 0;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        line_no += 1;
        std.debug.print("{d}--{s}\n", .{ line_no, line });
        if (line[0] == '#') {
            continue;
        }

        var it = std.mem.splitAny(u8, line, ",");
        const itemDef = try allocator.create(ItemDef);
        const statePathFromIt = it.next() orelse "";
        itemDef.*.statePath = try allocator.alloc(u8, statePathFromIt.len);
        @memcpy(itemDef.*.statePath, statePathFromIt);
        // jumper.gravity,float,SLIDER,Gravity

        const menuItemTypeString = it.next() orelse "";
        itemDef.*.menuItemTypeString = try allocator.alloc(u8, menuItemTypeString.len);
        @memcpy(itemDef.*.menuItemTypeString, menuItemTypeString);

        // TODO here is where I need to decide what to do
        // Current, the valuePtr union is always coming back string which is probably because its never
        // getting initialized.
        //
        // It should be getting initialized based on the field type

        // itemDef.*.valuePtr = try allocator.create(MenuItemValuePtr);
        // itemDef.*.valuePtr.
        _ = it.next(); // ui type,
        _ = it.next(); // label
        try ret.append(itemDef);
    }

    return ret.items;
}

pub const MenuItemTypeError = error{MenuItemTypeUnknown};

const testing = std.testing;
const expect = testing.expect;

test "IntMenuItem can build" {
    var intValue: i32 = 420;
    const menuItem = IntMenuItem.init(UiElementType.SLIDER, &intValue, Rectangle{ .width = 1, .height = 2, .y = 3, .x = 4 }, "player.points");
    const returnedIntValue = menuItem.valuePtr.*;

    try testing.expectEqual(intValue, returnedIntValue);
}
