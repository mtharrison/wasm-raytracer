// zig@0.6.0
// Build:
// $ zig build-lib --release-fast --output-dir ./pkg/ -target wasm32-freestanding-none lib.zig

const AtomicOrder = @import("builtin").AtomicOrder;
const Vector = @import("vector.zig").Vector(f32);

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const allocator = std.heap.page_allocator;

const Math = std.math;
const json = std.json;

// Location for MMIO, Vector pointer and vector length will be put there.
var arg_ptr = [_]usize{0, 0};

const SELF_INTERSECTION_THRESHOLD: f32 = 0.001;

const Ray = struct {
    point: Vector,
    vector: Vector,
};

const ObjectType = enum {
    Plane,
    Sphere,
};

const Scene = struct {
    const Camera = struct {
        point: Vector,
        vector: Vector,
        fov: f32,
    };
    camera: Camera,

    const Object = struct {
        @"type": ObjectType,
        point: Vector,
        color: Vector,
        specular: f32,
        lambert: f32,
        ambient: f32,
        radius: f32 = 0.0,
        normal: Vector = Vector.new(0.0, 0.0, 0.0),
    };

    objects: []Object,
    lights: []Vector,
    checker: []Vector,
};


export fn __wbindgen_global_argument_ptr() usize {
    @fence(AtomicOrder.SeqCst);
    return @ptrToInt(&arg_ptr);
}

export fn __wbindgen_free_u8(ptr: u32, len: u32) void {
    @fence(AtomicOrder.SeqCst);
    allocator.free(@intToPtr([*]u8, ptr)[0..len]);
}

export fn __wbindgen_free_f32(ptr: u32, len: u32) void {
    @fence(AtomicOrder.SeqCst);
    allocator.free(@intToPtr([*]volatile f32, ptr)[0..len]);
}

export fn __wbindgen_malloc_u8(len: u32) usize {
    @fence(AtomicOrder.SeqCst);
    const mem = allocator.alloc(u8, len) catch unreachable;
    return @ptrToInt(mem.ptr);
}

fn closer(a: ?f32, b: ?f32) bool {
    if (a !=null and b != null)
        return (a.? > SELF_INTERSECTION_THRESHOLD and a.? < b.?);

    if (a == null and b == null)
        return false;

    return a orelse 0.0 > SELF_INTERSECTION_THRESHOLD;
}

const IntersectionResult = struct {
    distance: ?f32,
    object: ?Scene.Object,
};

fn intersect_scene(ray: Ray, scene: Scene) IntersectionResult {
    var closest = IntersectionResult{ .distance = null, .object = null };

    for (scene.objects) |object| {
        var distance = object_intersection(object, ray);
        if (closer(distance, closest.distance)) {
            closest = IntersectionResult{
                .distance = distance,
                .object = object
            };
        }
    }

    return closest;
}
fn object_intersection(object: Scene.Object, ray: Ray) ?f32 {
    return switch (object.type) {
        ObjectType.Sphere => blk: {
            const eye_to_center = object.point.subtract(ray.point);
            const v = eye_to_center.dot_product(ray.vector);
            const eo_dot = eye_to_center.dot_product(eye_to_center);
            const discriminant = (object.radius * object.radius) - eo_dot + (v * v);

            if (discriminant < 0.0) {
                return null;
            }

            const distance = v - Math.sqrt(discriminant);

            if (distance > SELF_INTERSECTION_THRESHOLD) {
                return distance;
            }

            break :blk null;
        },
        ObjectType.Plane =>  blk: {
            const neg_norm = object.normal.negate();
            const denom = neg_norm.dot_product(ray.vector);

            if (denom <= 0.0) {
                return null;
            }

            const interm = object.point.subtract(ray.point);
            break :blk interm.dot_product(neg_norm) / denom;
        },
        else => null

    };
}


