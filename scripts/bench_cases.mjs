// The inputs of the benchmarks, generated deterministically. src/perf/cases.mbt
// is the same generator in MoonBit: both use the Park-Miller sequence of
// rough.js' Random and the same arithmetic, in the same order, so they build
// exactly the same shapes and paths. A checksum of what the official rough.js
// generates from them (scripts/gen_fixtures.mjs) is checked in the MoonBit
// tests, which proves that the two sides are timed on the same work.

/** `() => number in [0, 1)`, the generator of rough.js' Random. */
export function makeRng(seed) {
  let state = seed | 0;
  return () => {
    state = Math.imul(48271, state);
    return (state & 0x7fffffff) / 2147483648;
  };
}

/** 0 .. 500 with two decimals: a coordinate. */
const coordinate = (next) => Math.floor(next() * 50000) / 100;
/** 10 .. 310 with two decimals: a width, height or diameter. */
const size = (next) => 10 + Math.floor(next() * 30000) / 100;

const FILL_STYLES = ['hachure', 'solid', 'zigzag', 'cross-hatch', 'dashed', 'zigzag-line'];

function randomPath(next) {
  const segments = 2 + Math.floor(next() * 4);
  let d = `M ${coordinate(next)} ${coordinate(next)}`;
  for (let i = 0; i < segments; i++) {
    switch (Math.floor(next() * 3)) {
      case 0: d += ` L ${coordinate(next)} ${coordinate(next)}`; break;
      case 1: d += ` C ${coordinate(next)} ${coordinate(next)} ${coordinate(next)} ${coordinate(next)} ${coordinate(next)} ${coordinate(next)}`; break;
      default: d += ` Q ${coordinate(next)} ${coordinate(next)} ${coordinate(next)} ${coordinate(next)}`; break;
    }
  }
  return `${d} Z`;
}

function randomPoints(next, minimum) {
  const count = minimum + Math.floor(next() * 6);
  const points = [];
  for (let i = 0; i < count; i++) {
    const x = coordinate(next);
    const y = coordinate(next);
    points.push([x, y]);
  }
  return points;
}

/**
 * One random shape: `{ shape, args, options }`, the arguments of the shape
 * method of rough.js. With `dots`, every shape gets the dots fill; otherwise
 * each one gets no fill or one of six fill styles.
 */
export function randomCase(next, dots) {
  const kind = Math.floor(next() * 9);
  let shape;
  let args;
  switch (kind) {
    case 0: {
      shape = 'line';
      const x1 = coordinate(next); const y1 = coordinate(next);
      const x2 = coordinate(next); const y2 = coordinate(next);
      args = [x1, y1, x2, y2];
      break;
    }
    case 1: case 2: {
      shape = kind === 1 ? 'rectangle' : 'ellipse';
      const x = coordinate(next); const y = coordinate(next);
      const w = size(next); const h = size(next);
      args = [x, y, w, h];
      break;
    }
    case 3: {
      shape = 'circle';
      const x = coordinate(next); const y = coordinate(next);
      args = [x, y, size(next)];
      break;
    }
    case 4: shape = 'linearPath'; args = randomPoints(next, 2); break;
    case 5: shape = 'polygon'; args = randomPoints(next, 3); break;
    case 6: {
      shape = 'arc';
      const x = coordinate(next); const y = coordinate(next);
      const w = size(next); const h = size(next);
      const start = next() * 2 * Math.PI;
      const stop = start + 0.3 + next() * 5;
      const closed = next() < 0.6 ? 1 : 0;
      args = [x, y, w, h, start, stop, closed];
      break;
    }
    case 7: shape = 'curve'; args = randomPoints(next, 3); break;
    default: shape = 'path'; args = randomPath(next); break;
  }
  const options = {
    seed: 1 + Math.floor(next() * 1000000),
    roughness: Math.floor(next() * 300) / 100,
    bowing: Math.floor(next() * 800) / 100,
    hachureAngle: Math.floor(next() * 3600) / 10 - 180,
    hachureGap: 4 + Math.floor(next() * 160) / 10,
    strokeWidth: 0.5 + Math.floor(next() * 40) / 10,
    stroke: '#1d3557',
  };
  if (dots) {
    options.fill = '#e76f51';
    options.fillStyle = 'dots';
  } else {
    const style = Math.floor(next() * 7);
    if (style > 0) {
      options.fill = '#e76f51';
      options.fillStyle = FILL_STYLES[style - 1];
    }
  }
  return { shape, args, options };
}

export function randomCases(count, seed, dots = false) {
  const next = makeRng(seed);
  return Array.from({ length: count }, () => randomCase(next, dots));
}

