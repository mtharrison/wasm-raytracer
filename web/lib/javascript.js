import Vector from './vector'

const SELF_INTERSECTION_THRESHOLD = 0.001;

function trace(ray, scene, depth) {
    if (depth > 2) return;

    var distObject = intersectScene(ray, scene);

    if (distObject[0] === Infinity) {
        return Vector.ZERO;
    }

    var dist = distObject[0],
        object = distObject[1];

    var pointAtTime = Vector.add(ray.point, Vector.scale(ray.vector, dist));

    return surface(ray, scene, object, pointAtTime, surfaceNormal(object, pointAtTime), depth);
}

function intersectScene(ray, scene) {
    var closest = [Infinity, null];
    for (var i = 0; i < scene.objects.length; i++) {
        var object = scene.objects[i];
        let dist;
        if (object.type === 'Sphere') {
            dist = sphereIntersection(object, ray);
        } else {
            dist = planeIntersection(object, ray);
        }

        if (dist !== undefined &&
            dist > SELF_INTERSECTION_THRESHOLD &&
            dist < closest[0]) {
            closest = [dist, object];
        }
    }

    return closest;
}

function sphereIntersection(sphere, ray) {
    var eye_to_center = Vector.subtract(sphere.point, ray.point),
        v = Vector.dotProduct(eye_to_center, ray.vector),
        eoDot = Vector.dotProduct(eye_to_center, eye_to_center),
        discriminant = (sphere.radius * sphere.radius) - eoDot + (v * v);
    if (discriminant < 0) {
        return;
    } else {
        const dist = v - Math.sqrt(discriminant);
        return dist > SELF_INTERSECTION_THRESHOLD ? dist : undefined;
    }
}

function planeIntersection(plane, ray) {
    const negNorm = Vector.negate(plane.normal);
    const denom = Vector.dotProduct(negNorm, ray.vector);

    if (denom <= 0) {
        return Infinity;
    }

    const interm = Vector.subtract(plane.point, ray.point);
    return Vector.dotProduct(interm, negNorm) / denom;
}

function surfaceNormal(object, pos) {

    if (object.type === 'Sphere') {
        return Vector.unitVector(Vector.subtract(pos, object.point));
    }

    return object.normal;
}

function planeColorAt(plane, point, scene) {

    // Point from plane origin
    // This is a complete hack to make up for my sad lack of lin alg. knowledge

    const fromOrigin = Vector.subtract(point, plane.point);
    const width = 2;

    var px = { x: 0, y: 1, z: 0 };
    var py = { x: 0, y: 0, z: 1 };

    if (plane.normal.z !== 0) {
        var px = { x: 0, y: 1, z: 0 };
        var py = { x: 1, y: 0, z: 0 };
    }

    if (plane.normal.y !== 0) {
        var px = { x: 0, y: 0, z: 1 };
        var py = { x: 1, y: 0, z: 0 };
    }

    const cx = Vector.dotProduct(px, fromOrigin);
    const cy = Vector.dotProduct(py, fromOrigin);

    const x_cond = (cx < 0 && cx % width < -width/2) || (cx > 0 && cx % width < width/2);
    const y_cond = (cy < 0 && cy % width < -width/2) || (cy > 0 && cy % width < width/2);

    if ((x_cond && !y_cond) || (y_cond && !x_cond)) {
        return scene.checker[0];
    }

    return scene.checker[1];
}

function surface(ray, scene, object, pointAtTime, normal, depth) {

    var b = object.color,
        c = Vector.ZERO,
        lambertAmount = 0;

    if (object.type === 'Plane') {
        b = planeColorAt(object, pointAtTime, scene);
    }

    if (object.lambert) {
        for (var i = 0; i < scene.lights.length; i++) {
            const light = scene.lights[i];
            if (!isLightVisible(pointAtTime, scene, light)) {
                continue;
            }
            var contribution = Vector.dotProduct(Vector.unitVector(
                Vector.subtract(light, pointAtTime)), normal);
            if (contribution > 0) lambertAmount += contribution;
        }
    }

    if (object.specular) {
        var reflectedRay = {
            point: pointAtTime,
            vector: Vector.reflectThrough(ray.vector, normal)
        };
        var reflectedColor = trace(reflectedRay, scene, ++depth);
        if (reflectedColor) {
            c = Vector.add(c, Vector.scale(reflectedColor, object.specular));
        }
    }

    lambertAmount = Math.min(1, lambertAmount);

    return Vector.add3(c,
        Vector.scale(b, lambertAmount * object.lambert),
        Vector.scale(b, object.ambient));
}

function isLightVisible(pt, scene, light) {

    const pointToLightVector = Vector.subtract(light, pt);

    const ray = {
        point: pt,
        vector: Vector.unitVector(pointToLightVector)
    };

    const distanceToLight = Vector.length(pointToLightVector);

    const [dist] = intersectScene(ray, scene);

    return dist > distanceToLight;
}

export function render(canvas, scene) {

    const { width, height } = canvas;

    var camera = scene.camera;

    var eyeVector = Vector.unitVector(Vector.subtract(camera.vector, camera.point)),

        vpRight = Vector.unitVector(Vector.crossProduct(eyeVector, Vector.UP)),
        vpUp = Vector.unitVector(Vector.crossProduct(vpRight, eyeVector)),

        fovRadians = Math.PI * (camera.fov / 2) / 180,
        heightWidthRatio = height / width,
        halfWidth = Math.tan(fovRadians),
        halfHeight = heightWidthRatio * halfWidth,
        camerawidth = halfWidth * 2,
        cameraheight = halfHeight * 2,
        pixelWidth = camerawidth / (width - 1),
        pixelHeight = cameraheight / (height - 1);

    var color;
    var ray = {
        point: camera.point
    };

    const dataArray = [];

    for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
            var xcomp = Vector.scale(vpRight, (x * pixelWidth) - halfWidth),
                ycomp = Vector.scale(vpUp, (y * pixelHeight) - halfHeight);

            ray.vector = Vector.unitVector(Vector.add3(eyeVector, xcomp, ycomp));

            color = trace(ray, scene, 0);

            dataArray.push(color.x, color.y, color.z, 255);
        }
    }

    return dataArray;
}