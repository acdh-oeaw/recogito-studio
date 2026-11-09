const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = process.cwd();

const pkg = require(path.join(root, 'package.json'));
const lock = require(path.join(root, 'package-lock.json'));

const sdkKey = 'node_modules/@recogito/studio-sdk';
const rootSdkPath = path.join(root, sdkKey);

assert.ok(
  fs.existsSync(rootSdkPath),
  `Missing root ${sdkKey}`
);

const rootSdkLock = lock.packages[sdkKey];

assert.ok(
  rootSdkLock,
  `Missing ${sdkKey} in package-lock.json`
);

const rootSdkVersion = rootSdkLock.version;
const rootSdkRealPath = fs.realpathSync(rootSdkPath);

// Verify that GeoTagger resolves the ROOT SDK.
// require.resolve() returns the package entry point
// (e.g. dist/index.js), not the package directory.
const geotaggingPath = path.join(
  root,
  'node_modules/@recogito/plugin-geotagging'
);

assert.ok(
  fs.existsSync(geotaggingPath),
  'Missing @recogito/plugin-geotagging'
);

const geotaggingResolved = require.resolve(
  '@recogito/studio-sdk',
  { paths: [geotaggingPath] }
);

const geotaggingRealPath = fs.realpathSync(geotaggingResolved);

assert.ok(
  geotaggingRealPath === rootSdkRealPath ||
  geotaggingRealPath.startsWith(rootSdkRealPath + path.sep),
  [
    'GeoTagger resolves a different studio-sdk instance.',
    `Root SDK: ${rootSdkRealPath}`,
    `GeoTagger SDK: ${geotaggingRealPath}`
  ].join('\n')
);

console.log(
  `Verified root studio-sdk ${rootSdkVersion}; ` +
  `GeoTagger resolves the same SDK instance.`
);

// Legacy plugins are expected to use their own 0.9.1 SDK
// until those plugins are upgraded.
for (const name of [
  'plugin-ner',
  'plugin-revisions',
  'plugin-tei-inliner'
]) {
  const plugin = path.join(
    root,
    'node_modules/@recogito',
    name
  );

  if (!fs.existsSync(plugin))
    continue;

  try {
    const resolved = require.resolve(
      '@recogito/studio-sdk',
      { paths: [plugin] }
    );

    const resolvedRealPath = fs.realpathSync(resolved);

    console.log(
      `${name} resolves studio-sdk from ${resolvedRealPath}`
    );
  } catch {
    console.warn(
      `${name}: could not resolve studio-sdk`
    );
  }
}

for (const key of [
  'dependencies',
  'devDependencies',
  'optionalDependencies'
]) {
  assert.deepEqual(
    lock.packages[''][key],
    pkg[key],
    `package/lock mismatch: ${key}`
  );
}

console.log(
  `SDK verification passed. Root SDK: ${rootSdkVersion}`
);
