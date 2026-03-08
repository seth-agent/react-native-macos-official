# RFC 0002: Platform Provider API — Implementation Plan

This document is the execution plan for RFC 0001. It specifies phases,
workstreams within each phase, exact gates between phases, and which work
can run in parallel.

## Ground Rules

1. **Zero breaking changes.** Every commit must pass the full iOS and Android
   test suites. Existing user code compiles without modification. No new
   required imports, no renamed public APIs, no changed prop signatures.
   If a public symbol is deprecated, the old symbol remains and works for
   at least 2 major SDK versions (covering the "2-3 SDKs back" commitment).

2. **Additive only.** New abstractions are introduced alongside existing code.
   Old code paths are preserved behind typedefs, re-exports, or thin shims
   until the deprecation window closes.

3. **Commit early, commit often.** Each workstream below produces multiple
   small, reviewable commits. Squash before merge to main, but keep the
   granular history on the working branch so progress is visible.

4. **Test at every commit.** Every commit must:
   - Compile for iOS (arm64, x86_64 simulator)
   - Pass the existing Jest test suite (276+ suites, 5598+ tests)
   - Pass the existing native unit tests
   - Introduce no new compiler warnings in the changed files

5. **Backward-compat SDK support.** We test against current SDK and the two
   prior SDK versions. Any new API must have a fallback path for older SDKs.

---

## Phase 1: Native Type Abstraction

**Goal:** Introduce platform-agnostic type aliases for UIKit types in all
shared Obj-C/C++ code. iOS resolves them to UIKit. macOS resolves them to
AppKit. No behavior change on any existing platform.

**Impact:** Eliminates 134 import-header patches (54%) and 99 UIKit-type
patches (39%). Combined (with overlap): ~166 unique patches eliminated (67%).

**Duration estimate:** This is a mechanical refactor. Large in scope but
low in risk.

### Workstream 1A: RCTPlatformTypes.h (Foundation)

Create the core header that all shared code will import.

```
React/Base/RCTPlatformTypes.h
```

Contents:

```objc
#pragma once

#if TARGET_OS_OSX
  #import <AppKit/AppKit.h>
  typedef NSView       RCTPlatformView;
  typedef NSColor      RCTPlatformColor;
  typedef NSImage      RCTPlatformImage;
  typedef NSFont       RCTPlatformFont;
  typedef NSWindow     RCTPlatformWindow;
  typedef NSViewController RCTPlatformViewController;
  typedef NSEvent      RCTPlatformEvent;
  typedef NSScrollView RCTPlatformScrollView;
  typedef NSTextView   RCTPlatformTextView;
  typedef NSTextField  RCTPlatformTextField;
  typedef NSBezierPath RCTPlatformBezierPath;
  typedef NSEdgeInsets RCTPlatformEdgeInsets;
  typedef NSResponder  RCTPlatformResponder;
  typedef NSApplication RCTPlatformApplication;
  typedef NSCursor     RCTPlatformCursor;
  typedef NSGestureRecognizer RCTPlatformGestureRecognizer;
  typedef NSPanGestureRecognizer RCTPlatformPanGestureRecognizer;
#else
  #import <UIKit/UIKit.h>
  typedef UIView       RCTPlatformView;
  typedef UIColor      RCTPlatformColor;
  typedef UIImage      RCTPlatformImage;
  typedef UIFont       RCTPlatformFont;
  typedef UIWindow     RCTPlatformWindow;
  typedef UIViewController RCTPlatformViewController;
  typedef UIEvent      RCTPlatformEvent;
  typedef UIScrollView RCTPlatformScrollView;
  typedef UITextView   RCTPlatformTextView;
  typedef UITextField  RCTPlatformTextField;
  typedef UIBezierPath RCTPlatformBezierPath;
  typedef UIEdgeInsets RCTPlatformEdgeInsets;
  typedef UIResponder  RCTPlatformResponder;
  typedef UIApplication RCTPlatformApplication;
  // No direct cursor equivalent on iOS; define as void* or a stub
  typedef id           RCTPlatformCursor;
  typedef UIGestureRecognizer RCTPlatformGestureRecognizer;
  typedef UIPanGestureRecognizer RCTPlatformPanGestureRecognizer;
#endif
```

On iOS, `RCTPlatformView` is literally `UIView`. No indirection, no
virtual dispatch, no performance cost. It is a C typedef — the compiler
resolves it at compile time.

