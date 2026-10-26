// The page: reads the controls, draws the same shape with moon_rough and with
// the official rough.js, and shows whether the two agree.

import { comparePixels, compareSets } from './compare.mjs';
import { FILL_STYLES, SHAPES, drawOfficial, makeSpec } from './spec.mjs';

const WIDTH = 420;
const HEIGHT = 320;
const $ = (id) => document.getElementById(id);

const SHAPE_NAMES = {
  line: '直线 line',
  rectangle: '矩形 rectangle',
  ellipse: '椭圆 ellipse',
  circle: '圆 circle',
  polygon: '多边形 polygon',
  arc: '扇形 arc',
  curve: '曲线 curve',
  linearPath: '折线 linearPath',
  path: 'SVG 路径 path',
};

for (const shape of Object.keys(SHAPES)) {
  $('shape').add(new Option(SHAPE_NAMES[shape], shape));
}
$('shape').value = 'polygon';
$('fillStyle').add(new Option('无填充', ''));
for (const style of FILL_STYLES) $('fillStyle').add(new Option(style, style));
$('fillStyle').value = 'hachure';

let moon = null;
try {
  moon = await import('./moon_rough_demo.js');
} catch (error) {
  showFatal('找不到 moon_rough_demo.js。请先在仓库根目录运行 node examples/web/build.mjs，再用 node examples/web/serve.mjs 打开本页。', error);
}

