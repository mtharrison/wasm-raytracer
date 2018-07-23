// Configs

#![feature(use_extern_macros, wasm_import_module, wasm_custom_section)]

// Extern crates

extern crate serde;
extern crate serde_json;
#[macro_use]
extern crate serde_derive;
extern crate wasm_bindgen;

// Load modules

mod vector;

// Use statements

use vector::Vector;
use wasm_bindgen::prelude::*;

#[derive(Serialize, Deserialize)]
pub struct Camera {
    pub point: Vector,
    pub vector: Vector,
    pub fov: f32,
}

struct Ray<'a> {
    point: &'a Vector,
    vector: Vector,
}

#[derive(Serialize, Deserialize)]
pub struct Sphere {
    pub point: Vector,
    pub color: Vector,
    pub specular: f32,
    pub lambert: f32,
    pub ambient: f32,
    pub radius: f32,
}

#[derive(Serialize, Deserialize)]
pub struct Scene {
    pub camera: Camera,
    pub objects: Vec<Sphere>,
    pub lights: Vec<Vector>,
}

#[wasm_bindgen]
pub fn binding(scene: String, width: f32, height: f32) -> Vec<f32> {
    let s: Scene = serde_json::from_str(&scene).unwrap();
    render(s, width, height)
}

pub fn render(scene: Scene, width: f32, height: f32) -> Vec<f32> {
    let mut result = Vec::new();
    let camera = &scene.camera;

    let eye_vector = camera.vector.subtract(&camera.point).unit();
    let vp_right = eye_vector.cross_product(&Vector::up()).unit();
    let vp_up = vp_right.cross_product(&eye_vector).unit();

    let fov_radians = std::f32::consts::PI * (camera.fov / 2.0) / 180.0;
    let height_width_ratio = height / width;
    let half_width = fov_radians.tan();
    let half_height = height_width_ratio * half_width;
    let camera_width = half_width * 2.0;
    let camera_height = half_height * 2.0;
    let pixel_width = camera_width / (width - 1.0);
    let pixel_height = camera_height / (height - 1.0);

    let mut ray = Ray {
        point: &camera.point,
        vector: Vector::up(),
    };

    for y in 0..height as u32 {
        for x in 0..width as u32 {
            let x_comp = vp_right.scale((x as f32 * pixel_width) - half_width);
            let y_comp = vp_up.scale((y as f32 * pixel_height) - half_height);

            ray.vector = eye_vector.add3(&x_comp, &y_comp).unit();

            let color = trace(&ray, &scene, 0).unwrap();

            result.push(color.x);
            result.push(color.y);
            result.push(color.z);
            result.push(255.0);
        }
    }

    result
}

fn trace(ray: &Ray, scene: &Scene, depth: usize) -> Option<Vector> {
    if depth > 2 {
        return None;
    }

    let dist_object = intersect_scene(ray, scene);

    match dist_object.0 {
        None => Some(Vector::zero()),
        Some(distance) => {
            let collision = dist_object.1;
            match collision {
                None => Some(Vector::zero()),
                Some(object) => {
                    let point_in_time = ray.point.add(&ray.vector.scale(distance));
                    Some(surface(
                        &ray,
                        &scene,
                        &object,
                        &point_in_time,
                        &sphere_normal(&object, &point_in_time),
                        depth,
                    ))
                }
            }
        }
    }
}

fn closer(a: &Option<f32>, b: &Option<f32>) -> bool {
    match a {
        None => false,
        Some(a_distance) => match b {
            None => true,
            Some(b_distance) => a_distance < b_distance,
        },
    }
}

fn intersect_scene<'a>(ray: &Ray, scene: &'a Scene) -> (Option<f32>, Option<&'a Sphere>) {
    let mut closest = (None, None);

    for object in &scene.objects {
        let distance = sphere_intersection(object, ray);
        if closer(&distance, &closest.0) {
            closest = (distance, Some(object));
        }
    }

    closest
}

fn sphere_intersection(sphere: &Sphere, ray: &Ray) -> Option<f32> {
    let eye_to_center = sphere.point.subtract(&ray.point);
    let v = eye_to_center.dot_product(&ray.vector);
    let eo_dot = eye_to_center.dot_product(&eye_to_center);
    let discriminant = (sphere.radius * sphere.radius) - eo_dot + (v * v);

    if discriminant < 0.0 {
        return None;
    }

    return Some(v - discriminant.sqrt());
}

fn sphere_normal(sphere: &Sphere, pos: &Vector) -> Vector {
    pos.subtract(&sphere.point).unit()
}

fn surface(
    ray: &Ray,
    scene: &Scene,
    object: &Sphere,
    point_at_time: &Vector,
    normal: &Vector,
    depth: usize,
) -> Vector {
    let b = &object.color;
    let mut c = Vector::zero();
    let mut lambert_amount = 0.0;

    if object.lambert > 0.0 {
        for light in &scene.lights {
            if !is_light_visible(point_at_time, scene, light) {
                continue;
            }

            let contribution = light.subtract(point_at_time).unit().dot_product(normal);

            if contribution > 0.0 {
                lambert_amount += contribution;
            }
        }
    }

    if object.specular > 0.0 {
        let reflected_ray = Ray {
            point: point_at_time,
            vector: ray.vector.reflect_through(normal),
        };
        let reflected_color = trace(&reflected_ray, scene, depth + 1);
        match reflected_color {
            Some(color) => {
                c = c.add(&color.scale(object.specular));
            }
            _ => {}
        }
    }

    lambert_amount = min(lambert_amount, 1.0);

    c.add3(
        &b.scale(lambert_amount * object.lambert),
        &b.scale(object.ambient),
    )
}

fn is_light_visible(point: &Vector, scene: &Scene, light: &Vector) -> bool {
    let ray = Ray {
        point,
        vector: point.subtract(light).unit(),
    };
    let (dist, _) = intersect_scene(&ray, scene);
    match dist {
        None => false,
        Some(distance) => distance > -0.005,
    }
}

fn min(a: f32, b: f32) -> f32 {
    if a > b {
        return b;
    }
    a
}
