// The animation page: draws the picture of scene.mjs frame after frame with
// moon_rough, and with the official rough.js next to it, and counts the
// frames on which the two agree.
//
//   jitter   every frame draws the picture again with seed + frame
//   drawon   every frame draws the first k ops of the picture's shapes, one
//            shape after the other, with k growing until the picture is done

import { comparePixels, compareSets } from './compare.mjs';
import { sceneSpecs } from './scene.mjs';
import { drawOfficial, drawOfficialPrefix } from './spec.mjs';

const WIDTH = 420;
const HEIGHT = 320;
const DRAW_FRAMES = 90; // frames in which the picture is written
const HOLD_FRAMES = 20; // frames in which the finished picture stays
const DEFAULT_FPS = { jitter: 8, drawon: 30 };
const $ = (id) => document.getElementById(id);

let moon = null;
try {
  moon = await import('./moon_rough_demo.js');
} catch (error) {
  $('verdict').className = 'badge bad';
  $('verdict').textContent = '无法运行';
  $('verdictText').textContent = '找不到 moon_rough_demo.js。请先在仓库根目录运行 node examples/web/build.mjs，再用 node examples/web/serve.mjs 打开本页。';
  console.error(error);
}

/** Sizes a canvas for the screen's pixel ratio and clears it. */
function prepare(canvas) {
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.round(WIDTH * ratio);
  canvas.height = Math.round(HEIGHT * ratio);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.clearRect(0, 0, WIDTH, HEIGHT);
  return ctx;
}

const number = (x) => x.toLocaleString('en-US');

// What has been compared since the animation (re)started.
let stats;
function resetStats() {
  stats = { frames: 0, opFrames: 0, pixelFrames: 0, values: 0, differing: 0, maxAbs: 0, structure: 0 };
}

// The ops moon_rough generates for a description do not change from frame to
// frame in draw-on (the seeds stay), so they are asked for once.
const generated = new Map();
function generatedFor(spec) {
  const json = JSON.stringify(spec);
  if (!generated.has(json)) {
    const sets = JSON.parse(moon.generate(json)).sets;
    generated.set(json, { json, sets, ops: sets.reduce((n, set) => n + set.ops.length, 0) });
  }
  return generated.get(json);
}

/** Draws frame number `frame`; returns the specs drawn and, if comparing, what was drawn by rough.js. */
function drawFrame(frame, comparing) {
  const mode = $('mode').value;
  const roughness = Number($('roughness').value);
  const mineCtx = prepare($('mine'));
  if (comparing) prepare($('official'));

  const officialSets = [];
  const mineSets = [];
  if (mode === 'jitter') {
    for (const spec of sceneSpecs({ roughness, seed: 1 + frame })) {
      const json = JSON.stringify(spec);
      moon.draw(mineCtx, json);
      if (comparing) {
        mineSets.push(JSON.parse(moon.generate(json)).sets);
        officialSets.push(drawOfficial(window.rough, $('official'), spec).sets);
      }
    }
  } else {
    const specs = sceneSpecs({ roughness, seed: 1 });
    const shapes = specs.map(generatedFor);
    const total = shapes.reduce((n, shape) => n + shape.ops, 0);
    const position = frame % (DRAW_FRAMES + HOLD_FRAMES);
    let left = Math.round(Math.min(1, position / DRAW_FRAMES) * total);
    specs.forEach((spec, i) => {
      const count = Math.min(left, shapes[i].ops);
      left -= count;
      moon.draw_prefix(mineCtx, shapes[i].json, count);
      if (comparing) {
        mineSets.push(shapes[i].sets);
        officialSets.push(drawOfficialPrefix(window.rough, $('official'), spec, count).sets);
      }
    });
  }
  return { mineSets, officialSets };
}

function compareFrame({ mineSets, officialSets }) {
  let sameStructure = true;
  let differing = 0;
  for (let i = 0; i < mineSets.length; i++) {
    const result = compareSets(mineSets[i], officialSets[i]);
    sameStructure &&= result.sameStructure;
    stats.values += result.values;
    differing += result.differing;
    stats.maxAbs = Math.max(stats.maxAbs, result.maxAbs);
  }
  stats.differing += differing;
  if (!sameStructure) stats.structure++;
  if (!sameStructure || differing > 0) stats.opFrames++;

  const pixels = comparePixels(
    $('mine').getContext('2d').getImageData(0, 0, $('mine').width, $('mine').height),
    $('official').getContext('2d').getImageData(0, 0, $('official').width, $('official').height),
  );
  if (pixels.differing > 0) stats.pixelFrames++;
}

// tan(1e22) is one of the values whose last bit differs between math
// libraries: the one fdlibm (and moon_rough) gives is -1.628778225606899.
const hostTan = Math.tan(1e22);
const hostMathMatches = hostTan === -1.628778225606899;