fn plane_color_at(point_at_time: Vector, plane: Scene.Object, scene: Scene) Vector {
    // Point from plane origin
    // This is a complete hack to make up for my sad lack of lin alg. knowledge

    const from_origin = point_at_time.subtract(plane.point);
    const width = 2.0;

    var px = Vector.new(0.0, 1.0, 0.0);
    var py = Vector.new(0.0, 0.0, 1.0);

    if (plane.normal.z != 0.0) {
        py = Vector.new(1.0, 0.0, 1.0);
    }

    if (plane.normal.y != 0.0) {
        px = Vector.new(0.0, 0.0, 1.0);
        py = Vector.new(1.0, 0.0, 0.0);
    }

    const cx = px.dot_product(from_origin);
    const cy = py.dot_product(from_origin);

    const x_cond = (cx < 0.0 and @rem(cx, width) < -width / 2.0) or (cx > 0.0 and @rem(cx, width) < width / 2.0);
    const y_cond = (cy < 0.0 and @rem(cy, width) < -width / 2.0) or (cy > 0.0 and @rem(cy, width) < width / 2.0);

    if ((x_cond and !y_cond) or (y_cond and !x_cond)) {
        return scene.checker[0].scale(1.0);
    }

    return scene.checker[1].scale(1.0);
}

fn get_normal(object: Scene.Object, pos: Vector) Vector {
    return switch (object.type) {
        ObjectType.Sphere => pos.subtract(object.point).unit(),
        ObjectType.Plane => object.normal.unit(),
        else => Vector.new(0.0, 0.0, 0.0),
    };
}

fn surface(
    ray: Ray,
    scene: Scene,
    object: Scene.Object,
    point_at_time: Vector,
    normal: Vector,
    depth: usize,
) Vector {
    var lambert = object.lambert;
    var specular = object.specular;
    var ambient = object.ambient;
    var b = switch (object.type) {
        ObjectType.Sphere => object.color.scale(1.0),
        ObjectType.Plane => plane_color_at(point_at_time, object, scene),
    };

    var c = Vector.zero();
    var lambert_amount: f32 = 0.0;

    if (lambert > 0.0) {
        for (scene.lights) |light| {
            if (!is_light_visible(point_at_time, scene, light)) {
                continue;
            }

            const contribution = light.subtract(point_at_time).unit().dot_product(normal);

            if (contribution > 0.0) {
                lambert_amount += contribution;
            }
        }
    }

    if (specular > 0.0) {
        const reflected_ray = Ray{
            .point = point_at_time,
            .vector = ray.vector.reflect_through(normal),
        };
        const reflected_color = trace(reflected_ray, scene, depth + 1);
        if (reflected_color != null) {
            c = c.add(reflected_color.?.scale(specular));
        }
    }

    lambert_amount = min(lambert_amount, 1.0);
    return c.add3(b.scale(lambert_amount * lambert), b.scale(ambient));
}

fn trace(ray: Ray, scene: Scene, depth: usize)  ?Vector {
    if (depth > 2) {
        return null;
    }

    var dist_object = intersect_scene(ray, scene);

    return if (dist_object.distance) |distance| (
        if (dist_object.object) |collision| blk: {
            const point_in_time = ray.point.add(ray.vector.scale(distance));
            break :blk surface(
                ray,
                scene,
                collision,
                point_in_time,
                get_normal(collision, point_in_time),
                depth
            );
        } else Vector.zero()
    ) else Vector.zero();
}


fn render(scene_str: []const u8, width: u32, height: u32) []f32 {
    const options = json.ParseOptions{ .allocator = allocator };
    const scene = json.parse(Scene, &json.TokenStream.init(scene_str), options) catch unreachable;
    defer json.parseFree(Scene, scene, options);

    const camera = scene.camera;
    const eye_vector = camera.vector.subtract(camera.point).unit();
    const vp_right = eye_vector.cross_product(Vector.up()).unit();
    const vp_up = vp_right.cross_product(eye_vector).unit();

    const fov_radians = Math.pi * (camera.fov / 2.0) / 180.0;
    const height_width_ratio = @intToFloat(f32, height) / @intToFloat(f32, width);
    const half_width = Math.tan(fov_radians);
    const half_height = height_width_ratio * half_width;
    const camera_width = half_width * 2.0;
    const camera_height = half_height * 2.0;
    const pixel_width = camera_width / (@intToFloat(f32, width) - 1.0);
    const pixel_height = camera_height / (@intToFloat(f32, height) - 1.0);

    var ray = Ray{
        .point = camera.point,
        .vector = Vector.up(),
    };


    var len = width * height * 4;
    var x: u32 = 0;
    var y: u32 = 0;

    var result = allocator.alloc(f32, len) catch unreachable;

    while (y < height) {
        x = 0;
        while( x < width) {
            const i = 4 * (y * width + x);
            const x_comp = vp_right.scale((@intToFloat(f32, x) * pixel_width) - half_width);
            const y_comp = vp_up.scale((@intToFloat(f32, y) * pixel_height) - half_height);

            ray.vector = eye_vector.add3(x_comp, y_comp).unit();

            const color = trace(ray, scene, 0) orelse Vector.new(0.0, 0.0, 0.0);

            result[i + 0] = @floatCast(f32, color.x);
            result[i + 1] = @floatCast(f32, color.y);
            result[i + 2] = @floatCast(f32, color.z);
            result[i + 3] = 255.0;
            x += 1;
        }
        y += 1;
    }

    return result;
}

