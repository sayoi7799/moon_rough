// A canvas that writes down every call and assignment, and the comparison of
// two such lists. Used by the Node tests of the demo.
//
// The results are bit-identical to rough.js on Node 24 / x64, the reference
// of the fixtures. On a machine whose Math.sin / cos / tan differ in the last
// bit (e.g. arm64), set ALLOW_INEXACT=1 to accept differences below 1e-9.

export const tolerant = process.env.ALLOW_INEXACT === '1';

/** A canvas whose context writes down every call and assignment. */
export function recordingCanvas() {
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

export function sameValue(a, b) {
  if (typeof a === 'number' && typeof b === 'number') {
    return tolerant ? Math.abs(a - b) <= 1e-9 : Object.is(a, b);
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((x, i) => sameValue(x, b[i]));
  }
  return a === b;
}

export function sameEvents(a, b) {
  return a.length === b.length && a.every((e, i) => sameValue(e, b[i]));
}