function showFatal(message, error) {
  $('verdict').className = 'badge bad';
  $('verdict').textContent = '无法运行';
  $('verdictText').textContent = message;
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

function currentSpec() {
  const options = {
    seed: Math.max(1, Math.floor(Number($('seed').value) || 1)),
    roughness: Number($('roughness').value),
    bowing: Number($('bowing').value),
    strokeWidth: Number($('strokeWidth').value),
    stroke: $('stroke').value,
    hachureAngle: Number($('hachureAngle').value),
    hachureGap: Number($('hachureGap').value),
  };
  if ($('fillStyle').value !== '') {
    options.fill = $('fill').value;
    options.fillStyle = $('fillStyle').value;
  }
  return makeSpec($('shape').value, options);
}

const number = (x) => x.toLocaleString('en-US');

function mark(kind) {
  return { ok: '✓', warn: '≈', bad: '✗' }[kind];
}

function setChecks(rows) {
  const list = $('checks');
  list.replaceChildren();
  for (const [name, kind, text] of rows) {
    const li = document.createElement('li');
    const n = document.createElement('span');
    n.className = 'name';
    n.textContent = name;
    const m = document.createElement('span');
    m.className = `mark ${kind}`;
    m.textContent = mark(kind);
    const t = document.createElement('span');
    t.textContent = text;
    li.append(n, m, t);
    list.append(li);
  }
}

function setNotes(lines) {
  const list = $('notes');
  list.replaceChildren();
  for (const line of lines) {
    const li = document.createElement('li');
    li.textContent = line;
    list.append(li);
  }
}

function setVerdict(kind, label, text) {
  $('verdict').className = `badge ${kind}`;
  $('verdict').textContent = label;
  $('verdictText').textContent = text;
}

// tan(1e22) is one of the values whose last bit differs between math
// libraries: the one fdlibm (and moon_rough) gives is -1.628778225606899.
const hostTan = Math.tan(1e22);
const hostMathMatches = hostTan === -1.628778225606899;

function render() {
  if (moon === null) return;
  const spec = currentSpec();
  const json = JSON.stringify(spec);
  const mineCanvas = $('mine');
  const officialCanvas = $('official');

  // moon_rough: draw() on the first canvas, generate() for the ops.
  const mineCtx = prepare(mineCanvas);
  const message = moon.draw(mineCtx, json);
  if (message !== '') {
    setVerdict('bad', '出错', message);
    setChecks([]);
    setNotes([]);
    return;
  }
  const mine = JSON.parse(moon.generate(json));

  // The official rough.js on the second canvas.
  prepare(officialCanvas);
  const drawable = drawOfficial(window.rough, officialCanvas, spec);

  const ops = compareSets(mine.sets, drawable.sets);
  const pixels = comparePixels(
    mineCanvas.getContext('2d').getImageData(0, 0, mineCanvas.width, mineCanvas.height),
    officialCanvas.getContext('2d').getImageData(0, 0, officialCanvas.width, officialCanvas.height),
  );

  const rows = [];
  if (ops.sameStructure) {
    rows.push(['操作序列', 'ok', `${ops.sets} 组线条、共 ${number(ops.ops)} 个 move / lineTo / bcurveTo，类型和顺序完全一致`]);
  } else {
    rows.push(['操作序列', 'bad', `不一致：${ops.problem}`]);
  }
  if (!ops.sameStructure) {
    rows.push(['坐标', 'bad', '结构不同，无法逐个比较']);
  } else if (ops.differing === 0) {
    rows.push(['坐标', 'ok', `${number(ops.values)} 个数值逐位相同`]);
  } else {
    rows.push(['坐标', 'warn', `${number(ops.values)} 个数值里有 ${number(ops.differing)} 个不同，最大误差 ${ops.maxAbs.toExponential(2)}`]);
  }
  if (pixels.differing === 0) {
    rows.push(['像素', 'ok', `两张画布的 ${number(pixels.total)} 个像素完全相同`]);
  } else {
    rows.push(['像素', 'warn', `${number(pixels.differing)} 个像素不同（共 ${number(pixels.total)}）`]);
  }
  setChecks(rows);

  if (!ops.sameStructure) {
    setVerdict('bad', '不一致', '两边画出的线条结构不同');
  } else if (ops.differing === 0 && pixels.differing === 0) {
    setVerdict('ok', '完全一致', '操作序列、每个坐标和每个像素都相同');
  } else {
    setVerdict('warn', '有微小差异', '结构相同，数值有最后几位的差别');
  }

  const notes = [];
  if (ops.sameStructure && ops.differing > 0) {
    notes.push(hostMathMatches
      ? '官方 rough.js 用的是浏览器自己的 Math.sin / cos / tan，moon_rough 用 fdlibm，两者的最后一位在个别输入上可能不同。'
      : `你的浏览器里 Math.tan(1e22) = ${hostTan}，和 fdlibm 的 -1.628778225606899 不同，说明它的三角函数和 moon_rough 在最后一位上有差别；官方 rough.js 用的是浏览器的实现，所以这里出现微小差异是预期的，不是移植错误。`);
  } else if (!hostMathMatches) {
    notes.push(`提示：你的浏览器里 Math.tan(1e22) = ${hostTan}，和 fdlibm 的 -1.628778225606899 不同，某些参数下两边可能出现最后一位的差别。`);
  }
  if (spec.options.fillStyle === 'dots') {
    notes.push('rough.js 的 dots 填充用没有种子的 Math.random() 决定点的位置，同一个 seed 在官方 rough.js 里每次画出来都不一样。为了能比较，这里把官方那一边的 Math.random 临时换成了和 MoonBit 相同的固定序列。');
  }
  setNotes(notes);
}

let pending = false;
function schedule() {
  if (pending) return;
  pending = true;
  requestAnimationFrame(() => {
    pending = false;
    render();
  });
}

for (const id of ['roughness', 'bowing', 'hachureAngle', 'hachureGap', 'strokeWidth']) {
  const input = $(id);
  const output = document.querySelector(`output[for="${id}"]`);
  const show = () => { output.textContent = input.value; };
  show();
  input.addEventListener('input', () => { show(); schedule(); });
}
for (const id of ['shape', 'fillStyle', 'seed', 'stroke', 'fill']) {
  $(id).addEventListener('input', schedule);
}
$('randomSeed').addEventListener('click', () => {
  $('seed').value = 1 + Math.floor(Math.random() * 99999);
  schedule();
});

render();