**Backward compatibility:** Any file that currently uses `UIView` directly
continues to compile. The typedef is additive. No existing code is modified
in this workstream.

**Gate:** This header must compile cleanly on iOS arm64 and x86_64 simulator
before any dependent workstreams begin. One commit. One PR.

### Workstream 1B: Umbrella Header (RCTPlatform.h)

Create an umbrella import that replaces `#import <UIKit/UIKit.h>` in shared
headers:

```objc
// React/Base/RCTPlatform.h
#pragma once
#import <React/RCTPlatformTypes.h>

// Additional platform-agnostic utilities can go here later.
// For now, this is just the single canonical import for platform types.
```

**Gate:** Compiles on iOS. One commit.

### Workstream 1C: Mechanical Type Replacement (Parallelizable)

This is the bulk of the work. Replace UIKit type references with
RCTPlatformType aliases in shared headers and implementation files.

This workstream is split into independent sub-workstreams by directory.
Each can be done in parallel by different contributors (or agents):

| Sub-workstream | Directory | Files affected | Can start after |
|---|---|---|---|
| 1C-i | React/Fabric/ | ~60 | 1A gate |
| 1C-ii | React/Views/ | ~28 | 1A gate |
| 1C-iii | React/Base/ | ~28 | 1A gate |
| 1C-iv | ReactCommon/react/ | ~24 | 1A gate |
| 1C-v | Libraries/Text/ | ~20 | 1A gate |
| 1C-vi | Libraries/Image/ | ~18 | 1A gate |
| 1C-vii | React/CoreModules/ | ~10 | 1A gate |
| 1C-viii | React/Modules/ | ~8 | 1A gate |
| 1C-ix | Libraries/NativeAnimation/ | ~8 | 1A gate |
| 1C-x | Libraries/Components/ | ~9 | 1A gate |
| 1C-xi | Libraries/Lists/ | ~9 | 1A gate |
| 1C-xii | Remaining (6 dirs, <5 files each) | ~16 | 1A gate |

**Rules for each sub-workstream:**

1. Add `#import <React/RCTPlatform.h>` where needed (replacing bare
   `#import <UIKit/UIKit.h>` only in shared headers — platform-specific
   files keep their direct imports).
2. Replace `UIView *` with `RCTPlatformView *`, etc. Only in files that
   are shared between platforms (i.e., not in `platform/ios/` directories).
3. Do NOT touch files inside `platform/ios/` or `platform/android/`
   directories. Those are platform-specific by definition.
4. Each sub-workstream produces one commit per logical unit (e.g., one
   commit per file or per small group of related files).
5. Each commit must compile on iOS and pass tests.

**What NOT to change (backward compat):**

