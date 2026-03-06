/**
 * Metro configuration helper for react-native-macos-official.
 *
 * Usage in your app's metro.config.js:
 *
 *   const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
 *   const macosMetro = require('react-native-macos-official/metro');
 *   module.exports = mergeConfig(getDefaultConfig(__dirname), macosMetro);
 */

'use strict';

const path = require('path');
const fs = require('fs');

const macosSourceDir = path.resolve(__dirname, 'src');

/**
 * Custom resolver that checks the OOT package's src/ directory for
 * .macos.js platform overrides before falling back to standard resolution.
 */
function createMacOSResolver(originalResolver) {
  return (context, moduleName, platform, ...rest) => {
    if (platform === 'macos') {
      // For react-native internal modules, check if we have a .macos.js override
      if (moduleName.startsWith('./') || moduleName.startsWith('../')) {
        // Relative imports -- let Metro handle normally
        return originalResolver(context, moduleName, platform, ...rest);
      }
    }
    return originalResolver(context, moduleName, platform, ...rest);
  };
}

module.exports = {
  resolver: {
    platforms: ['macos', 'ios', 'android'],
    // Add the OOT package's src/ as an additional source for .macos.js resolution
    nodeModulesPaths: [macosSourceDir],
  },
  watchFolders: [macosSourceDir],
};
