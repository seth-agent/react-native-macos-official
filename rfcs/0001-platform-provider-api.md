# RFC 0001: React Native Platform Provider API

## Summary

This RFC proposes a formal Platform Provider API for React Native that enables out-of-tree (OOT) platforms to integrate without forking or patching the core framework. The goal is to make every platform — iOS, Android, macOS, Windows, VisionOS, TV, and future targets — a pluggable "projection" of React onto a native surface, rather than a hardcoded special case.

## Motivation

### The Problem Today

React Native has no clean platform boundary. Platform-specific code is scattered across hundreds of source files through:

- Inline `Platform.OS === 'ios'` conditionals in JS
- `#if TARGET_OS_OSX` / `#ifdef __ANDROID__` guards in native code
- `UIKit` type references hardcoded into shared Obj-C/C++ headers
- Platform-suffixed files (`.ios.js`, `.android.js`) that only work for first-party platforms
- `NativeEventEmitter` constructor guards that enumerate known platforms
- `Platform.select({ios: ..., android: ...})` calls with closed platform sets
- Component props defined inline with no extension mechanism

This design forces every new platform to either:

1. **Maintain a full fork** (Microsoft's approach for react-native-macos and react-native-windows), bearing enormous ongoing merge burden
2. **Patch source files at install time** (the approach we prototyped for react-native-macos-official), which is fragile and breaks on every upstream update

### Evidence: Patch Analysis

We built a proof-of-concept OOT macOS platform targeting React Native 0.84. To make it work without forking, we needed **248 source patches** across the React Native codebase. Categorizing these patches reveals where the platform abstraction leaks:

| Category | Patches | % of Total | Description |
|---|---|---|---|
| UIKit/AppKit type abstraction | 166 | 67% | Replacing `UIView`, `UIColor`, `UIImage`, etc. with platform-agnostic types |
| Import header changes | 129 | 52% | Adding `#import <RCTUIKit/RCTUIKit.h>` instead of `<UIKit/UIKit.h>` |
| Conditional compilation | 55 | 22% | Adding `#if TARGET_OS_OSX` guards around platform-specific native code |
| Platform.OS checks | 12 | 5% | Adding `Platform.OS === 'macos'` to existing iOS-only conditionals |
| View prop extensions | 7 | 3% | Adding macOS-specific props (tooltip, cursor, focusRing) to core components |
| Keyboard/mouse events | 2 | 1% | Desktop input event support |
| Build configuration | 2 | 1% | Podspec modifications |
| Type definitions | 4 | 2% | TypeScript declaration updates |

(Patches can belong to multiple categories; percentages exceed 100%.)

**The critical insight: 67% of patches exist solely because UIKit types are hardcoded into shared code.** A proper native type abstraction would eliminate two-thirds of the patching surface immediately.

### The Cost of the Status Quo

- **Microsoft's react-native-macos fork** is permanently ~3 major versions behind upstream (currently based on 0.73, upstream is at 0.84). Each upgrade takes months of engineering.
- **react-native-windows** maintains >1000 override files to track upstream changes.
- **New platforms** (VisionOS, TV, embedded) face the same fork-or-patch dilemma.
- **Meta's own platforms** (iOS and Android) benefit from being first-class but create an implicit two-tier system where OOT platforms are second-class citizens.

## Design Principles

1. **Platforms are projections, not forks.** React is the programming model. Each platform projects that model onto a native surface. The core must be platform-agnostic.

2. **No platform enumeration in core.** Code that says `if (Platform.OS === 'ios')` is a bug in the abstraction. Core code should query capabilities, not identity.

3. **Extension over modification.** Platforms must be able to add props, events, modules, and views without modifying core source files.

4. **Zero-patch integration.** A well-behaved OOT platform package should require exactly zero patches to core React Native source code.

5. **Incremental adoption.** The API must be adoptable incrementally. iOS and Android are refactored first as reference implementations, then OOT platforms follow.

## Detailed Design

### 1. Platform Provider Registration

A platform package exports a `PlatformProvider` that registers itself with React Native at initialization time.

```javascript
// react-native-macos-official/index.js
import { PlatformRegistry } from 'react-native';

PlatformRegistry.register('macos', {
  // JS-layer platform services
  modules: MacOSModules,
  viewConfigs: MacOSViewConfigs,
  componentOverrides: MacOSComponentOverrides,

  // Capability declarations
  capabilities: {
    statusBar: false,
    haptics: false,
    keyboard: true,
    mouse: true,
    menuBar: true,
    multipleWindows: true,
    tooltip: true,
    cursor: true,
    focusRing: true,
    dragAndDrop: true,
  },
});
```

The `PlatformRegistry` replaces all `Platform.OS` checks in core with capability queries:

```javascript
// BEFORE (platform enumeration - bad)
if (Platform.OS === 'ios') {
  return value;
}

// AFTER (capability query - good)
if (Platform.capabilities.statusBar) {
  return value;
}

// Or for NativeEventEmitter guards:
// BEFORE
new NativeEventEmitter(
  Platform.OS !== 'ios' ? null : NativeModule,
)

// AFTER
new NativeEventEmitter(
  Platform.capabilities.nativeEventEmitters ? NativeModule : null,
)
```

### 2. Native Type Abstraction Layer

This is the highest-impact change. Today, 166 of our 248 patches (67%) exist because shared Obj-C/C++ code references UIKit types directly.

#### 2a. Platform View Types (Obj-C)

Define a set of platform-agnostic type aliases that each platform provides:

```objc
// React/Base/RCTPlatformTypes.h (in core)
// This file is auto-generated or conditionally included per platform

#if TARGET_OS_OSX
  #import <AppKit/AppKit.h>
  typedef NSView RCTPlatformView;
  typedef NSColor RCTPlatformColor;
  typedef NSImage RCTPlatformImage;
  typedef NSFont RCTPlatformFont;
  typedef NSWindow RCTPlatformWindow;
  typedef NSViewController RCTPlatformViewController;
  typedef NSEvent RCTPlatformEvent;
  typedef NSScrollView RCTPlatformScrollView;
  // ... etc
#elif TARGET_OS_IOS || TARGET_OS_TV
  #import <UIKit/UIKit.h>
  typedef UIView RCTPlatformView;
  typedef UIColor RCTPlatformColor;
  typedef UIImage RCTPlatformImage;
  typedef UIFont RCTPlatformFont;
  typedef UIWindow RCTPlatformWindow;
  typedef UIViewController RCTPlatformViewController;
  typedef UIEvent RCTPlatformEvent;
  typedef UIScrollView RCTPlatformScrollView;
#endif
```

All shared code uses `RCTPlatformView`, `RCTPlatformColor`, etc. instead of UIKit types directly. This is essentially what Microsoft's `RCTUIKit.h` shim does — but it should be a first-class part of core, not a patch.

**Impact: Eliminates 166 patches (67% of our macOS patch set).**

#### 2b. Platform View Types (C++ / Fabric)

The Fabric renderer already has a partial `HostPlatformView` concept. This should be formalized:

```cpp
// react/renderer/components/view/platform/HostPlatformViewTraits.h

struct HostPlatformViewTraits {
  // Each platform provides these
  using NativeViewType = /* platform-specific */;
  using NativeColorType = /* platform-specific */;
  using NativeFontType = /* platform-specific */;

  // Platform-specific touch/event types
  using TouchType = HostPlatformTouch;
  using KeyEventType = HostPlatformKeyEvent;    // desktop platforms
  using MouseEventType = HostPlatformMouseEvent; // desktop platforms
};
```

Platforms provide their implementations in a `platform/<name>/` directory that the build system selects at compile time:

```
react/renderer/components/view/
  platform/
    ios/
      HostPlatformViewTraits.h
      HostPlatformTouch.h
    android/
      HostPlatformViewTraits.h
      HostPlatformTouch.h
    macos/          <-- OOT platform provides this
      HostPlatformViewTraits.h
      HostPlatformTouch.h
      HostPlatformKeyEvent.h
      HostPlatformMouseEvent.h
```

### 3. Component Prop Extension Registry

Platforms need to add props to core components without modifying their source. Today, adding `tooltip` to `<View>` requires patching View's prop types, ViewConfig, and native implementation.

```javascript
// Platform package registers additional props
PlatformRegistry.extendComponent('View', {
  props: {
    tooltip: { type: 'string' },
    cursor: { type: 'enum', values: ['auto', 'pointer', 'default', ...] },
    focusRing: { type: 'boolean' },
    enableFocusRing: { type: 'boolean' },
    draggedTypes: { type: 'array', items: 'string' },
    validKeysDown: { type: 'array', items: 'object' },
    validKeysUp: { type: 'array', items: 'object' },
  },
  events: {
    onMouseEnter: { bubbles: false },
    onMouseLeave: { bubbles: false },
    onDragEnter: { bubbles: false },
    onDragLeave: { bubbles: false },
    onDrop: { bubbles: false },
    onKeyDown: { bubbles: false },
    onKeyUp: { bubbles: false },
  },
});
```

The core `ViewConfig` merging system picks these up automatically:

```javascript
// In core: ViewConfig generation merges platform extensions
function getViewConfig(componentName) {
  const base = BaseViewConfigs[componentName];
  const platformExtensions = PlatformRegistry.getComponentExtensions(componentName);
  return mergeViewConfigs(base, platformExtensions);
}
```

**Impact: Eliminates the need to patch View.js, ViewPropTypes, ViewAccessibility, TextInput, ScrollView, and all component definition files.**

### 4. Native Module Platform Override

Platforms need to provide alternative implementations of core native modules. Today this requires patching the module source or using runtime hacks.

```javascript
// Platform package overrides a core module
PlatformRegistry.overrideModule('Alert', () => require('./modules/MacOSAlert'));
PlatformRegistry.overrideModule('StatusBar', () => null); // not available on macOS
PlatformRegistry.overrideModule('Linking', () => require('./modules/MacOSLinking'));
```

For native modules, this maps to the TurboModule registry:

```objc
// Platform provides alternative native module implementations
@interface MacOSAlertManager : RCTBaseAlertManager
// macOS-specific alert implementation using NSAlert
@end

// Registered via the platform's TurboModule provider
- (std::shared_ptr<TurboModule>)getTurboModule:(const std::string &)name {
  if (name == "Alert") return std::make_shared<MacOSAlertModule>();
  return nullptr; // fall through to core
}
```

### 5. Platform File Resolution

Metro already supports platform extensions (`.ios.js`, `.android.js`). The missing piece is making OOT platform extensions discoverable without patching Metro's config.

```javascript
// metro.config.js - this should be automatic when a platform package is installed
const { getDefaultConfig } = require('@react-native/metro-config');
const config = getDefaultConfig(__dirname);

// This should happen automatically via PlatformRegistry
// config.resolver.platforms = ['ios', 'android', 'macos'];
// Instead, platform packages auto-register:
config.resolver.platforms = PlatformRegistry.getAllPlatforms();
```

### 6. Build System Plugin API

#### CocoaPods

```ruby
# Podfile
use_react_native!()

# Platform packages register their pods automatically
# No need for platform-specific pod helpers
use_react_native_platform!('macos', :path => '../node_modules/react-native-macos-official')
```

The platform package's podspec declares:

```ruby
Pod::Spec.new do |s|
  s.name = 'ReactNativeMacOS'

  # Tells the RN build system to:
  # 1. Include platform/<macos>/ directories in header search paths
  # 2. Link platform-specific subspecs
  # 3. Apply platform preprocessor definitions
  s.react_native_platform = 'macos'

  s.dependency 'React-Core'
  # etc.
end
```

#### Gradle (for reference)

```groovy
// Android equivalent - already partially exists
reactNativePlatform {
    name = "tv"
    nativeModules = [TVNativeModules]
}
```

### 7. Conditional Compilation Convention

Instead of each platform adding its own `#if TARGET_OS_*` guards, core code uses a macro that the build system defines:

```objc
// Core code uses RCT_PLATFORM_SUPPORTS()
#if RCT_PLATFORM_SUPPORTS(HAPTICS)
  [generator triggerHaptic];
#endif

#if RCT_PLATFORM_SUPPORTS(STATUS_BAR)
  [statusBar setHidden:YES];
#endif
```

Each platform's build configuration defines which capabilities it supports:

```ruby
# In the platform's podspec
s.pod_target_xcconfig = {
  'GCC_PREPROCESSOR_DEFINITIONS' => [
    'RCT_PLATFORM_MACOS=1',
    'RCT_SUPPORTS_KEYBOARD=1',
    'RCT_SUPPORTS_MOUSE=1',
    'RCT_SUPPORTS_TOOLTIP=1',
    'RCT_SUPPORTS_CURSOR=1',
    'RCT_SUPPORTS_MULTIPLE_WINDOWS=1',
  ]
}
```

## Migration Path

This proposal is designed for incremental adoption. The migration order:

### Phase 1: Native Type Abstraction (Highest Impact)

1. Introduce `RCTPlatformTypes.h` with typedef aliases for UIKit types
2. Mechanically replace all `UIView` → `RCTPlatformView`, `UIColor` → `RCTPlatformColor`, etc. in shared headers
3. iOS continues to work identically (the typedefs resolve to UIKit types)
4. macOS, VisionOS, TV platforms can now compile shared code without patching

**Eliminates ~67% of OOT platform patches.**

This is a mechanical refactor. It changes no behavior on iOS or Android. It can be done file-by-file with automated codemods.

### Phase 2: Platform Capability Queries

1. Introduce `PlatformCapabilities` registry
2. Replace `Platform.OS === 'ios'` checks with capability queries
3. Replace `#if TARGET_OS_*` guards with `RCT_PLATFORM_SUPPORTS()` macros

**Eliminates ~27% of OOT platform patches** (Platform.OS checks + conditional compilation).

### Phase 3: Component Extension Registry

1. Introduce `PlatformRegistry.extendComponent()` API
2. Refactor ViewConfig generation to merge platform extensions
3. Move platform-specific props out of core component definitions

**Eliminates ~3% of patches and enables platforms to add features without touching core.**

### Phase 4: Build System Integration

1. Standardize `react_native_platform` in podspecs
2. Auto-discover platform packages from node_modules
3. Auto-register platform file extensions with Metro

**Eliminates manual configuration and build system patches.**

### Phase 5: Module Override System

1. Formalize `PlatformRegistry.overrideModule()`
2. Integrate with TurboModule registry for native overrides
3. Support platform-specific implementations of core modules

**Enables clean module replacement without source patching.**

## Impact Assessment

If all phases are implemented:

| Current Patch Category | Patches Today | Patches After | Reduction |
|---|---|---|---|
| UIKit/AppKit type abstraction | 166 | 0 | 100% |
| Import header changes | 129 | 0 | 100% |
| Conditional compilation | 55 | 0 | 100% |
| Platform.OS checks | 12 | 0 | 100% |
| View prop extensions | 7 | 0 | 100% |
| Type definitions | 4 | 0 | 100% |
| Build configuration | 2 | 0 | 100% |
| Other | 36 | ~10 | ~72% |
| **Total** | **248** | **~10** | **~96%** |

The remaining ~10 patches would cover truly platform-specific behavior that can't be abstracted (e.g., NSAlert vs UIAlertController implementation differences). These would be handled by the module override system but may still need small patches during the transition.

## Prior Art

- **React DOM / React Native split**: React already separates the reconciler from the renderer. This proposal extends that separation to within React Native itself.
- **react-native-windows**: Microsoft's OOT platform maintains >1000 override files. Their `react-native-platform-override` tool tracks divergence. This RFC would make that tool unnecessary.
- **Flutter**: Has a clean platform channel API and platform-specific embedding layers. Each platform implements a well-defined shell interface.
- **Electron**: Chromium's platform abstraction layer (`ui/gfx`, `ui/views`) enables macOS/Windows/Linux from shared code with platform implementations behind interfaces.

## Open Questions

1. **Backward compatibility**: How long do we maintain the current `Platform.OS` checks alongside the new capability system? Proposed: deprecate in the release that introduces capabilities, remove after 2 major versions.

2. **Codegen integration**: React Native's Codegen generates platform-specific code from JS specs. How do OOT platforms hook into this? They likely need to provide their own codegen templates.

3. **Fabric renderer**: The C++ Fabric renderer has deeper platform coupling than the JS layer. The `HostPlatformView` abstraction needs careful design to not sacrifice performance.

4. **Testing**: How do we test core React Native against platforms that aren't present? Proposed: mock platform providers for testing, plus CI that runs against reference OOT platforms.

5. **Community platforms**: Should the React Foundation maintain reference OOT implementations (macOS, Windows) to ensure the Platform Provider API stays honest? Proposed: Yes, at least macOS and Windows should be maintained by the Foundation as first-class OOT platforms.

## Conclusion

React Native's current architecture treats iOS and Android as hardcoded special cases, forcing every other platform into unsustainable forks. By introducing a formal Platform Provider API — starting with the high-impact native type abstraction — we can make React Native truly platform-agnostic while maintaining full backward compatibility for existing iOS and Android apps.

The data from our macOS OOT prototype shows that **96% of platform patches would be eliminated** by this API, reducing the macOS integration surface from 248 patched files to approximately 10.

This is not a theoretical proposal. We have built the OOT macOS platform, measured exactly where the abstraction leaks, and designed each component of this API to close those specific gaps. Phase 1 alone (native type abstraction) is a mechanical refactor that eliminates two-thirds of the problem.
