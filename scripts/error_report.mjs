// Runs `moon test` on every backend and prints the "[error report]" lines
// of the fixture suites as a Markdown table (used in the README).
//
//   node scripts/error_report.mjs

import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TARGETS = ['js', 'wasm-gc', 'native'];
const LINE = /\[error report\] (.+): (\d+) values, (\d+) not bit-identical, max abs error (\S+), max rel error (\S+)/;

const suites = new Map();
for (const target of TARGETS) {
  let out;
  try {
    out = execSync(`moon test --target ${target}`, { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 28 });
  } catch (e) {
    console.error(`moon test --target ${target} failed`);
    process.stderr.write(e.stdout ?? '');
    process.exit(1);
  }
  const total = /Total tests: (\d+), passed: (\d+), failed: (\d+)/.exec(out);
  console.error(`${target}: ${total ? total[0] : 'no summary'}`);
  for (const line of out.split('\n')) {
    const m = LINE.exec(line);
    if (!m) continue;
    const [, name, values, inexact, maxAbs] = m;
    if (!suites.has(name)) suites.set(name, { values, results: {} });
    suites.get(name).results[target] = `${maxAbs} (${inexact} inexact)`;
  }
}

const rows = [...suites.entries()].sort(([a], [b]) => a.localeCompare(b));
console.log(`| suite | values | ${TARGETS.join(' | ')} |`);
console.log(`|---|---:|${TARGETS.map(() => '---').join('|')}|`);
let total = 0;
for (const [name, { values, results }] of rows) {
  total += Number(values);
  console.log(`| ${name} | ${values} | ${TARGETS.map((t) => results[t] ?? 'n/a').join(' | ')} |`);
}
console.log(`\n${total} compared values in total; cells show the maximum absolute error.`);