- Public headers that app developers import directly keep their existing
  types. If `RCTView.h` currently exposes `UIView`, it continues to expose
  `UIView` in its public API. Internally, the implementation uses
  `RCTPlatformView`, but the public-facing typedef is preserved:

  ```objc
  // In public header — unchanged
  @interface RCTView : UIView  // stays UIView for source compat
  ```

  The key insight: `RCTPlatformView` IS `UIView` on iOS (it's a typedef),
  so this is not a lie — it's just that we don't force users to update
  their source code that references `UIView` in subclasses.

- If a user has code like `UIView *myView = rctView;` it continues to
  compile because `RCTPlatformView` is `UIView`.

**Gate for Phase 1 completion:**
- ALL sub-workstreams merged
- Full iOS build succeeds (arm64 + simulator)
- Full Jest test suite passes (276+ suites)
- Full native test suite passes
- No new compiler warnings
- Spot-check: a macOS OOT platform can compile React/Base and React/Views
  without any UIKit-related patches (validated against our 248-patch set)

### Workstream 1D: C++ / Fabric Type Traits (Parallel with 1C)

Formalize the `HostPlatformViewTraits` in the Fabric C++ renderer:

```
react/renderer/components/view/platform/HostPlatformViewTraits.h
```

This file already partially exists. The work is:
1. Audit every platform-specific type in the C++ Fabric code
2. Add missing types to the traits struct
3. Create a `platform/macos/` directory structure that OOT platforms can
   populate (empty for now — just the directory and a README)

**Gate:** Fabric compiles on iOS. No behavior change.

---

## Phase 1 -> Phase 2 Gate

Phase 2 may NOT begin until:

- [ ] All Phase 1 workstreams are merged to the working branch
- [ ] iOS arm64 build: PASS
- [ ] iOS simulator build: PASS
- [ ] Jest test suite: 276+ suites, 5598+ tests passing
- [ ] Native test suite: PASS
- [ ] No new compiler warnings in changed files
- [ ] Verification: at least 50% of our macOS UIKit-type patches are now
      unnecessary (measured by attempting to apply them — they should fail
      because the code they patch no longer exists in its original form)

---

## Phase 2: Platform Capability System

**Goal:** Replace `Platform.OS === 'ios'` checks and `#if TARGET_OS_*`
guards with capability queries. No behavior change for any existing
platform.

**Impact:** Eliminates 55 conditional-compilation patches (22%) and 12
Platform.OS patches (5%).

### Workstream 2A: JS Capability Registry

Introduce `Platform.capabilities` in JavaScript:

```javascript
// Libraries/Utilities/Platform.js (additive — new property)
const Platform = {
  OS: 'ios',         // unchanged, not deprecated yet
  Version: ...,      // unchanged
  capabilities: {    // NEW — additive
    statusBar: true,
    haptics: true,
    keyboard: false,  // physical keyboard — false for phones
    mouse: false,
    menuBar: false,
    multipleWindows: false,
    tooltip: false,
    cursor: false,
    focusRing: false,
    dragAndDrop: false,
    nativeEventEmitters: true,
    pushNotifications: true,
  },
};
```

**Backward compatibility:** `Platform.OS` continues to work exactly as
before. `Platform.capabilities` is a new additive property. No existing
code breaks.

**Gate:** `Platform.capabilities` is accessible in JS. All existing
`Platform.OS` checks still work. Jest tests pass.

### Workstream 2B: Replace Platform.OS Checks in Core (Sequential)

For each of the 12 files that use `Platform.OS` checks:

1. Add a corresponding capability check alongside (not replacing) the
   existing `Platform.OS` check
2. The capability check is the primary path; the `Platform.OS` check
   becomes the fallback:

   ```javascript
   // BEFORE
   if (Platform.OS === 'ios') { ... }

   // AFTER (backward compatible — both paths produce same result on iOS)
   if (Platform.capabilities?.statusBar ?? Platform.OS === 'ios') { ... }
   ```

3. This dual-path approach means that:
   - Old code (pre-capabilities) still works via the `Platform.OS` fallback
   - New OOT platforms only need to set capabilities, not add their OS name
     to every conditional
   - After 2 major versions, the `Platform.OS` fallback can be removed

**Files to update (in order, each its own commit):**

1. Libraries/EventEmitter/NativeEventEmitter.js
2. Libraries/Components/Keyboard/Keyboard.js
3. Libraries/AppState/AppState.js
4. Libraries/WebSocket/WebSocket.js
5. Libraries/WebSocket/WebSocketInterceptor.js
6. Libraries/Utilities/HMRClient.js
7. Libraries/Utilities/DevSettings.js
8. Libraries/Linking/Linking.js
9. Libraries/PushNotificationIOS/PushNotificationIOS.js
10. Libraries/ReactNative/PaperUIManager.js
11. Libraries/NativeComponent/ViewConfigIgnore.js
12. Libraries/Network/__tests__/XMLHttpRequest-test.js

**Gate:** All 12 files updated. Jest tests pass. Behavior identical.

### Workstream 2C: Native Capability Macros (Parallel with 2B)

Introduce `RCT_PLATFORM_SUPPORTS()` macro for conditional compilation:

```objc
// React/Base/RCTPlatformCapabilities.h
#pragma once

// Default capabilities for iOS
#ifndef RCT_SUPPORTS_HAPTICS
  #if TARGET_OS_IOS
    #define RCT_SUPPORTS_HAPTICS 1
  #else
    #define RCT_SUPPORTS_HAPTICS 0
  #endif
#endif

#ifndef RCT_SUPPORTS_STATUS_BAR
  #if TARGET_OS_IOS
    #define RCT_SUPPORTS_STATUS_BAR 1
  #else
    #define RCT_SUPPORTS_STATUS_BAR 0
  #endif
#endif

#ifndef RCT_SUPPORTS_KEYBOARD
  #define RCT_SUPPORTS_KEYBOARD 0
#endif

#ifndef RCT_SUPPORTS_MOUSE
  #define RCT_SUPPORTS_MOUSE 0
#endif

// ... etc for each capability

// Convenience macro
#define RCT_PLATFORM_SUPPORTS(CAP) (RCT_SUPPORTS_##CAP)
```

OOT platforms override these via their podspec's preprocessor definitions.

**Backward compatibility:** On iOS, all macros resolve to their current
values. `TARGET_OS_IOS` checks continue to compile. The macros are additive.

### Workstream 2D: Replace #if TARGET_OS Guards (After 2C gate)

Replace `#if TARGET_OS_OSX` guards in the 55 affected native files with
`#if RCT_PLATFORM_SUPPORTS(...)` macros. Since there are currently no
`TARGET_OS_OSX` guards in upstream (they only exist in our patches), this
workstream focuses on:

1. Identifying the ~55 locations where our macOS patches ADD guards
2. Ensuring the `RCT_PLATFORM_SUPPORTS()` macro covers each case
3. Documenting which capabilities map to which guards

This workstream primarily benefits OOT platforms — upstream code doesn't
have these guards yet, so there's nothing to "replace." The value is that
when an OOT platform needs to add a guard, they use the macro system
instead of raw `TARGET_OS_*` checks.

**Gate:** Macro system compiles on iOS. No behavior change.

---

## Phase 2 -> Phase 3 Gate

- [ ] All Phase 2 workstreams merged
- [ ] iOS build: PASS
- [ ] Jest test suite: PASS
- [ ] Native test suite: PASS
- [ ] Verification: `Platform.capabilities` is accessible and correct on iOS
- [ ] Verification: all 12 Platform.OS patches are now unnecessary for macOS
      OOT (the capability fallback handles them)
- [ ] Verification: `RCT_PLATFORM_SUPPORTS()` macros compile and resolve
      correctly on iOS

---

## Phase 3: Component Extension Registry

**Goal:** Allow OOT platforms to add props and events to core components
without modifying core source files.

**Impact:** Eliminates 5 view-prop patches (2%) and establishes the
extension pattern for all future platform-specific props.

### Workstream 3A: ViewConfig Extension API

Add a registration mechanism for platform-specific props:

```javascript
// Libraries/NativeComponent/PlatformComponentExtensions.js (NEW file)

const extensions = {};

const PlatformComponentExtensions = {
  register(componentName, config) {
    if (!extensions[componentName]) {
      extensions[componentName] = { props: {}, events: {} };
    }
    Object.assign(extensions[componentName].props, config.props || {});
    Object.assign(extensions[componentName].events, config.events || {});
  },

  getExtensions(componentName) {
    return extensions[componentName] || { props: {}, events: {} };
  },
};

module.exports = PlatformComponentExtensions;
```

**Gate:** New file exists. No existing code calls it yet. Tests pass.

### Workstream 3B: Integrate Extensions into ViewConfig Generation

Modify the ViewConfig generation pipeline to merge platform extensions:

1. In `verifyComponentAttributeEquivalence.js` — allow platform-extended
   props to pass validation
2. In `StaticViewConfigValidator.js` — merge platform extensions before
   validation
3. In component registration — merge extensions at registration time

**Backward compatibility:** If no extensions are registered (the default
for iOS/Android), the behavior is identical to today. Extensions are purely
additive.

**Gate:** ViewConfig generation works with and without extensions. Tests pass.

### Workstream 3C: TypeScript Extension Types (Parallel with 3B)

Provide TypeScript support for platform-extended props:

```typescript
// types/PlatformExtensions.d.ts (NEW file)
declare module 'react-native' {
  interface ViewPropsExtensions {
    // OOT platforms augment this interface
  }

  interface TextPropsExtensions {
    // OOT platforms augment this interface
  }

  // ... etc
}
```

OOT platforms use TypeScript module augmentation:

```typescript
// In react-native-macos-official/types/index.d.ts
declare module 'react-native' {
  interface ViewPropsExtensions {
    tooltip?: string;
    cursor?: 'auto' | 'pointer' | 'default';
    focusRing?: boolean;
  }
}
```

**Backward compatibility:** Empty interfaces merge with nothing. No existing
types change.

---

## Phase 3 -> Phase 4 Gate

- [ ] All Phase 3 workstreams merged
- [ ] iOS build: PASS
- [ ] Jest test suite: PASS
- [ ] Verification: `PlatformComponentExtensions.register()` works and
      extensions appear in ViewConfig
- [ ] Verification: TypeScript augmentation compiles for a sample OOT config
- [ ] Verification: all 5 view-prop patches are now unnecessary for macOS
      OOT (props are registered via the extension API instead)

---

## Phase 4: Build System Integration

**Goal:** Make OOT platform packages auto-discoverable. No manual Metro or
CocoaPods configuration needed.

**Impact:** Eliminates 2 build-config patches and all manual setup steps.

### Workstream 4A: Platform Package Auto-Discovery

Add a `react-native.config.js` convention for platform packages:

```javascript
// In OOT package's react-native.config.js
module.exports = {
  platforms: {
    macos: {
      npmPackageName: 'react-native-macos-official',
      platformFileExtensions: ['macos'],
    },
  },
};
```

React Native's CLI and Metro already support this pattern partially. The
work is:

1. Ensure Metro auto-discovers platform extensions from installed packages
2. Ensure `react-native.config.js` `platforms` key is respected
3. Document the convention

**Gate:** A test OOT package with `react-native.config.js` is auto-discovered
by Metro without manual `metro.config.js` changes.

### Workstream 4B: CocoaPods Platform Plugin (Parallel with 4A)

Standardize how OOT platforms register their pods:

```ruby
# In OOT package's podspec
Pod::Spec.new do |s|
  s.name = 'ReactNativeMacOS'

  # Convention: platform/<name>/ directories are added to header search paths
  s.react_native_platform = {
    name: 'macos',
    platform_types_dir: 'platform/macos',
  }
end
```

Add a `use_react_native_platform!` helper to the CocoaPods integration:

```ruby
# In user's Podfile
use_react_native!()
use_react_native_platform!('macos',
  path: '../node_modules/react-native-macos-official')
```

**Gate:** Helper exists and produces correct pod configuration.

### Workstream 4C: Platform Directory Convention in Core

Create the directory structure in core that OOT platforms populate:

```
react/renderer/components/view/platform/
  ios/         (existing)
  android/     (existing)
  README.md    (NEW — documents the convention)
```

An OOT platform adds its directory (e.g., `platform/macos/`) containing
its `HostPlatformViewTraits.h` and other platform-specific headers. The
build system selects the correct directory based on the target platform.

**Gate:** Directory convention documented. iOS continues to use `platform/ios/`.

---

## Phase 4 -> Phase 5 Gate

- [ ] All Phase 4 workstreams merged
- [ ] iOS build: PASS
- [ ] Jest test suite: PASS
- [ ] Verification: an OOT platform package with `react-native.config.js`
      is auto-discovered by Metro
- [ ] Verification: `use_react_native_platform!` generates correct CocoaPods
      config
- [ ] Verification: both build-config patches are now unnecessary

---

## Phase 5: Module Override System

**Goal:** Allow OOT platforms to provide alternative implementations of core
native modules without patching.

**Impact:** Eliminates the remaining "other" category patches and provides
a clean extension mechanism for platform-specific module behavior.

### Workstream 5A: JS Module Override Registry

```javascript
// Libraries/Core/PlatformModuleOverrides.js (NEW file)

const overrides = {};

const PlatformModuleOverrides = {
  register(moduleName, factory) {
    overrides[moduleName] = factory;
  },

  resolve(moduleName, defaultModule) {
    if (overrides[moduleName]) {
      return overrides[moduleName]();
    }
    return defaultModule;
  },
};

module.exports = PlatformModuleOverrides;
```

### Workstream 5B: Integrate Overrides into Core Module Initialization

For modules that OOT platforms commonly need to replace (Alert, StatusBar,
Linking, Clipboard, etc.):

1. Wrap the module initialization with `PlatformModuleOverrides.resolve()`
2. Default behavior is unchanged — the override returns the original module
3. OOT platforms register their override during initialization

**Backward compatibility:** If no override is registered (default for
iOS/Android), the original module is used. Zero behavior change.

### Workstream 5C: TurboModule Override Hook (Parallel with 5B)

For native modules, add a hook in the TurboModule registry:

```objc
// React/Base/RCTPlatformModuleProvider.h (NEW file)

@protocol RCTPlatformModuleProvider <NSObject>
@optional
- (Class)moduleClassForName:(NSString *)name;
- (std::shared_ptr<facebook::react::TurboModule>)
    turboModuleForName:(const std::string &)name;
@end

// Registration
void RCTRegisterPlatformModuleProvider(id<RCTPlatformModuleProvider> provider);
```

The TurboModule registry checks the platform provider before falling back
to the default module implementation.

**Gate:** Override mechanism works. Default behavior unchanged.

---

## Phase 5 Completion Gate (Full Implementation)

- [ ] All Phase 5 workstreams merged
- [ ] iOS build: PASS (arm64 + simulator)
- [ ] Android build: PASS
- [ ] Jest test suite: PASS (276+ suites, 5598+ tests)
- [ ] Native test suite: PASS (iOS and Android)
- [ ] No new compiler warnings
- [ ] Verification: an OOT macOS platform using ALL five APIs (type aliases,
      capabilities, component extensions, auto-discovery, module overrides)
      requires <= 10 patches to core React Native (down from 248)
- [ ] Verification: `Platform.OS === 'ios'` still works everywhere
- [ ] Verification: all public headers are source-compatible with existing
      user code
- [ ] Verification: builds succeed against current SDK, SDK-1, and SDK-2

---

## Parallelization Summary

```
Timeline:
=========

Phase 1: ====================================================
  1A (types header)     [##]
  1B (umbrella header)  [#]
                            1C-i   (Fabric)       [##########]
                            1C-ii  (Views)        [######]
                            1C-iii (Base)         [######]
                            1C-iv  (ReactCommon)  [#####]
                            1C-v   (Text)         [####]
                            1C-vi  (Image)        [####]
                            1C-vii (CoreModules)  [##]
                            1C-viii(Modules)      [##]
                            1C-ix  (NativeAnim)   [##]
                            1C-x   (Components)   [##]
                            1C-xi  (Lists)        [##]
                            1C-xii (Remaining)    [###]
                            1D (C++ Fabric)       [######]
                                                       GATE 1
Phase 2: ====================================          |
  2A (JS capabilities)  [###]                          |
  2C (native macros)    [###]                          |
                            2B (Platform.OS)  [######] |
                            2D (TARGET_OS)    [####]   |
                                                  GATE 2
Phase 3: ==========================               |
  3A (extension API)     [##]                     |
  3C (TypeScript types)  [##]                     |
                            3B (ViewConfig)  [####]
                                              GATE 3
Phase 4: ==========================
  4A (Metro discovery)   [####]
  4B (CocoaPods plugin)  [####]
  4C (dir convention)    [#]
                          GATE 4
Phase 5: ==========================
  5A (JS overrides)      [##]
  5C (TurboModule hook)  [###]
                            5B (integrate)  [####]
                                             GATE 5 (DONE)
```

Key parallelization points:
- Phase 1C: ALL 12 sub-workstreams run in parallel (biggest win)
- Phase 1D: runs in parallel with all of 1C
- Phase 2A + 2C: run in parallel
- Phase 2B + 2D: run in parallel (after their respective dependencies)
- Phase 3A + 3C: run in parallel
- Phase 4A + 4B: run in parallel
- Phase 5A + 5C: run in parallel

Maximum parallelism: 13 concurrent workstreams (during Phase 1C + 1D).

---

## Tracking: Patch Elimination Progress

We track progress against our macOS OOT patch set (248 patches). After each
phase gate, we measure how many patches are now unnecessary:

| Gate | Expected patches eliminated | Remaining | Cumulative % |
|---|---|---|---|
| Phase 1 | ~166 (UIKit types + imports) | ~82 | 67% |
| Phase 2 | ~67 (conditionals + Platform.OS) | ~15 | 94% |
| Phase 3 | ~5 (view props) | ~10 | 96% |
| Phase 4 | ~2 (build config) | ~8 | 97% |
| Phase 5 | varies (module overrides) | ~5-10 | 96-98% |

The measurement is concrete: attempt to apply each remaining patch. If it
fails because the code it targeted has been abstracted, that patch is
"eliminated." If it still applies, we haven't covered that case yet.

---

## Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Performance regression from typedefs | Low — C typedefs are zero-cost | Benchmark before/after Phase 1 |
| Public API surface accidentally changed | High — breaks user code | CI check: dump all public symbols before/after, diff must be empty |
| OOT platform exposes bug in abstraction | Medium | macOS OOT is our canary — test against it at every gate |
| Codegen doesn't support extended props | Medium | Address in Phase 3; may need codegen plugin API (separate RFC) |
| Community resistance to Platform.capabilities | Low | Platform.OS still works; capabilities are additive |

---

## Appendix: Files by Workstream

### Phase 1C sub-workstream file lists

These are derived from our 248-patch analysis. Each list shows the upstream
files that need UIKit type replacement.

(Full file lists to be generated from patch analysis and committed as a
separate tracking document once work begins.)
