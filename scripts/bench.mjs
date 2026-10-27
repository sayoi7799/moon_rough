// Runs the benchmarks on Node (rough.js) and on the three MoonBit backends and
// prints the table of the README.
//
//   node scripts/bench.mjs                       run everything, print the table
//   node scripts/bench.mjs --out run1.json       also save the raw numbers
//   node scripts/bench.mjs --table run1.json     print the table of a saved run
//   node scripts/bench.mjs --compare run1.json run2.json
//                                                compare two saved runs, to spot outliers
//
// Needs the MoonBit toolchain and `npm ci` in scripts/. The benchmarks are
// built with --release. Everything runs one after the other: a benchmark
// that shares the machine with another one is not worth much.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const TARGETS = ['js', 'wasm-gc', 'native'];

const NAMES = [
  ['random_shapes_10k', '10,000 个随机图形（生成）'],
  ['dots_500', '500 个 dots 填充的图形'],
  ['path_parse', '复杂路径：解析、绝对化、规范化'],
  ['path_points_on_path', '复杂路径：曲线采样和简化'],
  ['path_fill_hachure', '复杂路径：hachure 填充'],
  ['path_fill_solid', '复杂路径：solid 填充'],
  ['path_fill_cross_hatch', '复杂路径：cross-hatch 填充'],
  ['svg_output_10k', '10,000 个图形转 SVG 字符串'],
  ['svg_output_10k_fixed2', '同上，保留两位小数'],
];

const UNIT = { ns: 1, 'µs': 1e3, 'μs': 1e3, ms: 1e6, s: 1e9 };
const toNs = (value, unit) => Number(value) * UNIT[unit];

function format(ns) {
  if (ns >= 1e9) return `${(ns / 1e9).toFixed(2)} s`;
  if (ns >= 1e6) return `${(ns / 1e6).toFixed(ns >= 1e8 ? 0 : 1)} ms`;
  if (ns >= 1e3) return `${(ns / 1e3).toFixed(ns >= 1e5 ? 0 : 1)} µs`;
  return `${ns.toFixed(0)} ns`;
}

/** Parses the output of `moon bench`: the name, then "mean ± sd  min … max  in 10 × N runs". */
function parseMoonBench(text) {
  const results = {};
  let name = null;
  const unit = '(ns|µs|μs|ms|s)';
  const line = new RegExp(`^\\s*([\\d.]+) ${unit} ±\\s*([\\d.]+) ${unit}\\s+([\\d.]+) ${unit} …\\s+([\\d.]+) ${unit}\\s+in (\\d+) ×\\s+(\\d+) runs`);
  for (const raw of text.split('\n')) {
    const named = /bench .*\("([^"]+)"\)/.exec(raw);
    if (named) { name = named[1]; continue; }
    const m = line.exec(raw);
    if (m && name) {
      results[name] = {
        mean: toNs(m[1], m[2]), sd: toNs(m[3], m[4]),
        min: toNs(m[5], m[6]), max: toNs(m[7], m[8]), batch: Number(m[10]),
      };
      name = null;
    }
  }
  return results;
}

function run(command, args, options = {}) {
  return execFileSync(command, args, { cwd: root, encoding: 'utf8', maxBuffer: 1 << 28, ...options });
}

function collect() {
  const node = JSON.parse(run('node', [path.join(here, 'bench_roughjs.mjs')]));
  const data = { environment: node.environment, 'rough.js': node.results };
  data.environment.moon = run('moon', ['version']).split('\n')[0];
  for (const target of TARGETS) {
    console.error(`moon bench --release --target ${target} ...`);
    const text = run('moon', ['bench', '-p', 'sayoi7799/moon_rough/perf', '--target', target, '--release']);
    data[target] = parseMoonBench(text);
    const missing = NAMES.filter(([key]) => !data[target][key]).map(([key]) => key);
    if (missing.length) throw new Error(`${target}: no result for ${missing.join(', ')}`);
  }
  return data;
}

function table(data) {
  const lines = [
    '| 项目 | rough.js（Node） | moon_rough js | wasm-gc | native |',
    '|---|---:|---:|---:|---:|',
  ];
  for (const [key, label] of NAMES) {
    const base = data['rough.js'][key];
    const cells = TARGETS.map((target) => {
      const r = data[target][key];
      const ratio = base.mean / r.mean; // > 1: faster than rough.js
      const text = ratio >= 1 ? `${ratio.toFixed(1)}× 快` : `${(1 / ratio).toFixed(1)}× 慢`;
      return `${format(r.mean)}（${text}）`;
    });
    lines.push(`| ${label} | ${format(base.mean)} | ${cells.join(' | ')} |`);
  }
  return lines.join('\n');
}

function compare(a, b) {
  console.log('| 项目 | ' + ['rough.js', ...TARGETS].map((t) => `${t}: 第二次 / 第一次`).join(' | ') + ' |');
  console.log('|---|' + '---:|'.repeat(TARGETS.length + 1));
  let worst = 0;
  for (const [key] of NAMES) {
    const cells = ['rough.js', ...TARGETS].map((t) => {
      const ratio = b[t][key].mean / a[t][key].mean;
      worst = Math.max(worst, Math.abs(ratio - 1));
      return ratio.toFixed(3);
    });
    console.log(`| ${key} | ${cells.join(' | ')} |`);
  }
  console.log(`\n最大偏差 ${(worst * 100).toFixed(1)}%`);
}

const args = process.argv.slice(2);
if (args[0] === '--table') {
  const data = JSON.parse(fs.readFileSync(args[1], 'utf8'));
  const e = data.environment;
  console.log(`${e.cpu.trim()}，${e.threads} 线程，${e.platform}；Node ${e.node}；${e.moon}
`);
  console.log(table(data));
} else if (args[0] === '--compare') {
  compare(JSON.parse(fs.readFileSync(args[1], 'utf8')), JSON.parse(fs.readFileSync(args[2], 'utf8')));
} else {
  const data = collect();
  const out = args.indexOf('--out');
  if (out >= 0) fs.writeFileSync(args[out + 1], JSON.stringify(data, null, 2));
  const e = data.environment;
  console.log(`${e.cpu.trim()}，${e.threads} 线程，${e.platform}；Node ${e.node}；${e.moon}\n`);
  console.log(table(data));
}
