// The frames of the animation page against the official rough.js in Node.
//
//   node examples/web/build.mjs && node examples/web/animation_test.mjs
//
// Jittering strokes: the picture is drawn again with seed + frame. Every
// frame of both the ops (`generate`) and the canvas calls (`draw`) must be
// those of rough.js.
//
// Draw-on: the first k ops of the picture's shapes, for every k from 0 to
// the number of ops. `draw_prefix` must make the canvas calls that
// RoughCanvas.draw makes for the same cut of the drawable rough.js generated.
//
// Same reference as test.mjs: Node 24 / x64, or ALLOW_INEXACT=1.

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { compareSets } from './compare.mjs';
import { recordingCanvas, sameEvents, tolerant } from './recording.mjs';
import { sceneSpecs } from './scene.mjs';
import { drawOfficial, drawOfficialPrefix, generateOfficial } from './spec.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const rough = require(path.join(here, '..', '..', 'scripts', 'node_modules', 'roughjs'));
const moon = await import(pathToFileURL(path.join(here, 'moon_rough_demo.js')).href);

const FRAMES = 60;
const ROUGHNESS = [0.5, 1, 2.5];

let failures = 0;
let frames = 0;
let values = 0;
let calls = 0;
let maxAbs = 0;
const report = (what, message) => {
  failures++;
  if (failures <= 10) console.error(`FAIL ${what}: ${message}`);
};

// 1. Jittering strokes.
for (const roughness of ROUGHNESS) {
  for (let frame = 0; frame < FRAMES; frame++) {
    for (const spec of sceneSpecs({ roughness, seed: 1 + frame })) {
      const what = `${spec.shape} roughness ${roughness} seed ${spec.options.seed}`;
      const json = JSON.stringify(spec);
      const official = recordingCanvas();
      const drawable = drawOfficial(rough, official.canvas, spec);
      const mine = JSON.parse(moon.generate(json));
      const result = compareSets(mine.sets, drawable.sets);
      values += result.values;
      maxAbs = Math.max(maxAbs, result.maxAbs);
      if (!result.sameStructure) report(what, result.problem);
      else if (result.differing > 0 && !(tolerant && result.maxAbs <= 1e-9)) {
        report(what, `${result.differing} of ${result.values} numbers differ, by up to ${result.maxAbs}`);
      }
      const own = recordingCanvas();
      const message = moon.draw(own.ctx, json);
      if (message !== '') report(what, `draw: ${message}`);
      calls += own.events.length;
      if (!sameEvents(own.events, official.events)) report(what, 'canvas calls differ');
    }
    frames++;
  }
}

// 2. Draw-on, every prefix.
let prefixes = 0;
for (const roughness of ROUGHNESS) {
  for (const spec of sceneSpecs({ roughness })) {
    const json = JSON.stringify(spec);
    const total = generateOfficial(rough, spec).sets.reduce((n, set) => n + set.ops.length, 0);
    // One past the end checks that a count beyond the last op draws everything.
    for (let count = 0; count <= total + 1; count++) {
      const what = `${spec.shape} roughness ${roughness}, first ${count} of ${total} ops`;
      const official = recordingCanvas();
      drawOfficialPrefix(rough, official.canvas, spec, count);
      const own = recordingCanvas();
      const message = moon.draw_prefix(own.ctx, json, count);
      if (message !== '') report(what, `draw_prefix: ${message}`);
      calls += own.events.length;
      prefixes++;
      if (!sameEvents(own.events, official.events)) report(what, `canvas calls differ (${own.events.length} against ${official.events.length})`);
    }
  }
}

// The pen writes the shape: more ops never means fewer calls, and nothing is
// drawn for zero ops.
{
  const spec = sceneSpecs()[0];
  const json = JSON.stringify(spec);
  const none = recordingCanvas();
  moon.draw_prefix(none.ctx, json, 0);
  if (none.events.length !== 0) report('prefix 0', `${none.events.length} calls for zero ops`);
  const negative = recordingCanvas();
  moon.draw_prefix(negative.ctx, json, -5);
  if (negative.events.length !== 0) report('prefix -5', `${negative.events.length} calls for a negative count`);
  const message = moon.draw_prefix(recordingCanvas().ctx, '{', 3);
  if (message === '') report('bad input', 'draw_prefix accepted it');
}

console.log(`${frames} frames of jittering strokes and ${prefixes} prefixes, ${values} numbers compared, `
  + `${calls} canvas calls, max error ${maxAbs}${tolerant ? ' (tolerant)' : ''}`);
if (failures > 0) {
  console.error(`${failures} failures`);
  process.exit(1);
}
console.log('moon_rough and rough.js agree on every frame');
