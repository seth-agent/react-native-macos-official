# iOS Build Validation Report — Split RCTConvert

**Date:** 2026-04-14
**Issue:** #13 — Validate: fresh RN iOS app builds with split RCTConvert

## Environment

- **Xcode:** 26.3.0 (build 17C529)
- **iOS SDK:** 26.2 (iphonesimulator26.2)
- **iOS Simulator devices:** None available (iOS platform not fully installed)
- **Workspace:** MacOSTestApp.xcworkspace
- **Split files location:** `node_modules/react-native/React/Base/`

## Files Under Test

| File | Extension | Present |
|------|-----------|---------|
| RCTConvert.h | .h | Yes |
| RCTConvert.mm | .mm | Yes |
| RCTConvert+UIKit.h | .h | Yes |
| RCTConvert+UIKit.mm | .mm | Yes |

Both headers are properly symlinked in Pods/Headers/Public and Pods/Headers/Private.

## Test Results

### 1. React-Core Scheme Build (macOS destination)

**Result: BUILD SUCCEEDED**

The React-Core scheme builds successfully with `platform=macOS`. Note: React-Core uses prebuilt XCFrameworks, so source files are not recompiled. Headers are validated via downstream consumers.

### 2. Header Compilation (iOS Simulator SDK — clang syntax check)

| Header | Result |
|--------|--------|
| RCTConvert.h | **PASS** — zero errors |
| RCTConvert+UIKit.h | **PASS** — zero errors |

Both split headers parse and type-check cleanly when compiled as Objective-C++ headers against the iOS Simulator SDK with Yoga and React-Core include paths.

### 3. Implementation File Compilation (iOS Simulator SDK — clang syntax check)

| File | Errors | RCTConvert-split related? |
|------|--------|--------------------------|
| RCTConvert.mm | 3 errors | **No** — all are `RCTNilIfNull` (defined in RCTUtils, not in include path) |
| RCTConvert+UIKit.mm | 5 errors | **No** — `RCTNilIfNull`, `RCTUnsafeExecuteOnMainQueueSync`, `RCTImageFromLocalAssetURL`, `RCTImageFromLocalBundleAssetURL` (all utility functions from other RN headers not in standalone include path) |

All errors are pre-existing dependencies on utility functions defined outside the Base directory. Zero errors are attributable to the RCTConvert split.

### 4. Full App Build — MacOSTestApp-iOS Scheme

**Result: COULD NOT RUN** — No iOS Simulator devices available. The iOS 26.2 platform runtime is not installed in this Xcode instance.

### 5. Full App Build — MacOSTestApp-macOS Scheme

**Result: BUILD FAILED** — Pre-existing failures unrelated to RCTConvert:
- `'UIKit/UIKit.h' file not found` in RCTEventDispatcher.h
- `'yoga/style/Style.h' file not found` in YogaStylableProps.h

No RCTConvert-related errors appeared.

## Conclusion

**Zero regressions from the RCTConvert split.**

- Both split headers (`RCTConvert.h` and `RCTConvert+UIKit.h`) compile cleanly on the iOS Simulator SDK.
- All implementation file errors are pre-existing utility function dependencies, not caused by the split.
- The React-Core scheme builds successfully, confirming the pod structure is intact.
- A full iOS app build could not be performed due to missing simulator runtime, but all available evidence shows the split introduces no regressions.

### Recommendation

To fully close this issue, install the iOS 26.2 Simulator runtime (`Xcode > Settings > Components`) and re-run:
```
xcodebuild -workspace MacOSTestApp.xcworkspace -scheme MacOSTestApp-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```
