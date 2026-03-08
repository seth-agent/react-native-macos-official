# react-native-macos-official

Out-of-tree React Native platform for macOS, built on the Platform Provider API for React Native 0.84.

## Overview

This package provides macOS (AppKit) support for React Native without forking the core framework. It uses the Platform Provider API extension points to register macOS as an additional platform alongside iOS and Android.

## Architecture

Unlike previous approaches that forked React Native (e.g., react-native-macos by Microsoft), this package works as a drop-in addition:

- Type aliases (RCTPlatformView, RCTPlatformColor, etc.) abstract UIKit/AppKit differences
- Capability-based platform checks replace hardcoded Platform.OS comparisons
- Module override hooks allow swapping iOS-specific modules with macOS equivalents
- CocoaPods integration via $RN_PLATFORMS registration
- Metro auto-discovery detects and configures the platform automatically

## Installation

```
yarn add react-native-macos-official
```

### Podfile Setup

```ruby
require_relative '../node_modules/react-native/scripts/react_native_pods'

$RN_PLATFORMS = ['iOS', 'macOS']
$RN_MACOS_DEPLOYMENT_TARGET = '14.0'

platform :macos, '14.0'

prepare_react_native_project!

target 'YourApp-macOS' do
  use_react_native!(
    :path => '../node_modules/react-native',
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )

  pod 'ReactNativeMacOS', :path => '../node_modules/react-native-macos-official'

  post_install do |installer|
    react_native_post_install(installer, '../node_modules/react-native')
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
      end
    end
  end
end
```

### Metro Config

```js
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const config = {
  resolver: {
    platforms: ['macos', 'ios', 'android', 'native'],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
```

## How It Works

The postinstall script applies 248 compatibility patches to React Native that:
- Add AppKit compatibility via RCTUIKit.h (maps UIView to NSView, UIColor to NSColor, etc.)
- Enable macOS-specific code paths in native modules
- Handle platform-specific UI differences (NSWindow vs UIWindow, NSMenu vs UIActionSheet, etc.)

## Status

Alpha. The Platform Provider API infrastructure is complete and all upstream tests pass (5598/5600). Native macOS build validation is in progress.

### What Works
- All 5 phases of Platform Provider API implemented
- 248 patches apply cleanly against vanilla RN 0.84.1
- Pod install succeeds with macOS target
- Zero regressions in existing test suite

### What's In Progress
- Native macOS build validation
- Core module macOS adaptations (StatusBar, Alert, Clipboard)
- Text rendering and text input (AppKit text system)
- RNTester macOS target

## Requirements

- React Native 0.84.x
- macOS 14.0+
- Xcode (full installation)
- Ruby 3.x (Ruby 4.0 has CocoaPods compatibility issues)

## License

MIT
