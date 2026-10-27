// The picture of the animation page and of its test: a few shapes on a
// 420 x 320 canvas, as descriptions in the format of spec.mjs.

/**
 * The shapes of the picture, with `roughness` and `seed + index` as their
 * options. Every shape has its own seed, so that each one looks different.
 */
export function sceneSpecs({ roughness = 1, seed = 1 } = {}) {
  const common = { roughness, strokeWidth: 2, stroke: '#1d3557' };
  const shapes = [
    ['rectangle', [28, 28, 170, 110], { fill: '#e76f51', fillStyle: 'hachure', hachureGap: 7, hachureAngle: -41 }],
    ['ellipse', [318, 84, 160, 104], { fill: '#2a9d8f', fillStyle: 'cross-hatch', hachureGap: 9, hachureAngle: 60 }],
    ['linearPath', [[60, 200], [236, 200]], {}],
    ['polygon', [[236, 186], [262, 200], [236, 214]], { fill: '#1d3557', fillStyle: 'solid' }],
    ['circle', [120, 262, 90], { fill: '#e9c46a', fillStyle: 'zigzag', hachureGap: 8 }],
    ['path', 'M 262 250 C 292 210, 350 210, 384 246 S 340 304, 262 280 Z', { fill: '#a8dadc', fillStyle: 'dashed', hachureGap: 9 }],
  ];
  return shapes.map(([shape, args, options], index) => ({
    shape,
    args,
    options: { ...common, ...options, seed: seed + index },
  }));
}
