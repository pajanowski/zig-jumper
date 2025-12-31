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

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.displayValuePrefix);
        allocator.free(self.statePath);
    }
};

pub const IntMenuItem = struct {
    valuePtr: *i32,
    menuProperties: BaseMenuItem,
    range: Range,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *i32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8, range: Range) Self {
        return IntMenuItem{
            .valuePtr = valuePtr,
            .range = range,
            .menuProperties = BaseMenuItem.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const FloatMenuItem = struct {
    valuePtr: *f32,
    menuProperties: BaseMenuItem,
    range: Range,

    const Self = @This();
    pub fn init(elementType: UiElementType, valuePtr: *f32, bounds: Rectangle, displayValuePrefix: []const u8, statePath: []const u8, range: Range) Self {
        return FloatMenuItem{
            .valuePtr = valuePtr,
            .range = range,
            .menuProperties = BaseMenuItem.init(elementType, bounds, displayValuePrefix, statePath),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.menuProperties.deinit(allocator);
        allocator.destroy(self);
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

    pub fn deinit(self: *MenuItem, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .int => |val| val.deinit(allocator),
            .float => |val| val.deinit(allocator),
            .string => |val| val.deinit(allocator),
            .none => {},
        }
        allocator.destroy(self);
    }
};

// pub const ItemDef = struct {
//     menuItemType: []u8,
//     statePath: []u8,
//     elementType: []u8,
//     bounds: Rectangle, // Not implemented
//     displayValuePrefix: []u8,
// };

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

const IntermediateItemDef = struct {
    menuItemType: []const u8,
    statePath: []const u8,
    elementType: []const u8,
    displayValuePrefix: []const u8,
    range: Range
};

const IntermediateMenuDef = struct {
    itemDefs: []IntermediateItemDef
};

// ... existing code ...
pub const ItemDef = struct {
    menuItemType: []u8,
    statePath: []u8,
    elementType: []u8,
    bounds: Rectangle,
    displayValuePrefix: []u8,
    range: Range,

    pub fn fromIntermediate(allocator: std.mem.Allocator, source: IntermediateItemDef) !*ItemDef {
        const self = try allocator.create(ItemDef);
        errdefer allocator.destroy(self);

        // Initialize with defaults to handle missing fields in source
        self.* = .{
            .menuItemType = &.{},
            .statePath = &.{},
            .elementType = &.{},
            .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .displayValuePrefix = &.{},
            .range = .{ .lower = 0, .upper = 1}
        };

        // Use comptime reflection to safely copy matching fields
        inline for (std.meta.fields(@TypeOf(source))) |f| {
            if (@hasField(ItemDef, f.name)) {
                const val = @field(source, f.name);
                if (@TypeOf(val) == []const u8) {
                    @field(self, f.name) = try allocator.dupe(u8, val);
                } else if (@TypeOf(val) == Range) {
                    @field(self, f.name) = val;
                }
            }
        }
        return self;
    }
};

pub fn GetMenuDefFromFile(filePath: []const u8, allocator: std.mem.Allocator) !*MenuDef {
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
    errdefer allocator.destroy(ret);

    ret.itemDefs = try allocator.alloc(*ItemDef, result.itemDefs.len);
    for (result.itemDefs, 0..) |item, i| {
        ret.itemDefs[i] = try ItemDef.fromIntermediate(allocator, item);
    }

    return ret;
}

pub const MenuItemTypeError = error{MenuItemTypeUnknown};

const testing = std.testing;
const expect = testing.expect;

test "IntMenuItem can build" {
    var intValue: i32 = 420;
    const menuItem = IntMenuItem.init(UiElementType.SLIDER, &intValue, Rectangle{ .width = 1, .height = 2, .y = 3, .x = 4 }, "player.points", "player.points", try Range.init(0, 100));
    const returnedIntValue = menuItem.valuePtr.*;

    try testing.expectEqual(intValue, returnedIntValue);
}
