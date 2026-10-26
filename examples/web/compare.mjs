// Compares what moon_rough generated with what the official rough.js
// generated for the same description.

/**
 * `mine` and `official` are lists of op sets: `{ type, ops: [{ op, data }] }`
 * (moon_rough's `generate` result and rough.js' `drawable.sets`).
 *
 * Reports whether the structure (the number and types of the op sets and
 * ops) is the same, how many numbers there are, how many of them differ
 * and by how much at most.
 */
export function compareSets(mine, official) {
  const result = {
    sameStructure: true,
    sets: official.length,
    ops: 0,
    values: 0,
    differing: 0,
    maxAbs: 0,
    problem: null,
  };
  const fail = (message) => {
    if (result.sameStructure) result.problem = message;
    result.sameStructure = false;
  };
  if (mine.length !== official.length) {
    fail(`${mine.length} op sets against ${official.length}`);
    return result;
  }
  for (let i = 0; i < official.length; i++) {
    const a = mine[i];
    const b = official[i];
    if (a.type !== b.type) fail(`op set ${i} is ${a.type}, rough.js has ${b.type}`);
    if (a.ops.length !== b.ops.length) {
      fail(`op set ${i} has ${a.ops.length} ops, rough.js has ${b.ops.length}`);
      continue;
    }
    result.ops += b.ops.length;
    for (let j = 0; j < b.ops.length; j++) {
      const x = a.ops[j];
      const y = b.ops[j];
      if (x.op !== y.op || x.data.length !== y.data.length) {
        fail(`op ${j} of set ${i} is ${x.op}, rough.js has ${y.op}`);
        continue;
      }
      for (let k = 0; k < y.data.length; k++) {
        result.values++;
        if (x.data[k] !== y.data[k]) {
          result.differing++;
          result.maxAbs = Math.max(result.maxAbs, Math.abs(x.data[k] - y.data[k]));
        }
      }
    }
  }
  return result;
}

/** Number of pixels that differ between two `ImageData`s of the same size. */
export function comparePixels(a, b) {
  if (a.width !== b.width || a.height !== b.height) {
    return { total: 0, differing: Infinity };
  }
  let differing = 0;
  const total = a.width * a.height;
  for (let i = 0; i < a.data.length; i += 4) {
    if (a.data[i] !== b.data[i] || a.data[i + 1] !== b.data[i + 1]
      || a.data[i + 2] !== b.data[i + 2] || a.data[i + 3] !== b.data[i + 3]) {
      differing++;
    }
  }
  return { total, differing };
}
