/**
 * react-native-macos-official
 *
 * Out-of-tree React Native platform for macOS.
 * Re-exports react-native and adds macOS-specific modules.
 */

'use strict';

// Re-export everything from react-native
module.exports = require('react-native');

// macOS-specific additions
Object.defineProperty(module.exports, 'SoundManager', {
  get: () => require('./src/Libraries/Components/Sound/SoundManager'),
});

Object.defineProperty(module.exports, 'PlatformColorValueTypesMacOS', {
  get: () => require('./src/Libraries/StyleSheet/PlatformColorValueTypesMacOS'),
});
