// Runs the demo's two entry points against the official rough.js in Node,
// without a browser: for many shape descriptions, `generate` must give the
// same ops and `draw` the same canvas calls.
//
//   node examples/web/build.mjs && node examples/web/test.mjs
//
// The results are bit-identical to rough.js on Node 24 / x64, the reference
// of the fixtures. On a machine whose Math.sin / cos / tan differ in the last
// bit (e.g. arm64), set ALLOW_INEXACT=1 to accept differences below 1e-9.

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { compareSets } from './compare.mjs';
import { FILL_STYLES, SHAPES, drawOfficial, makeSpec } from './spec.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const rough = require(path.join(here, '..', '..', 'scripts', 'node_modules', 'roughjs'));
const moon = await import(pathToFileURL(path.join(here, 'moon_rough_demo.js')).href);

const tolerant = process.env.ALLOW_INEXACT === '1';

/** A canvas whose context writes down every call and assignment. */
function recordingCanvas() {
  const events = [];
  const methods = new Set(['save', 'restore', 'beginPath', 'moveTo', 'lineTo',
    'bezierCurveTo', 'stroke', 'fill', 'setLineDash']);
  const ctx = new Proxy({}, {
    get(_, key) {
      if (!methods.has(key)) throw new Error(`read of ctx.${String(key)}`);
      return (...args) => events.push([key, ...args]);
    },
    set(_, key, value) {
      events.push(['set', key, value]);
      return true;
    },
  });
  return { events, canvas: { getContext: () => ctx }, ctx };
}

function sameValue(a, b) {
  if (typeof a === 'number' && typeof b === 'number') {
    return tolerant ? Math.abs(a - b) <= 1e-9 : Object.is(a, b);
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((x, i) => sameValue(x, b[i]));
  }
  return a === b;
}

function sameEvents(a, b) {
  return a.length === b.length && a.every((e, i) => sameValue(e, b[i]));
}

// Descriptions to try: every shape, every fill style, several settings.
const specs = [];
for (const shape of Object.keys(SHAPES)) {
  for (const fillStyle of [null, ...FILL_STYLES]) {
    for (const [roughness, bowing, hachureAngle, hachureGap] of [
      [1, 1, -41, 8], [0, 1, 30, 6], [2.5, 4, 90, 12], [0.5, 0, 0, 5],
    ]) {
      const options = { seed: 1 + specs.length, roughness, bowing, strokeWidth: 2, stroke: '#1d3557' };
      if (fillStyle) Object.assign(options, { fill: '#e76f51', fillStyle, hachureAngle, hachureGap });
      specs.push(makeSpec(shape, options));
    }
  }
}
let seed = 123456;
const next = () => {
  seed = Math.imul(48271, seed);
  return (seed & 0x7fffffff) / 2 ** 31;
};
const shapes = Object.keys(SHAPES);
for (let i = 0; i < 300; i++) {
  const shape = shapes[Math.floor(next() * shapes.length)];
  const options = {
    seed: 1 + Math.floor(next() * 100000),
    roughness: Math.round(next() * 40) / 10,
    bowing: Math.round(next() * 80) / 10,
    strokeWidth: 0.5 + Math.round(next() * 50) / 10,
    stroke: '#222',
    hachureGap: 4 + Math.round(next() * 120) / 10,
    hachureAngle: Math.round((next() - 0.5) * 3600) / 10,
  };
  if (next() < 0.8) {
    options.fill = '#2a9d8f';
    options.fillStyle = FILL_STYLES[Math.floor(next() * FILL_STYLES.length)];
  }
  specs.push(makeSpec(shape, options));
}

let failures = 0;
let totalValues = 0;
let totalCalls = 0;
let maxAbs = 0;
const report = (spec, message) => {
  failures++;
  if (failures <= 10) console.error(`FAIL ${spec.shape} ${JSON.stringify(spec.options)}: ${message}`);
};

for (const spec of specs) {
  const json = JSON.stringify(spec);

  // 1. generate() against the generator of rough.js.
  const official = recordingCanvas();
  const drawable = drawOfficial(rough, official.canvas, spec);
  const mine = JSON.parse(moon.generate(json));
  if (mine.error) {
    report(spec, `generate: ${mine.error}`);
    continue;
  }
  const result = compareSets(mine.sets, drawable.sets);
  totalValues += result.values;
  maxAbs = Math.max(maxAbs, result.maxAbs);
  if (!result.sameStructure) report(spec, result.problem);
  else if (result.differing > 0 && !(tolerant && result.maxAbs <= 1e-9)) {
    report(spec, `${result.differing} of ${result.values} numbers differ, by up to ${result.maxAbs}`);
  }

  // 2. draw() against the canvas calls of rough.js.
  const own = recordingCanvas();
  const message = moon.draw(own.ctx, json);
  if (message !== '') {
    report(spec, `draw: ${message}`);
    continue;
  }
  totalCalls += own.events.length;
  if (!sameEvents(own.events, official.events)) {
    report(spec, `canvas calls differ (${own.events.length} against ${official.events.length})`);
  }
}

// Bad input is reported, not thrown.
for (const bad of ['', '{', '[]', '{"shape":"star"}', '{"shape":"rectangle","args":[1,2]}',
  '{"shape":"path","args":"M 1 1 L"}', '{"shape":"polygon","args":[[1]]}']) {
  const message = moon.draw(recordingCanvas().ctx, bad);
  if (message === '') report({ shape: 'bad input', options: bad }, 'draw accepted it');
  if (!JSON.parse(moon.generate(bad)).error) report({ shape: 'bad input', options: bad }, 'generate accepted it');
}

console.log(`${specs.length} descriptions, ${totalValues} numbers compared, ${totalCalls} canvas calls, `
  + `max error ${maxAbs}${tolerant ? ' (tolerant)' : ''}`);
if (failures > 0) {
  console.error(`${failures} failures`);
  process.exit(1);
}
console.log('moon_rough and rough.js agree on all of them');
