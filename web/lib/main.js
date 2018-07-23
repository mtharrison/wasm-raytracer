import * as Wasm from './wasm'
import * as JavaScript from './javascript'
import Fps from './fps'

const canvas = {
    width: 640,
    height: 480
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
                point: { x: -3, y: 0, z: 0 },
                color: { x: input('obj-1-red'), y: input('obj-1-blue'), z: input('obj-1-green') },
                specular: input('obj-1-specular') / 100,
                lambert: input('obj-1-lambert') / 100,
                ambient: input('obj-1-ambient') / 100,
                radius: input('obj-1-radius') / 100
            },
            {
                point: { x: 3, y: 0, z: 0 },
                color: { x: input('obj-2-red'), y: input('obj-2-blue'), z: input('obj-2-green') },
                specular: input('obj-2-specular') / 100,
                lambert: input('obj-2-lambert') / 100,
                ambient: input('obj-2-ambient') / 100,
                radius: input('obj-2-radius') / 100
            },
            {
                point: { x: 0, y: 0, z: 0 },
                color: { x: input('obj-3-red'), y: input('obj-3-blue'), z: input('obj-3-green') },
                specular: input('obj-3-specular') / 100,
                lambert: input('obj-3-lambert') / 100,
                ambient: input('obj-3-ambient') / 100,
                radius: input('obj-3-radius') / 100
            }
        ],
        lights: [{
            x: input('light-1-x'),
            y: input('light-1-y'),
            z: input('light-1-z')
        },
        {
            x: input('light-2-x'),
            y: input('light-2-y'),
            z: input('light-2-z')
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

const render = () => {

    fps.tick();

    const scene = getScene();

    scene.objects[0].point.x = Math.sin(inc) * 3.0;
    scene.objects[0].point.z = Math.cos(inc) * 3.0;

    scene.objects[1].point.x = Math.sin(inc) * -3.0;
    scene.objects[1].point.z = Math.cos(inc) * -3.0;

    inc += parseFloat(document.getElementById('orbit-speed').value / 250);

    if (document.querySelector('.switch-wasm input').checked) {
        renderJs(scene);
    } else {
        renderWasm(scene);
    }

    requestAnimationFrame(render);
};

requestAnimationFrame(render);