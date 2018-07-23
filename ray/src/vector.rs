#[derive(Debug, Serialize, Deserialize)]
pub struct Vector {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Vector {
    pub fn new(x: f32, y: f32, z: f32) -> Vector {
        Vector { x, y, z }
    }

    pub fn up() -> Vector {
        Vector {
            x: 0.0,
            y: 1.0,
            z: 0.0,
        }
    }

    pub fn zero() -> Vector {
        Vector {
            x: 0.0,
            y: 0.0,
            z: 0.0,
        }
    }

    pub fn white() -> Vector {
        Vector {
            x: 255.0,
            y: 255.0,
            z: 255.0,
        }
    }

    pub fn dot_product(&self, v: &Vector) -> f32 {
        (self.x * v.x) + (self.y * v.y) + (self.z * v.z)
    }

    pub fn cross_product(&self, v: &Vector) -> Vector {
        Vector {
            x: (self.y * v.z) - (self.z * v.y),
            y: (self.z * v.x) - (self.x * v.z),
            z: (self.x * v.y) - (self.y * v.x),
        }
    }

    pub fn scale(&self, factor: f32) -> Vector {
        Vector {
            x: self.x * factor,
            y: self.y * factor,
            z: self.z * factor,
        }
    }

    pub fn unit(&self) -> Vector {
        self.scale(1.0 / self.length())
    }

    pub fn add(&self, v: &Vector) -> Vector {
        Vector {
            x: self.x + v.x,
            y: self.y + v.y,
            z: self.z + v.z,
        }
    }

    pub fn add3(&self, v: &Vector, w: &Vector) -> Vector {
        Vector {
            x: self.x + v.x + w.x,
            y: self.y + v.y + w.y,
            z: self.z + v.z + w.z,
        }
    }

    pub fn subtract(&self, v: &Vector) -> Vector {
        Vector {
            x: self.x - v.x,
            y: self.y - v.y,
            z: self.z - v.z,
        }
    }

    pub fn negate(&self) -> Vector {
        Vector {
            x: -self.x,
            y: -self.y,
            z: -self.z,
        }
    }

    pub fn length(&self) -> f32 {
        self.dot_product(self).sqrt()
    }

    pub fn reflect_through(&self, normal: &Vector) -> Vector {
        let a = self.dot_product(normal);
        let d = normal.scale(a);
        let e = d.scale(2.0);
        self.subtract(&e)
    }
}
