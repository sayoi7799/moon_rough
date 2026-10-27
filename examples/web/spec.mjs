// The description of a shape that both sides draw: moon_rough (through the
// exported `draw` and `generate`) and the official rough.js.
//
//   { shape: "rectangle", args: [x, y, w, h], options: { seed: 42, ... } }

/** Default arguments of every shape, for a 420 x 320 canvas. */
export const SHAPES = {
  line: [30, 40, 390, 280],
  rectangle: [40, 40, 340, 240],
  ellipse: [210, 160, 340, 230],
  circle: [210, 160, 240],
  polygon: [[210, 24], [392, 120], [330, 292], [90, 292], [28, 120]],
  arc: [210, 160, 340, 250, -0.6, 4.1, 1],
  curve: [[30, 270], [100, 50], [200, 240], [300, 40], [392, 210]],
  linearPath: [[30, 260], [100, 60], [170, 250], [240, 60], [310, 250], [390, 60]],
  path: 'M 40 280 C 40 40, 200 40, 210 160 S 380 290, 380 70 L 300 30 Z',
};

export const FILL_STYLES = ['hachure', 'solid', 'zigzag', 'cross-hatch', 'dots', 'dashed', 'zigzag-line'];

export function makeSpec(shape, options) {
  return { shape, args: SHAPES[shape], options };
}

/**
 * Runs `fn` with `Math.random` replaced by the Park-Miller sequence that
 * moon_rough's demo uses for the same purpose.
 *
 * rough.js takes the dot positions of the `dots` fill (and one decision of
 * the hachure filler) from `Math.random()`, which has no seed, so two runs
 * can only be compared if both draw from the same fixed sequence.
 */
export function withFixedRandom(fn, seed = 1) {
  const original = Math.random;
  let state = seed;
  Math.random = () => {
    state = Math.imul(48271, state);
    return (state & 0x7fffffff) / 2 ** 31;
  };
  try {
    return fn();
  } finally {
    Math.random = original;
  }
}

/**
 * Draws `spec` with the official rough.js on `canvas` and returns the
 * drawable it generated. `roughLib` is the `rough` object of rough.js.
 */
export function drawOfficial(roughLib, canvas, spec) {
  const rc = roughLib.canvas(canvas);
  const { shape, args, options } = spec;
  return withFixedRandom(() => drawShape(rc, shape, args, options));
}

/**
 * The drawable the official generator makes for `spec`, without drawing it.
 * `roughLib` is the `rough` object of rough.js.
 */
export function generateOfficial(roughLib, spec) {
  const { shape, args, options } = spec;
  return withFixedRandom(() => drawShape(roughLib.generator(), shape, args, options));
}

/**
 * The first `count` ops of `sets` (rough.js' `drawable.sets`), counting
 * through the sets in order: later sets are dropped and the set in which
 * the count runs out is cut. The same rule as `draw_prefix` in
 * src/examples/web_demo.
 */
export function prefixSets(sets, count) {
  const result = [];
  let left = count;
  for (const set of sets) {
    if (left <= 0) break;
    const ops = set.ops.slice(0, left);
    left -= ops.length;
    result.push({ ...set, ops });
  }
  return result;
}

/**
 * Draws the first `count` ops of what rough.js generates for `spec` on
 * `canvas` and returns the full drawable. The generator and the drawing
 * methods of rough.js take the same arguments, so one function serves both.
 */
export function drawOfficialPrefix(roughLib, canvas, spec, count) {
  const drawable = generateOfficial(roughLib, spec);
  roughLib.canvas(canvas).draw({ ...drawable, sets: prefixSets(drawable.sets, count) });
  return drawable;
}

function drawShape(rc, shape, args, options) {
  switch (shape) {
    case 'line': return rc.line(...args, options);
    case 'rectangle': return rc.rectangle(...args, options);
    case 'ellipse': return rc.ellipse(...args, options);
    case 'circle': return rc.circle(...args, options);
    case 'polygon': return rc.polygon(args, options);
    case 'linearPath': return rc.linearPath(args, options);
    case 'curve': return rc.curve(args, options);
    case 'arc': return rc.arc(args[0], args[1], args[2], args[3], args[4], args[5], !!args[6], options);
    case 'path': return rc.path(args, options);
    default: throw new Error(`unknown shape ${shape}`);
  }
}
