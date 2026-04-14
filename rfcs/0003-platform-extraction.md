# RFC 0003: React Native Platform Extraction

## Summary

Extract iOS and Android out of React Native core, making them peer platform packages (`react-native-ios`, `react-native-android`) on equal footing with any other platform. React Native core becomes a platform-agnostic runtime — the reconciler, layout engine, module infrastructure, and JS bridge — with no knowledge of any specific native UI framework.

This is the React model applied to React Native: React is the programming model, renderers are separate packages.

## Motivation

RFC 0001 proposed adding platform abstractions to React Native core so that OOT platforms could plug in without patching. That's the right direction, but the wrong framing. Adding abstractions still treats iOS as the host and everything else as a guest. The result is an iOS app framework with escape hatches, not a platform-agnostic runtime.

**The real problem:** iOS isn't a platform plugin. It's the host. React-Core IS UIKit. Every file, every import, every type assumes iOS. This isn't fixable with abstractions layered on top — the foundation is wrong.

**The proposal:** Invert it. Pull iOS out. Make React Native core genuinely platform-agnostic — no UIKit, no AppKit, no Android Views. Then iOS, Android, macOS, Windows, and any future platform sit on top as equal peers, implementing a well-defined platform contract.

### The React Precedent

React already did this. React is the reconciler. React DOM, React Native, React Three Fiber, Ink — these are all renderers. They're peers, not children. React has no knowledge of the DOM. React DOM has no knowledge of native views.

React Native didn't follow this pattern internally. It should.

### What This Enables

- **macOS, Windows, visionOS, tvOS, Linux** become first-class without forking
- **Microsoft stops maintaining a fork** of 2M+ lines — they maintain `react-native-windows` as a platform package
- **Meta's iOS team** owns `react-native-ios`, not "all of React Native with iOS baked in"
- **Platform bugs don't block core releases** — an iOS regression doesn't hold up Android or macOS
- **Community platforms** (embedded, terminal, VR) become possible without touching core
- **Core stays small and auditable** — easier to reason about, test, and maintain

## Architecture

### Current State

```
react-native/
├── React/                    ← ObjC, imports UIKit everywhere
│   ├── Base/                 ← UIView, UIApplication references
│   ├── Views/                ← UIKit view implementations  
│   ├── Modules/              ← UIKit-dependent modules
│   └── Fabric/               ← UIKit mounting layer
├── ReactCommon/              ← C++, mostly platform-agnostic
│   └── react/renderer/
│       └── components/
│           └── view/platform/ ← ios/, android/, cxx/ directories
├── ReactAndroid/             ← Java/Kotlin Android implementation
├── Libraries/                ← JS, mixed platform-specific code
└── scripts/                  ← Build tools, hardcoded to iOS+Android
```

iOS is not "supported by" React Native. iOS IS React Native's native layer. There is no boundary.

### Target State

```
react-native/                 ← Platform-agnostic core
├── ReactCore/                ← ObjC/Swift, NO UIKit/AppKit imports
│   ├── Bridge/               ← JSI, TurboModules infrastructure
│   ├── Events/               ← Abstract event dispatch
│   ├── Modules/              ← Module registry, abstract base classes
│   └── Platform/             ← Platform contract interfaces
│       ├── RNPlatformView.h          ← @protocol, not @class
│       ├── RNPlatformApplication.h
│       ├── RNPlatformDisplayLink.h
│       ├── RNPlatformTextMeasurer.h
│       └── RNPlatformImageLoader.h
├── ReactCommon/              ← C++, unchanged (already clean)
│   └── react/renderer/
│       └── components/
│           └── view/platform/ ← cxx/ only in core
├── Libraries/                ← JS, platform-agnostic
│   ├── Components/           ← Core component JS (no Platform.OS)
│   └── Platform/             ← PlatformRegistry, capability queries
└── scripts/                  ← Build tools, platform-parameterized

react-native-ios/             ← iOS platform package (extracted)
├── platform/ios/             ← C++ HostPlatform* implementations
├── UIKit/                    ← UIView, UIApplication integration
├── Modules/                  ← StatusBar, ActionSheet, Haptics, etc.
├── Fabric/                   ← UIKit mounting, component views
├── AppDelegate/              ← iOS app lifecycle
└── CocoaPods/                ← iOS build integration

react-native-android/         ← Android platform package (extracted)
├── platform/android/         ← C++ HostPlatform* implementations  
├── Views/                    ← Android View integration
├── Modules/                  ← Android-specific modules
├── Fabric/                   ← Android mounting, component views
└── Gradle/                   ← Android build integration

react-native-macos/           ← macOS platform package (new, not a fork)
├── platform/macos/           ← C++ HostPlatform* implementations
├── AppKit/                   ← NSView, NSApplication integration
├── Modules/                  ← macOS-specific modules
├── Fabric/                   ← AppKit mounting, component views
└── CocoaPods/                ← macOS build integration
```

