# MacOS Build Report: Split RCTConvert Validation

**Date:** 2026-04-01
**Issue:** #12 - Validate MacOSTestApp builds with split RCTConvert

## Summary

Pod install and xcodebuild both succeed with zero errors.

## Results

### Pod Install
- **Status:** SUCCESS
- 75 dependencies from Podfile, 74 total pods installed
- No warnings related to RCTConvert

### Build
- **Status:** SUCCESS (zero errors)
- Command: `xcodebuild -workspace MacOSTestApp.xcworkspace -scheme MacOSTestApp-macOS -destination 'platform=macOS' build`
- No errors of any kind (RCTConvert-related or otherwise)

### RCTConvert+UIKit.mm Compilation
- **Not compiled from source.** The MacOSTestApp uses React Native's **prebuilt xcframework** (`React-Core-prebuilt`), not source compilation.
- `build_rncore_from_source()` returns false, so `podspec_sources()` returns header-only paths.
- The prebuilt `React.xcframework` contains the original (unsplit) compiled RCTConvert code with all UIKit methods baked in.
- The split headers (`RCTConvert.h` + `RCTConvert+UIKit.h`) are properly exposed in `Pods/Headers/Public/React-Core/React/` and used for header resolution.

### Why the Build Succeeds
1. The split `RCTConvert.h` includes a compat `#import "RCTConvert+UIKit.h"` re-export, so all existing consumers see the same API through the original header.
2. The prebuilt binary already contains all UIKit method implementations (compiled before the split).
3. No consumer code needed changes.

## Limitations of This Validation

This test validates **header compatibility** of the split (that the split headers don't break consumers), but does **not** validate that `RCTConvert+UIKit.mm` compiles correctly from source on macOS. To validate source compilation, a build-from-source test would be needed (set `RCT_BUILD_RNCORE_FROM_SOURCE=1` or equivalent).

## New Regressions from Split

None. Zero errors, and the split headers are properly resolved.
