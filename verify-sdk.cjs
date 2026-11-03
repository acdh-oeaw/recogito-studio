const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = process.cwd();
const pkg = require(path.join(root, 'package.json'));
const lock = require(path.join(root, 'package-lock.json'));
const sdkKey = 'node_modules/@recogito/studio-sdk';
const entries = Object.entries(lock.packages).filter(([p]) => p.endsWith(sdkKey));
assert.equal(entries.length, 1, `Expected one SDK in lockfile: ${JSON.stringify(entries.map(([p,v]) => [p,v.version]))}`);
assert.equal(entries[0][0], sdkKey);
const expected = fs.realpathSync(path.join(root, sdkKey));
for (const name of ['plugin-ner', 'plugin-geotagging', 'plugin-revisions', 'plugin-tei-inliner']) {
  const plugin = path.join(root, 'node_modules/@recogito', name);
  assert.ok(fs.existsSync(plugin), `Missing ${name}`);
  const resolved = require.resolve('@recogito/studio-sdk', { paths: [plugin] });
  assert.ok(fs.realpathSync(resolved).startsWith(expected + path.sep), `${name} resolves a separate SDK: ${resolved}`);
}
for (const key of ['dependencies', 'devDependencies', 'optionalDependencies']) {
  assert.deepEqual(lock.packages[''][key], pkg[key], `package/lock mismatch: ${key}`);
}
console.log(`Verified one SDK: ${entries[0][1].version}; package/lock agree; all four plugins resolve the root SDK.`);