function setRows(rows) {
  const list = $('checks');
  list.replaceChildren();
  for (const [name, kind, text] of rows) {
    const li = document.createElement('li');
    const n = document.createElement('span');
    n.className = 'name';
    n.textContent = name;
    const m = document.createElement('span');
    m.className = `mark ${kind}`;
    m.textContent = { ok: '✓', warn: '≈', bad: '✗' }[kind];
    const t = document.createElement('span');
    t.textContent = text;
    li.append(n, m, t);
    list.append(li);
  }
}

function setVerdict(kind, label, text) {
  $('verdict').className = `badge ${kind}`;
  $('verdict').textContent = label;
  $('verdictText').textContent = text;
}

function showStats(comparing) {
  $('notes').replaceChildren();
  if (!comparing) {
    setVerdict('warn', '未对比', '勾选「和官方 rough.js 对比」后，每一帧都会和官方的输出比较');
    setRows([]);
    return;
  }
  if (stats.frames === 0) return;
  const rows = [];
  if (stats.structure > 0) {
    rows.push(['操作序列', 'bad', `${number(stats.structure)} 帧的 move / lineTo / bcurveTo 序列和官方不同`]);
  } else {
    rows.push(['操作序列', 'ok', `${number(stats.frames)} 帧的操作序列类型和顺序都与官方相同`]);
  }
  if (stats.structure > 0) {
    rows.push(['坐标', 'bad', '结构不同，无法逐个比较']);
  } else if (stats.differing === 0) {
    rows.push(['坐标', 'ok', `${number(stats.values)} 个数值逐位相同`]);
  } else {
    rows.push(['坐标', 'warn', `${number(stats.values)} 个数值里有 ${number(stats.differing)} 个不同，最大误差 ${stats.maxAbs.toExponential(2)}`]);
  }
  rows.push(['像素', stats.pixelFrames === 0 ? 'ok' : 'warn',
    stats.pixelFrames === 0 ? `${number(stats.frames)} 帧的像素都完全相同` : `${number(stats.pixelFrames)} 帧里有像素不同（共 ${number(stats.frames)} 帧）`]);
  setRows(rows);

  if (stats.structure > 0) setVerdict('bad', '不一致', '有的帧两边画出的线条结构不同');
  else if (stats.opFrames === 0 && stats.pixelFrames === 0) setVerdict('ok', '完全一致', `已对比 ${number(stats.frames)} 帧，操作序列、坐标和像素都相同`);
  else setVerdict('warn', '有微小差异', '结构相同，数值有最后几位的差别');

  if (stats.differing > 0 || stats.pixelFrames > 0) {
    $('notes').append(Object.assign(document.createElement('li'), {
      textContent: hostMathMatches
        ? '官方 rough.js 用的是浏览器自己的 Math.sin / cos / tan，moon_rough 用 fdlibm，两者的最后一位在个别输入上可能不同。'
        : `你的浏览器里 Math.tan(1e22) = ${hostTan}，和 fdlibm 的 -1.628778225606899 不同，官方 rough.js 用的是浏览器的实现，所以这里出现微小差异是预期的，不是移植错误。`,
    }));
  }
}

let frame = 0;
let playing = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function render() {
  if (moon === null) return;
  const comparing = $('compare').checked;
  const drawn = drawFrame(frame, comparing);
  $('frameLabel').textContent = ` · 第 ${frame} 帧`;
  if (comparing) {
    stats.frames++;
    compareFrame(drawn);
  }
  showStats(comparing);
  frame++;
}

function restart() {
  frame = 0;
  generated.clear();
  resetStats();
  $('officialFigure').hidden = !$('compare').checked;
  $('canvases').classList.toggle('single', !$('compare').checked);
  if (!playing) render();
}

let last = 0;
function loop(now) {
  if (!playing) return;
  if (now - last >= 1000 / Number($('fps').value)) {
    last = now;
    render();
  }
  requestAnimationFrame(loop);
}

function setPlaying(value) {
  playing = value;
  $('play').textContent = playing ? '暂停' : '播放';
  $('step').disabled = playing;
  if (playing) requestAnimationFrame(loop);
}

for (const id of ['fps', 'roughness']) {
  const input = $(id);
  const output = document.querySelector(`output[for="${id}"]`);
  const show = () => { output.textContent = input.value; };
  show();
  input.addEventListener('input', () => {
    show();
    if (id === 'roughness') restart();
  });
}
$('mode').addEventListener('input', () => {
  $('fps').value = DEFAULT_FPS[$('mode').value];
  document.querySelector('output[for="fps"]').textContent = $('fps').value;
  restart();
});
$('compare').addEventListener('input', restart);
$('play').addEventListener('click', () => setPlaying(!playing));
$('step').addEventListener('click', render);

resetStats();
restart();
if (playing) render();
setPlaying(playing);
