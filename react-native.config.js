/**
 * React Native CLI configuration for the macOS out-of-tree platform.
 *
 * This registers the "macos" platform with the RN CLI, enabling:
 * - `npx react-native run-macos`
 * - Auto-linking of native dependencies for macOS
 * - Project/dependency config discovery for macOS targets
 */

'use strict';

const path = require('path');

let apple;
try {
  apple = require('@react-native-community/cli-platform-apple');
} catch {
  console.warn(
    'react-native-macos-official: @react-native-community/cli-platform-apple not found.',
  );
}

const runMacOSCommands = require('./cli/commands/runMacOS');

const commands = [...runMacOSCommands];

const config = {
  commands,
  platforms: {},
};

if (apple) {
  config.platforms.macos = {
    linkConfig: () => ({
      isInstalled: () => false,
      register: () => {},
      unregister: () => {},
      copyAssets: () => {},
      unlinkAssets: () => {},
    }),
    projectConfig: apple.getProjectConfig({platformName: 'macos'}),
    dependencyConfig: apple.getProjectConfig({platformName: 'macos'}),
    npmPackageName: 'react-native-macos-official',
  };
}

module.exports = config;