/** Calls the shape method of rough.js (a generator) for a case. */
export function generate(gen, c) {
  const { shape, args, options } = c;
  switch (shape) {
    case 'line': return gen.line(args[0], args[1], args[2], args[3], options);
    case 'rectangle': return gen.rectangle(args[0], args[1], args[2], args[3], options);
    case 'ellipse': return gen.ellipse(args[0], args[1], args[2], args[3], options);
    case 'circle': return gen.circle(args[0], args[1], args[2], options);
    case 'linearPath': return gen.linearPath(args, options);
    case 'polygon': return gen.polygon(args, options);
    case 'curve': return gen.curve(args, options);
    case 'arc': return gen.arc(args[0], args[1], args[2], args[3], args[4], args[5], args[6] === 1, options);
    case 'path': return gen.path(args, options);
    default: throw new Error(shape);
  }
}

/**
 * A complex SVG path of `segments` segments: absolute and relative lines,
 * horizontal and vertical lines, cubic and quadratic curves with their
 * smooth forms, elliptical arcs and several closed subpaths.
 */
export function complexPath(segments, seed) {
  const next = makeRng(seed);
  const absolute = () => 100 + Math.floor(next() * 30000) / 100;
  const relative = () => Math.floor(next() * 8000) / 100 - 40;
  const radius = () => 5 + Math.floor(next() * 3000) / 100;
  let d = `M ${absolute()} ${absolute()}`;
  for (let i = 0; i < segments; i++) {
    switch (Math.floor(next() * 12)) {
      case 0: d += ` l ${relative()} ${relative()}`; break;
      case 1: d += ` h ${relative()}`; break;
      case 2: d += ` v ${relative()}`; break;
      case 3: d += ` c ${relative()} ${relative()} ${relative()} ${relative()} ${relative()} ${relative()}`; break;
      case 4: d += ` s ${relative()} ${relative()} ${relative()} ${relative()}`; break;
      case 5: d += ` q ${relative()} ${relative()} ${relative()} ${relative()}`; break;
      case 6: d += ` t ${relative()} ${relative()}`; break;
      case 7: {
        const rx = radius(); const ry = radius();
        const rotation = Math.floor(next() * 90);
        const large = next() < 0.5 ? 1 : 0;
        const sweep = next() < 0.5 ? 1 : 0;
        d += ` a ${rx} ${ry} ${rotation} ${large} ${sweep} ${relative()} ${relative()}`;
        break;
      }
      case 8: d += ` L ${absolute()} ${absolute()}`; break;
      case 9: d += ` C ${absolute()} ${absolute()} ${absolute()} ${absolute()} ${absolute()} ${absolute()}`; break;
      case 10: d += ` Q ${absolute()} ${absolute()} ${absolute()} ${absolute()}`; break;
      default: d += ` z m ${relative()} ${relative()}`; break;
    }
  }
  return `${d} z`;
}

/** The numbers of a drawable's op sets, summed in order, with the counts. */
export function checksum(drawables) {
  let sets = 0;
  let ops = 0;
  let sum = 0;
  for (const drawable of drawables) {
    for (const set of drawable.sets) {
      sets++;
      for (const op of set.ops) {
        ops++;
        for (const x of op.data) sum += x;
      }
    }
  }
  return { sets, ops, sum };
}

const escapeAttribute = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/**
 * The SVG string of a drawable, the way moon_rough's `drawable_to_svg` writes
 * it (rough.js' RoughSVG builds DOM nodes instead, which Node does not have):
 * one <path> per op set inside a <g>. `digits` is fixedDecimalPlaceDigits.
 */
export function drawableToSvg(gen, drawable, digits) {
  const o = drawable.options;
  let out = '<g>';
  for (const set of drawable.sets) {
    const d = gen.opsToPath(set, digits);
    let attrs;
    if (set.type === 'path') {
      attrs = [['d', d], ['stroke', o.stroke], ['stroke-width', String(o.strokeWidth)], ['fill', 'none']];
    } else if (set.type === 'fillPath') {
      attrs = [['d', d], ['stroke', 'none'], ['stroke-width', '0'], ['fill', o.fill || '']];
      if (drawable.shape === 'curve' || drawable.shape === 'polygon') attrs.push(['fill-rule', 'evenodd']);
    } else {
      const weight = o.fillWeight < 0 ? o.strokeWidth / 2 : o.fillWeight;
      attrs = [['d', d], ['stroke', o.fill || ''], ['stroke-width', String(weight)], ['fill', 'none']];
    }
    out += '<path';
    for (const [name, value] of attrs) out += ` ${name}="${escapeAttribute(value)}"`;
    out += '/>';
  }
  return `${out}</g>`;
}
