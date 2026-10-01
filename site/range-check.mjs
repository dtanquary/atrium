// node site/range-check.mjs: checks the byte ranges functions/media answers, so Safari keeps getting its video.
import assert from 'node:assert/strict';
import { byteRange } from './functions/media/[[path]].js';

assert.deepEqual(byteRange('bytes=0-1', 100), [0, 1]); // Safari's first probe
assert.deepEqual(byteRange('bytes=10-', 100), [10, 99]);
assert.deepEqual(byteRange('bytes=90-500', 100), [90, 99]); // past the end is clipped
assert.deepEqual(byteRange('bytes=-30', 100), [70, 99]); // the last 30 bytes
assert.deepEqual(byteRange('bytes=-300', 100), [0, 99]);
assert.equal(byteRange(null, 100), null);
assert.equal(byteRange('bytes=0-1,5-6', 100), null); // several ranges: send the whole file
assert.equal(byteRange('bytes=-', 100), null);
assert.equal(byteRange('bytes=100-', 100), 'unsatisfiable');
assert.equal(byteRange('bytes=5-2', 100), 'unsatisfiable');
console.log('byte ranges ok');