### The Platform Contract

The core defines what a platform must provide. This is the API surface that makes platforms interchangeable.

```objc
// react-native/ReactCore/Platform/RNPlatformProvider.h

@protocol RNPlatformProvider <NSObject>

/// The platform identifier (e.g. "ios", "android", "macos")
@property (nonatomic, readonly) NSString *platformName;

/// Root view factory — creates the top-level native view for a React surface
- (id<RNPlatformView>)createRootViewWithBridge:(RCTBridge *)bridge
                                    moduleName:(NSString *)moduleName
                               initialProperties:(NSDictionary *)props;

/// Display link — provides vsync-aligned frame callbacks
- (id<RNPlatformDisplayLink>)createDisplayLink;

/// Text measurement — uses platform's font/text system
- (id<RNPlatformTextMeasurer>)createTextMeasurer;

/// Image loading — uses platform's image pipeline
- (id<RNPlatformImageLoader>)createImageLoader;

/// Platform-specific native modules
- (NSArray<id<RCTBridgeModule>> *)platformModules;

/// Capabilities this platform supports
- (RNPlatformCapabilities *)capabilities;

@end
```

```objc
// react-native/ReactCore/Platform/RNPlatformView.h

@protocol RNPlatformView <NSObject>

// The actual native view (UIView on iOS, NSView on macOS)
@property (nonatomic, readonly) id nativeView;

// Layout
- (void)setFrame:(CGRect)frame;
- (void)insertSubview:(id<RNPlatformView>)view atIndex:(NSInteger)index;
- (void)removeFromSuperview;

// Appearance
- (void)setBackgroundColor:(id)color;  // Platform-specific color type
- (void)setOpacity:(CGFloat)opacity;
- (void)setClipsToBounds:(BOOL)clips;
- (void)setTransform:(CGAffineTransform)transform;

// Events
- (void)setEventHandlers:(NSDictionary<NSString *, id> *)handlers;

@end
```

```cpp
// react-native/ReactCommon/react/renderer/platform/PlatformComponentDescriptor.h

// C++ equivalent — the Fabric-level platform contract
class PlatformComponentDescriptorProvider {
 public:
  virtual ~PlatformComponentDescriptorProvider() = default;
  
  // Each platform provides component descriptors for its native views
  virtual ComponentDescriptorRegistry::Shared createComponentDescriptorRegistry(
      ComponentDescriptorParameters const &parameters) const = 0;
      
  // Platform-specific touch/event handling
  virtual std::unique_ptr<EventDispatcher> createEventDispatcher() const = 0;
  
  // Platform-specific text measurement
  virtual std::unique_ptr<TextLayoutManager> createTextLayoutManager() const = 0;
};
```

### C++ Platform Directories

The existing `platform/` directory convention in ReactCommon is already correct. The extraction formalizes it:

**Core provides `platform/cxx/`** — default/fallback C++ implementations. These compile on any platform and provide baseline behavior.

**Each platform package provides `platform/<name>/`** — platform-optimized implementations. The build system selects the right directory.

