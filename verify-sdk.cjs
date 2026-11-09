const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = process.cwd();

const pkg = require(path.join(root, 'package.json'));
const lock = require(path.join(root, 'package-lock.json'));

const rootSdkPath = 'node_modules/@recogito/studio-sdk';

const rootSdkLock = lock.packages[rootSdkPath];

assert.ok(
  rootSdkLock,
  'Root @recogito/studio-sdk is missing from package-lock.json'
);

const rootSdkVersion = rootSdkLock.version;

const rootSdkRealPath = fs.realpathSync(
  path.join(root, rootSdkPath)
);

// GeoTagger is the plugin being verified.
// It must resolve the same SDK instance as the application.
const geotaggingPath = path.join(
  root,
  'node_modules/@recogito/plugin-geotagging'
);

assert.ok(
  fs.existsSync(geotaggingPath),
  'Missing @recogito/plugin-geotagging'
);

const geotaggingSdk = require.resolve(
  '@recogito/studio-sdk',
  { paths: [geotaggingPath] }
);

const geotaggingSdkRealPath = fs.realpathSync(geotaggingSdk);

assert.equal(
  geotaggingSdkRealPath,
  rootSdkRealPath,
  [
    'GeoTagger resolves a different studio-sdk instance.',
    `Root SDK: ${rootSdkRealPath}`,
    `GeoTagger SDK: ${geotaggingSdkRealPath}`
  ].join('\n')
);

console.log(
  `Verified root studio-sdk ${rootSdkVersion}; ` +
  `GeoTagger resolves the same SDK instance.`
);

// Show the legacy plugin SDK versions for diagnostics.
// These are expected to remain separate until those plugins are upgraded.
for (const name of [
  'plugin-ner',
  'plugin-revisions',
  'plugin-tei-inliner'
]) {
  const plugin = path.join(root, 'node_modules/@recogito', name);

  if (!fs.existsSync(plugin))
    continue;

  try {
    const resolved = require.resolve(
      '@recogito/studio-sdk/package.json',
      { paths: [plugin] }
    );

    const pluginSdk = require(resolved);

    console.log(
      `${name} resolves studio-sdk ${pluginSdk.version}`
    );
  } catch (err) {
    console.warn(
      `${name}: could not resolve studio-sdk`
    );
  }
}

console.log('SDK verification passed.');
