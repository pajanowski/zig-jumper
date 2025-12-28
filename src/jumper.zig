const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

const GRAVITY: f32 = -280;
const JUMP_HEIGHT: f32 = 320;

pub const Jumper = struct {
    rec: Rectangle,
    vel: Vector2,
    settled: bool = false,
    jumperFloorPos: f32,

    gravity: f32 = GRAVITY,
    jumpPower: f32 = JUMP_HEIGHT,

    bounces: u16 = 0,


    pub fn init(pos: Vector2, jumperFloorPos: f32, jumperSize: f32) Jumper {
        return Jumper {
            .rec = Rectangle{.x = pos.x, .y = pos.y, .height = jumperSize, .width = jumperSize},
            .vel = Vector2{ .x = 0, .y = 0 },
            .jumperFloorPos = jumperFloorPos,
        };
    }

    pub fn bounce(self: *Jumper) void {
        if (!self.settled) {
            self.vel.y = self.vel.y + self.gravity * rl.getFrameTime();
        } else {
            self.vel.y = self.jumpPower;
            self.settled = false;
        }

        self.rec.y = self.rec.y - self.vel.y * rl.getFrameTime();

        if (self.rec.y > self.jumperFloorPos) {
            self.rec.y = self.jumperFloorPos;
            self.vel.y = 0;
            self.settled = true;
        }
    }
};