```
// Core (react-native)
ReactCommon/react/renderer/components/view/platform/
  cxx/
    HostPlatformTouch.h       ← Base touch with minimal fields
    HostPlatformViewProps.h   ← Base view props
    HostPlatformViewEventEmitter.h

// iOS package (react-native-ios)  
platform/ios/
    HostPlatformTouch.h       ← Adds force touch, 3D touch fields
    HostPlatformViewProps.h   ← Adds iOS-specific props
    HostPlatformViewEventEmitter.h

// macOS package (react-native-macos)
platform/macos/
    HostPlatformTouch.h       ← Adds button, modifier keys
    HostPlatformViewProps.h   ← Adds tooltip, cursor, focusRing
    HostPlatformViewEventEmitter.h ← Adds key events, mouse events
    HostPlatformKeyEvent.h
    HostPlatformMouseEvent.h
```

### JS Platform Registry

```javascript
// react-native/Libraries/Platform/PlatformRegistry.js

class PlatformRegistry {
  static register(name, provider) { ... }
  
  static capabilities = {};  // Populated by active platform
  
  // Replaces Platform.OS checks
  static supports(capability) {
    return this.capabilities[capability] === true;
  }
  
  // Component extension
  static extendComponent(name, extensions) { ... }
  
  // Module override
  static overrideModule(name, factory) { ... }
  
  // Build-time: Metro platform resolution
  static getPlatformExtensions() { ... }
}
```

```javascript
// react-native-ios/index.js
import { PlatformRegistry } from 'react-native';

PlatformRegistry.register('ios', {
  capabilities: {
    statusBar: true,
    haptics: true,
    keyboard: false,  // software keyboard, managed by system
    mouse: false,
    menuBar: false,
    tooltip: false,
    forceTouch: true,
  },
  modules: require('./modules'),
  componentExtensions: {},  // iOS is the baseline, no extensions needed
});
```

```javascript
// react-native-macos/index.js
import { PlatformRegistry } from 'react-native';

PlatformRegistry.register('macos', {
  capabilities: {
    statusBar: false,
    haptics: false,
    keyboard: true,   // physical keyboard, always present
    mouse: true,
    menuBar: true,
    tooltip: true,
    forceTouch: true,  // trackpad
  },
  modules: require('./modules'),
  componentExtensions: {
    View: {
      props: { tooltip: 'string', cursor: 'string', enableFocusRing: 'boolean' },
      events: { onMouseEnter: {}, onMouseLeave: {}, onKeyDown: {}, onKeyUp: {} },
    },
  },
});
```

## Extraction Strategy

This must be incremental. You can't extract iOS from React Native in one release. The strategy: **extract from the edges inward**, proving the pattern at each step before going deeper.

### Wave 1: Platform Modules (4-6 weeks)

**Extract iOS-specific native modules into react-native-ios.**

These modules have clean boundaries — they're self-contained, have clear specs, and don't deeply entangle with the view system.

Candidates for first extraction:
- `RCTStatusBarManager` — macOS has no status bar. No-op on macOS, extract iOS impl.
- `RCTVibration` / `RCTHaptics` — iOS-only hardware.
- `RCTActionSheet` — UIAlertController on iOS, NSAlert on macOS.
- `RCTClipboard` — UIPasteboard vs NSPasteboard.
- `RCTAppearance` — Minor differences, mostly works cross-platform.

Core keeps the module specs (TurboModule interfaces). Platform packages provide implementations.

**Validation:** After this wave, an OOT platform can provide its own StatusBar (no-op), Clipboard (NSPasteboard), etc. without patching core.

### Wave 2: Platform Types (6-8 weeks)

**Introduce `RNPlatformTypes.h` and migrate shared ObjC code.**

This is the mechanical big bang: replace `UIView` → `RNPlatformView` across all shared headers. On iOS, `RNPlatformView` is `UIView`. On macOS, it's `NSView`. Zero behavior change.

This is RFC 0001 Phase 1, but framed as extraction rather than abstraction. The types aren't abstractions being added — they're the seam being created so iOS can be pulled out.

Use codemods. This is ~400 files but the changes are mechanical:
```
s/UIView/RNPlatformView/g
s/UIColor/RNPlatformColor/g  
s/UIImage/RNPlatformImage/g
s/#import <UIKit\/UIKit.h>/#import <ReactCore\/RNPlatformTypes.h>/g
```

**Validation:** After this wave, shared code compiles for macOS without patches to type references.

### Wave 3: View System Extraction (8-12 weeks)

