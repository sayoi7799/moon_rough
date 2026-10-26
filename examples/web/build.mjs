// Builds the MoonBit side of the demo and copies it next to the page.
//
//   node examples/web/build.mjs

import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');

execSync('moon build --target js --release', { cwd: root, stdio: 'inherit' });

const built = path.join(root, '_build', 'js', 'release', 'build', 'examples', 'web_demo', 'web_demo.js');
const target = path.join(here, 'moon_rough_demo.js');
fs.copyFileSync(built, target);
console.log(`wrote ${path.relative(root, target)} (${fs.statSync(target).size} bytes)`);