fn is_light_visible(point: Vector, scene: Scene, light: Vector) bool {
    const point_to_light_vector = light.subtract(point);
    const distance_to_light = point_to_light_vector.length();

    const ray = Ray {
        .point = point,
        .vector = point_to_light_vector.unit(),
    };
    const res = intersect_scene(ray, scene);
    return if (res.distance != null) res.distance.? > distance_to_light else true;
}

fn min(a: f32, b: f32) f32 {
    return if (a > b) b else a;
}

export fn binding(retptr: u32, ptr_scene: u32, len_scene: u32, width: u32, height: u32) void {
    @fence(AtomicOrder.SeqCst);
    const input = @intToPtr([*]u8, ptr_scene)[0..len_scene];
    defer allocator.free(input);

    var result = render(input, width, height);

    @intToPtr([*]volatile usize, retptr).* = @ptrToInt(result.ptr);
    @intToPtr([*]volatile usize, retptr + 4).* = width * height * 4;
}

const testing = std.testing;
test "json.parse" {

    const test_json =
    \\ {
    \\     "camera": {
    \\         "point":{"x":0,"y":0,"z":7},
    \\         "vector":{"x":0,"y":0,"z":0},
    \\         "fov":70
    \\     },
    \\     "objects":[
    \\         {"type":"Sphere","point":{"x":0.17989201943833377,"y":0.11992801295888919,"z":2.9946016198056125},"color":{"x":0,"y":0,"z":0},"specular":0.7,"lambert":0.5,"ambient":0.3,"radius":1},
    \\         {"type":"Sphere","point":{"x":-0.17989201943833377,"y":-1.9964010798704084,"z":-2.9946016198056125},"color":{"x":0,"y":0,"z":0},"specular":0.7,"lambert":0.5,"ambient":0.3,"radius":1},
    \\         {"type":"Sphere","point":{"x":0,"y":0,"z":0},"color":{"x":255,"y":255,"z":255},"specular":0.25,"lambert":0.72,"ambient":0.26,"radius":1.5},
    \\         {"type":"Plane","point":{"x":0,"y":5,"z":0},"normal":{"x":0,"y":-1,"z":0},"color":{"x":200,"y":200,"z":200},"specular":0,"lambert":0.9,"ambient":0.2},
    \\         {"type":"Plane","point":{"x":0,"y":-5,"z":0},"normal":{"x":0,"y":1,"z":0},"color":{"x":100,"y":100,"z":100},"specular":0,"lambert":0.9,"ambient":0.2},
    \\         {"type":"Plane","point":{"x":-5,"y":0,"z":0},"normal":{"x":1,"y":0,"z":0},"color":{"x":100,"y":100,"z":100},"specular":0,"lambert":0.9,"ambient":0.2},
    \\         {"type":"Plane","point":{"x":5,"y":0,"z":0},"normal":{"x":-1,"y":0,"z":0},"color":{"x":100,"y":100,"z":100},"specular":0,"lambert":0.9,"ambient":0.2},
    \\         {"type":"Plane","point":{"x":0,"y":0,"z":-12},"normal":{"x":0,"y":0,"z":1},"color":{"x":100,"y":100,"z":100},"specular":0,"lambert":0.9,"ambient":0.2},
    \\         {"type":"Plane","point":{"x":0,"y":0,"z":12},"normal":{"x":0,"y":0,"z":-1},"color":{"x":100,"y":100,"z":100},"specular":0,"lambert":0.9,"ambient":0.2}
    \\     ],
    \\     "checker":[
    \\         {"x":50,"y":0,"z":89},
    \\         {"x":92,"y":209,"z":92}
    \\     ],
    \\     "lights":[
    \\         {"x":3,"y":3,"z":5}
    \\     ]
    \\ }
    ;

    var result = render(test_json, 10, 10);


    // just testing if it fails
    testing.expect(result.len == 400);
}
