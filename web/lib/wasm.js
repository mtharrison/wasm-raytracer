let rayLoaded = false;
let _render;

import('ray').then((Ray) => {

    rayLoaded = true;

    _render = function (canvas, scene) {
        const { width, height } = canvas;
        return Ray.binding(JSON.stringify(scene), width, height);
    };
});

export function render(canvas, scene) {
    if (rayLoaded) {
        return _render(canvas, scene);
    }
}