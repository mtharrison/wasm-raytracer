import * as Wasm from './wasm'
import * as JavaScript from './javascript'
import Fps from './fps'

const canvas = {
    width: 480,
    height: 360
};

const getScene = () => {

    const input = (selector) => {
        return parseFloat(document.getElementById(selector).value);
    };

    return {
        camera: {
            point: {
                x: input('camera-x'),
                y: input('camera-y'),
                z: input('camera-z'),
            },
            vector: {
                x: 0,
                y: 0,
                z: 0
            },
            fov: input('camera-fov')
        },
        objects: [
            {
                type: 'Sphere',
                point: { x: -3, y: 0, z: 0 },
                color: { x: input('obj-1-red'), y: input('obj-1-green'), z: input('obj-1-blue') },
                specular: input('obj-1-specular') / 100,
                lambert: input('obj-1-lambert') / 100,
                ambient: input('obj-1-ambient') / 100,
                radius: input('obj-1-radius') / 100
            },
            {
                type: 'Sphere',
                point: { x: 3, y: 0, z: 0 },
                color: { x: input('obj-2-red'), y: input('obj-2-green'), z: input('obj-2-blue') },
                specular: input('obj-2-specular') / 100,
                lambert: input('obj-2-lambert') / 100,
                ambient: input('obj-2-ambient') / 100,
                radius: input('obj-2-radius') / 100
            },
            {
                type: 'Sphere',
                point: { x: 0, y: 0, z: 0 },
                color: { x: input('obj-3-red'), y: input('obj-3-green'), z: input('obj-3-blue') },
                specular: input('obj-3-specular') / 100,
                lambert: input('obj-3-lambert') / 100,
                ambient: input('obj-3-ambient') / 100,
                radius: input('obj-3-radius') / 100
            },
            {
                type: 'Plane',
                point: { x: 0, y: 5, z: 0 },
                normal: { x: 0, y: -1, z: 0 },
                color: { x: 200, y: 200, z: 200 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
            {
                type: 'Plane',
                point: { x: 0, y: -5, z: 0 },
                normal: { x: 0, y: 1, z: 0 },
                color: { x: 100, y: 100, z: 100 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
            {
                type: 'Plane',
                point: { x: -5, y: 0, z: 0 },
                normal: { x: 1, y: 0, z: 0 },
                color: { x: 100, y: 100, z: 100 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
            {
                type: 'Plane',
                point: { x: 5, y: 0, z: 0 },
                normal: { x: -1, y: 0, z: 0 },
                color: { x: 100, y: 100, z: 100 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
            {
                type: 'Plane',
                point: { x: 0, y: 0, z: -12 },
                normal: { x: 0, y: 0, z: 1 },
                color: { x: 100, y: 100, z: 100 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
            {
                type: 'Plane',
                point: { x: 0, y: 0, z: 12 },
                normal: { x: 0, y: 0, z: -1 },
                color: { x: 100, y: 100, z: 100 },
                specular: 0.0,
                lambert: 0.9,
                ambient: 0.2,
            },
        ],
        checker: [
            {
                x: input('checker-color-1-red'),
                y: input('checker-color-1-green'),
                z: input('checker-color-1-blue')
            },
            {
                x: input('checker-color-2-red'),
                y: input('checker-color-2-green'),
                z: input('checker-color-2-blue')
            }
        ],
        lights: [{
            x: input('light-1-x'),
            y: input('light-1-y'),
            z: input('light-1-z')
        }]
    };
};

const putData = (data) => {
    const ctx = document.getElementById('canvas').getContext('2d');
    ctx.putImageData(new ImageData(new Uint8ClampedArray(data), canvas.width, canvas.height), 0, 0);
};

const renderWasm = (scene) => {

    const data = Wasm.render(canvas, scene);
    if (data) {         // may return undefined if wasm module not loaded
        putData(data);
    }
};

const renderJs = (scene) => {

    const data = JavaScript.render(canvas, scene);
    putData(data);
};

let inc = 0;

const fps = new Fps(250,  document.querySelector('.fps'));
let wasm = true;

const render = () => {

    fps.tick();

    const scene = getScene();

    scene.objects[0].point.x = Math.sin(inc) * 3.0;
    scene.objects[0].point.z = Math.cos(inc) * 3.0;
    scene.objects[0].point.y = Math.sin(inc) * 2.0;

    scene.objects[1].point.x = Math.sin(inc) * -3.0;
    scene.objects[1].point.z = Math.cos(inc) * -3.0;
    scene.objects[1].point.y = Math.cos(inc) * -2.0;

    inc += parseFloat(document.getElementById('orbit-speed').value / 250);

    if (wasm) {
        renderWasm(scene);
    } else {
        renderJs(scene);
    }

    requestAnimationFrame(render);
};

requestAnimationFrame(render);

document.querySelectorAll('.switch-container a')
    .forEach((e) => e.addEventListener('click', (e) => {

    const node = e.target;
    if (node.innerText === 'WebAssembly') {
        wasm = true;
        document.querySelectorAll('.switch-container a')[0].classList = 'selected';
        document.querySelectorAll('.switch-container a')[1].classList = '';
    } else {
        wasm = false;
        document.querySelectorAll('.switch-container a')[1].classList = 'selected';
        document.querySelectorAll('.switch-container a')[0].classList = '';
    }

    e.preventDefault();
}));