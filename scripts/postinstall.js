#!/usr/bin/env node
/**
 * postinstall script for react-native-macos-official
 *
 * Applies macOS-specific patches to the local react-native installation
 * in node_modules. These patches add #if TARGET_OS_OSX guards and
 * macOS-specific behavior to upstream React Native files.
 *
 * Usage: node scripts/postinstall.js [--dry-run] [--verbose]
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const VERBOSE = args.includes('--verbose');

const OOT_ROOT = path.resolve(__dirname, '..');
const PATCHES_DIR = path.join(OOT_ROOT, 'patches', 'files');
const OVERRIDES_JSON = path.join(OOT_ROOT, 'patches', 'overrides.json');

// Find react-native in node_modules
function findReactNative() {
  const candidates = [
    path.resolve(OOT_ROOT, '..', 'react-native', 'packages', 'react-native'),
    path.resolve(OOT_ROOT, '..', 'react-native'),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, 'package.json'))) {
      try {
        const pkg = JSON.parse(
          fs.readFileSync(path.join(candidate, 'package.json'), 'utf8'),
        );
        if (
          pkg.name === 'react-native' ||
          pkg.name === '@react-native-macos/monorepo'
        ) {
          return candidate;
        }
      } catch {
        // continue
      }
    }
  }

  throw new Error(
    'Could not find react-native in node_modules. ' +
      'Make sure react-native is installed as a peer dependency.',
  );
}

function applyPatches() {
  const rnRoot = findReactNative();
  console.log(`react-native-macos-official: Applying macOS patches to ${rnRoot}`);

  if (!fs.existsSync(OVERRIDES_JSON)) {
    console.error('No overrides.json found. Skipping patch application.');
    return;
  }

  const overrides = JSON.parse(fs.readFileSync(OVERRIDES_JSON, 'utf8'));
  let applied = 0;
  let failed = 0;
  let skipped = 0;

  for (const override of overrides.overrides) {
    const { type, file } = override;

    if (type === 'platform') {
      // New file -- copy from OOT package to react-native
      const srcFile = path.join(OOT_ROOT, 'patches', 'files', file);
      // platform files don't have patches, they might be handled separately
      if (VERBOSE) {
        console.log(`  [platform] ${file} -- new file, skipping (handled by OOT package)`);
      }
      skipped++;
      continue;
    }

    const patchFile = path.join(PATCHES_DIR, `${file}.patch`);
    // Strip leading directory prefix (e.g. 'files-final/') to get the real path in react-native
    const relativeFile = file.replace(/^files-final\//, '');
    const targetFile = path.join(rnRoot, relativeFile);

    if (!fs.existsSync(patchFile)) {
      if (VERBOSE) {
        console.log(`  [skip] ${file} -- no patch file`);
      }
      skipped++;
      continue;
    }

    if (!fs.existsSync(targetFile)) {
      if (VERBOSE) {
        console.log(`  [skip] ${file} -- target not found in react-native`);
      }
      skipped++;
      continue;
    }

    if (DRY_RUN) {
      console.log(`  [dry-run] Would patch: ${file}`);
      applied++;
      continue;
    }

    try {
      // Apply the patch using the patch command
      execSync(
        `patch -p0 --forward --silent "${targetFile}" "${patchFile}"`,
        {
          cwd: rnRoot,
          stdio: VERBOSE ? 'inherit' : 'pipe',
        },
      );
      applied++;
      if (VERBOSE) {
        console.log(`  [ok] ${file}`);
      }
    } catch (err) {
      // patch may fail if already applied or if upstream has changed
      // Try reverse check to see if already applied
      try {
        execSync(
          `patch -p0 --reverse --dry-run --silent "${targetFile}" "${patchFile}"`,
          { cwd: rnRoot, stdio: 'pipe' },
        );
        // Reverse succeeded in dry-run = patch already applied
        skipped++;
        if (VERBOSE) {
          console.log(`  [already applied] ${file}`);
        }
      } catch {
        failed++;
        console.warn(`  [FAILED] ${file} -- patch could not be applied`);
        if (VERBOSE) {
          console.warn(`    Patch file: ${patchFile}`);
          console.warn(`    Target: ${targetFile}`);
        }
      }
    }
  }

  console.log(
    `react-native-macos-official: ${applied} applied, ${skipped} skipped, ${failed} failed`,
  );

  if (failed > 0) {
    console.warn(
      '\nSome patches failed to apply. This may be due to a version mismatch ' +
        'between react-native and react-native-macos-official. ' +
        `Expected react-native base version: ${overrides.baseVersion}`,
    );
  }
}

applyPatches();
