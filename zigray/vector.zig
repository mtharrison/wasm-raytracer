const sqrt = @import("std").math.sqrt;

pub fn Vector(comptime T: type) type {
    return struct {
        const Self = @This();
        x: T,
        y: T,
        z: T,

        pub fn new(x: T, y: T, z: T) Self {
            return Self{ .x = x, .y = y, .z = z };
        }

        pub fn up() Self {
            return Self{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }

        pub fn zero() Self {
            return Self{ .x = 0.0, .y = 0.0, .z = 0.0 };
        }

        pub fn white() Self {
            return Self{ .x = 255.0, .y = 255.0, .z = 255.0 };
        }

        pub fn dot_product(self: Self, v: Self) T {
            return (self.x * v.x) + (self.y * v.y) + (self.z * v.z);
        }

        pub fn cross_product(self: Self, v: Self) Self {
            return Self {
                .x = (self.y * v.z) - (self.z * v.y),
                .y = (self.z * v.x) - (self.x * v.z),
                .z = (self.x * v.y) - (self.y * v.x),
            };
        }

        pub fn scale(self: Self, factor: T) Self {
            return Self {
                .x = self.x * factor,
                .y = self.y * factor,
                .z = self.z * factor,
            };
        }

        pub fn unit(self: Self) Self {
            return self.scale(1.0 / self.length());
        }

        pub fn add(self: Self, v: Self) Self {
            return Self {
                .x = self.x + v.x,
                .y = self.y + v.y,
                .z = self.z + v.z,
            };
        }

        pub fn add3(self: Self, v: Self, w: Self) Self {
            return Self {
                .x = self.x + v.x + w.x,
                .y = self.y + v.y + w.y,
                .z = self.z + v.z + w.z,
            };
        }

        pub fn subtract(self: Self, v: Self) Self {
            return Self {
                .x = self.x - v.x,
                .y = self.y - v.y,
                .z = self.z - v.z,
            };
        }

        pub fn negate(self: Self) Self {
            return Self {
                .x = -self.x,
                .y = -self.y,
                .z = -self.z,
            };
        }

        pub fn length(self: Self) T {
            return sqrt(self.dot_product(self));
        }

        pub fn reflect_through(self: Self, normal: Self) Self {
            const a = self.dot_product(normal);
            const d = normal.scale(a);
            const e = d.scale(2.0);
            return self.subtract(e);
        }
    };
}
