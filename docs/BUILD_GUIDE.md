# Build Guide: Getting React Native macOS Running

This guide covers end-to-end setup for building a React Native macOS app
using the react-native-macos-official OOT platform package.

## Prerequisites

- macOS 14.0 or later
- Xcode (full installation from App Store, not just Command Line Tools)
- Ruby 3.x (3.3 recommended; Ruby 4.0 has CocoaPods encoding issues)
- CocoaPods (`gem install cocoapods`)
- Node.js 18+ and Yarn
- React Native 0.84.x

### Ruby Setup

If using Homebrew:
```bash
brew install ruby@3.3
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
gem install cocoapods
```

If using asdf:
```bash
asdf install ruby 3.3.7
asdf local ruby 3.3.7
gem install cocoapods
```

Note: Ruby 4.0 causes `Encoding::CompatibilityError` in CocoaPods due to
removed kconv support. Use 3.x until CocoaPods updates.

### Xcode Setup

Ensure xcode-select points to Xcode.app, not Command Line Tools:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:
```bash
xcodebuild -version
```

## Creating a New macOS App

### 1. Scaffold the React Native project

```bash
npx @react-native-community/cli init MyMacApp --version 0.84.1
cd MyMacApp
```

### 2. Add the macOS platform package

```bash
yarn add react-native-macos-official
```

Or for local development:
```json
{
  "dependencies": {
    "react-native-macos-official": "file:../react-native-macos-official"
  }
}
```

### 3. Create the macOS target directory

Copy the template from react-native-macos-official/template/macos/ or
create manually:

```
macos/
  MyMacApp-macOS/
    AppDelegate.h
    AppDelegate.mm
    main.m
    Info.plist
    MyMacApp.entitlements
    Base.lproj/Main.storyboard
  MyMacApp.xcodeproj/
  Podfile
```

### 4. Configure the Podfile

```ruby
require_relative '../node_modules/react-native/scripts/react_native_pods'

$RN_PLATFORMS = ['iOS', 'macOS']
$RN_MACOS_DEPLOYMENT_TARGET = '14.0'

platform :macos, '14.0'

prepare_react_native_project!

target 'MyMacApp-macOS' do
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

### 5. Configure Metro

Add 'macos' to the platform resolver in metro.config.js:

```js
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const config = {
  resolver: {
    platforms: ['macos', 'ios', 'android', 'native'],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
```

### 6. Install dependencies

```bash
yarn install
cd macos && pod install && cd ..
```

The postinstall script automatically applies 248 compatibility patches.
Pod install downloads prebuilt artifacts (~130MB) and sets up 74 pods.

### 7. Build and run

From Xcode:
- Open `macos/MyMacApp.xcworkspace`
- Select the `MyMacApp-macOS` scheme
- Build and Run (Cmd+R)

From command line:
```bash
xcodebuild -workspace macos/MyMacApp.xcworkspace \
  -scheme MyMacApp-macOS \
  -configuration Debug \
  build
```

## Troubleshooting

### "tool 'xcodebuild' requires Xcode"
Only Command Line Tools are installed. Install full Xcode from the App Store.

### CocoaPods encoding error (Unicode Normalization)
Ruby 4.0 incompatibility. Switch to Ruby 3.3:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
```

### Pod install fails with platform errors
Ensure `$RN_PLATFORMS` includes 'macOS' and is set before `prepare_react_native_project!`.

### "RCTPlatformView" not found / category errors
Ensure patches applied correctly (check postinstall output). The patches use
`@compatibility_alias` (not `typedef`) for ObjC class type aliases, which is
required for category support.

### React/RCTPlatform.h not found in ReactCommon
ReactCommon pods (React-graphics, React-ImageManager, textlayoutmanager) are
separate pods that cannot see React-Core headers. These files must use UIKit
directly, not RCTPlatformTypes.h abstractions.

### Prebuilt xcframework missing headers
Set `RCT_USE_PREBUILT_RNCORE=0` to build React-Core from source instead of
using the prebuilt xcframework from Maven.

## Architecture Notes

### How Patches Work
The postinstall script reads `overrides.json` which maps source files in
`patches/files-final/` to their targets in node_modules/react-native/.
Each patch replaces the upstream file with the macOS-compatible version.

### Platform Provider API Phases
1. RCTPlatformTypes.h - Native type aliases (UIView -> RCTPlatformView)
2. RCTPlatformCapabilities.h - Capability-based checks
3. PlatformModuleOverrides.js - JS module replacement registry
4. Metro + CocoaPods auto-discovery and integration
5. index.js module override wiring

### Key Files
- `RCTUIKit.h` - 770-line UIKit/AppKit compatibility layer
- `RCTPlatformTypes.h` - Type aliases using @compatibility_alias
- `RCTPlatformCapabilities.h` - Runtime capability queries
- `platform-discovery.js` - Metro OOT platform scanner
- `cocoapods/platform_plugin.rb` - CocoaPods platform registration