**Extract iOS view management into react-native-ios.**

This is the hard one. The Fabric mounting layer, component views (`RCTViewComponentView`, `RCTTextComponentView`, etc.), and the shadow tree → native view bridge are deeply iOS-specific.

The extraction creates `RNPlatformComponentViewFactory` — a protocol that each platform implements to create native views from shadow nodes.

Core owns: shadow tree, layout (Yoga), diffing, event routing.
Platform owns: native view creation, native view updates, mounting.

### Wave 4: Build System (4-6 weeks)

**Extract iOS build integration into react-native-ios.**

CocoaPods helpers, Xcode project generation, codegen templates — all move to the platform package. Core provides build primitives that platforms compose.

### Wave 5: App Shell (2-4 weeks)

**Extract AppDelegate, app lifecycle, and entry point into react-native-ios.**

`RCTAppDelegate` becomes `RNIOSAppDelegate` in the iOS package. Core provides `RNAppDelegate` — a protocol, not a class.

## Compatibility

### For existing iOS/Android developers

Nothing changes in the first releases. `react-native` continues to include iOS and Android support. The extraction happens in stages:

1. **Phase A:** `react-native` depends on `react-native-ios` and `react-native-android` as internal packages. Same npm install, same API. Users don't notice.
2. **Phase B:** `react-native-ios` and `react-native-android` become explicit peer dependencies. CLI templates include them. Migration is `yarn add react-native-ios`.
3. **Phase C:** `react-native` no longer includes platform code. Clean separation.

### For existing native modules

TurboModule specs don't change. Native module implementations that use UIKit continue working — they just live in the iOS platform package's dependency graph instead of core's.

### Import paths

```javascript
// These continue to work forever
import { View, Text, Platform } from 'react-native';

// Platform-specific imports (new)
import { StatusBar } from 'react-native-ios';  // iOS-only module
import { MenuBar } from 'react-native-macos';  // macOS-only module
```

## Success Criteria

The extraction is complete when:

1. `react-native` core compiles with NO platform SDK (no UIKit, no Android SDK)
2. `react-native-ios` compiles and runs existing RN apps with zero regressions
3. `react-native-macos` compiles and runs without ANY patches to core
4. A new platform can be bootstrapped from a template in under a week
5. Core releases don't require coordinated platform releases (platforms pin to core versions)

## Timeline

| Wave | Scope | Duration | Cumulative |
|------|-------|----------|------------|
| 1 | Platform Modules | 4-6 weeks | 4-6 weeks |
| 2 | Platform Types | 6-8 weeks | 10-14 weeks |
| 3 | View System | 8-12 weeks | 18-26 weeks |
| 4 | Build System | 4-6 weeks | 22-32 weeks |
| 5 | App Shell | 2-4 weeks | 24-36 weeks |

**6-9 months** for full extraction with a small dedicated team. Each wave delivers standalone value — the project is useful after Wave 1.

## Relationship to RFC 0001 and RFC 0002

RFC 0001 proposed the Platform Provider API. This RFC subsumes it: the Platform Provider API is the contract that enables extraction. The abstractions in RFC 0001 are the seams along which we cut.

RFC 0002 proposed a phased implementation plan for the macOS OOT platform. Under this RFC, the macOS platform becomes the **reference OOT implementation** that validates each extraction wave. As core extracts iOS, macOS should work with fewer patches at each step, reaching zero patches when extraction is complete.

## Open Questions

1. **Who owns react-native-ios?** Meta? The React Foundation? A community working group? The answer affects velocity and governance.

2. **Monorepo or multirepo?** Should react-native-ios live in the react-native monorepo (easier to coordinate) or a separate repo (cleaner separation)? Recommendation: monorepo during extraction, separate repo after Wave 5.

3. **Android first or iOS first?** Android's native layer is already more modular (Java packages with clear boundaries). It might be easier to extract first as a proof of concept. Counter-argument: iOS is where the pain is for OOT Apple platforms (macOS, visionOS, tvOS).

4. **Versioning:** Do platform packages version-lock to core? Or can they evolve independently? Recommendation: version-lock during extraction, independent after stabilization.
