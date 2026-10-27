// The Node side of the benchmarks: the same work as src/perf/perf_bench_test.mbt
// with the official rough.js 4.6.6, path-data-parser and points-on-path from
// package-lock.json, timed the way `moon bench` times: after a warm-up, the
// batch size is raised until a batch takes at least 100 ms, then 10 batches
// are timed and their mean, standard deviation and range are reported.
//
//   node scripts/bench_roughjs.mjs           prints JSON: { name: { mean, sd, min, max, batch } } in ns
//
// The names are the keys of the tests in perf_bench_test.mbt.

import os from 'node:os';
import { createRequire } from 'node:module';

import { complexPath, drawableToSvg, generate, randomCases } from './bench_cases.mjs';

const require = createRequire(import.meta.url);
const rough = require('roughjs');
const { absolutize, normalize, parsePath } = await import('path-data-parser');
const { pointsOnPath } = await import('points-on-path');

// The sizes and seeds of src/perf/cases.mbt.
const SHAPES = 10000;
const SHAPE_SEED = 1;
const DOTS = 500;
const DOTS_SEED = 2;
const SEGMENTS = 300;
const PATH_SEED = 11;

let sink; // keeps the results alive, like `it.keep` does in MoonBit

const now = () => Number(process.hrtime.bigint());

function bench(fn) {
  for (let i = 0; i < 3; i++) sink = fn(); // warm-up
  let batch = 1;
  for (;;) {
    const start = now();
    for (let i = 0; i < batch; i++) sink = fn();
    if (now() - start >= 1e8) break;
    batch *= 2;
  }
  const times = [];
  for (let b = 0; b < 10; b++) {
    const start = now();
    for (let i = 0; i < batch; i++) sink = fn();
    times.push((now() - start) / batch);
  }
  const mean = times.reduce((a, b) => a + b, 0) / times.length;
  const sd = Math.sqrt(times.reduce((a, b) => a + (b - mean) ** 2, 0) / (times.length - 1));
  return { mean, sd, min: Math.min(...times), max: Math.max(...times), batch };
}

const gen = rough.generator();
const path = complexPath(SEGMENTS, PATH_SEED);
const results = {};

const shapes = randomCases(SHAPES, SHAPE_SEED);
results.random_shapes_10k = bench(() => {
  let last;
  for (const c of shapes) last = generate(gen, c);
  return last;
});

const dots = randomCases(DOTS, DOTS_SEED, true);
results.dots_500 = bench(() => {
  let last;
  for (const c of dots) last = generate(gen, c);
  return last;
});

results.path_parse = bench(() => normalize(absolutize(parsePath(path))));
results.path_points_on_path = bench(() => pointsOnPath(path, 1, 1));

for (const [name, fillStyle] of [['hachure', 'hachure'], ['solid', 'solid'], ['cross_hatch', 'cross-hatch']]) {
  const options = { seed: 1, fill: '#e76f51', fillStyle, hachureGap: 8 };
  results[`path_fill_${name}`] = bench(() => gen.path(path, options));
}

// The SVG output: the drawables are made before the timer starts.
for (const digits of [undefined, 2]) {
  const cases = randomCases(SHAPES, SHAPE_SEED).map((c) => (
    digits === undefined ? c : { ...c, options: { ...c.options, fixedDecimalPlaceDigits: digits } }));
  const drawables = cases.map((c) => generate(gen, c));
  results[digits === undefined ? 'svg_output_10k' : 'svg_output_10k_fixed2'] = bench(() => {
    let last;
    for (const d of drawables) last = drawableToSvg(gen, d, digits);
    return last;
  });
}

console.log(JSON.stringify({
  environment: { node: process.version, cpu: os.cpus()[0].model, threads: os.cpus().length, platform: `${os.platform()} ${os.arch()}` },
  results,
}));
