const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

pub const Platform = struct {
    rec: Rectangle,

    pub fn init(pos: Vector2, width: f32) Platform {
       return .{
           .rec = .{
               .x = pos.x,
               .y = pos.y,
               .width = width,
               .height = 10
           }
       };
    }
};