# Roadmap: react-native-macos-official

## Completed

### Platform Provider API (All 5 Phases)
- [x] Phase 1: RCTPlatformTypes.h type aliases (@compatibility_alias)
- [x] Phase 2: RCTPlatformCapabilities.h capability-based checks
- [x] Phase 3: PlatformModuleOverrides registry (JS module replacement)
- [x] Phase 4A: Metro auto-discovery (platform-discovery.js)
- [x] Phase 4B: CocoaPods platform plugin (use_react_native_platform!)
- [x] Phase 5B: Module override wiring in index.js (10 modules)

### Patch System
- [x] 248 patches generated from 3-way merge (upstream 0.84.1 + MS fork)
- [x] All patches apply cleanly against vanilla RN 0.84.1
- [x] Postinstall script automates patch application
- [x] Zero test regressions (5598/5600 tests pass)

### Test App (MacOSTestApp)
- [x] Project scaffolded with correct structure
- [x] Pod install succeeds (74 pods)
- [ ] Native macOS build validation

## In Progress

### Native Build Validation
- Pod install works, native compile not yet tested
- Requires full Xcode installation (not just CLT)
- AppDelegate, main.m, storyboard from template need validation

## Remaining Work

### Layer 1: Platform Shell (2-3 weeks)
The most critical and novel work. Requires macOS-native implementations of:
- AppDelegate lifecycle (NSApplicationDelegate vs UIApplicationDelegate)
- RootView / content view management (NSView hierarchy)
- Window management (NSWindow vs UIWindow)
- Event handling (NSEvent vs UIEvent, responder chain differences)
- Menu bar integration (NSMenu)

### Layer 2: ReactCommon Platform Directories (2-3 weeks)
Eight directories in ReactCommon need macOS platform variants:
- TextLayout (hardest - NSTextStorage/NSLayoutManager differs significantly)
- TextInput (NSTextField/NSTextView vs UITextField/UITextView)
- React-graphics, React-ImageManager, textlayoutmanager pods
- These pods can't see React-Core headers, so they use UIKit directly

Text rendering and text input are the critical path. Microsoft's fork has
thousands of lines for this. The AppKit text system
(NSTextStorage/NSLayoutManager/NSTextContainer) behaves differently from
UIKit's even though some classes share names.

### Layer 3: Core Module Adaptations (1 week)
Several CoreModules are iOS-specific:
- RCTStatusBarManager: macOS has no status bar. Needs no-op. (~31 references)
- RCTAlertController: NSAlert instead of UIAlertController
- RCTAppearance: Mostly works, minor AppKit differences
- RCTKeyboardObserver: Completely different (physical keyboard always present)
- RCTDevMenu: NSMenu instead of shake gesture
- RCTClipboard: NSPasteboard instead of UIPasteboard
- Navigation controllers (~18 refs): UINavigationController doesn't exist on
  macOS. Must be ifdef'd out or replaced.

### Layer 4: JS Platform Module (2-3 days)
- Platform.macos.js file (or OOT equivalent)
- Handle 49 Platform.OS === 'ios' checks (use capabilities where possible)
- Add macos key to 19 Platform.select calls

### Layer 5: RNTester macOS Target (2-3 days)
- macOS Podfile target (platform :osx, '14.0')
- Xcode scheme targeting macOS
- Guards for iOS-specific examples (StatusBar, ActionSheet, etc.)

### Layer 6: Remaining UIKit Cleanup (2-3 days)
- 127 files still have #import <UIKit/UIKit.h>
- 34 remaining direct UIView references (not yet RCTPlatformView)
- 2 direct UIWindow references

### Conflict File Resolution
- 179 patch files had merge conflicts and were excluded
- These need manual resolution for full coverage
- Many are in the text/input subsystem (the hardest part)

## Effort Estimate

| Layer | Effort | Notes |
|-------|--------|-------|
| Platform shell | 2-3 weeks | Most critical, most novel |
| ReactCommon platform dirs | 2-3 weeks | TextLayout + TextInput hardest |
| Core module adaptations | 1 week | Mostly no-ops + simple AppKit swaps |
| JS platform + capabilities | 2-3 days | Mostly done already |
| RNTester macOS target | 2-3 days | Podfile + scheme + guards |
| Remaining UIKit cleanup | 2-3 days | Mechanical |
| Total | ~5-7 weeks | For one person, full-time |

## Design Decisions

### OOT vs Fork
We chose OOT over forking because:
- Forks fall behind upstream and require constant rebasing
- The Platform Provider API lets us add macOS without modifying core RN
- Patches are versioned and can be regenerated per RN release
- Zero impact on existing iOS/Android users

### @compatibility_alias vs typedef
ObjC class type aliases must use `@compatibility_alias`, not `typedef`.
`typedef` doesn't support categories (`@interface RCTPlatformView (React)`
fails with typedef but works with @compatibility_alias).

### Separate Pods Can't Use RCTPlatformTypes
ReactCommon pods (React-graphics, React-ImageManager, etc.) are built
separately from React-Core and can't access its headers. These files
must use UIKit types directly and handle platform differences locally.
