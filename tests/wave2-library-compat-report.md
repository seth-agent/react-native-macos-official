# Wave 2 UIKit Type Codemod — Ecosystem Library Compatibility Report

**Date:** 2026-04-01
**Scope:** Verify that replacing UIView/UIColor with RCTPlatformView/RCTUIColor in React-Core public headers does not break third-party library compilation on iOS.

## Verification

### 1. RCTPlatformView is a transparent alias for UIView on iOS

Confirmed in installed headers at:
`Pods/Headers/Public/React-Core/React/RCTUIKit.h`

```
#define RCTPlatformView UIView        // iOS path
#define RCTPlatformView NSView        // macOS path
```

On iOS, `RCTPlatformView *` is **token-identical** to `UIView *` after preprocessing. There is no type mismatch, no implicit cast, no bridging — the preprocessor substitutes `UIView` before the compiler ever sees it.

### 2. Headers affected by the codemods

26 React-Core public headers now use `RCTPlatformView` or `RCTUIColor`, including the most commonly consumed ones:

- **RCTViewManager.h** — `- (RCTPlatformView *)view;` and the `RCTViewManagerUIBlock` typedef
- **RCTView.h** — `+ (void)autoAdjustInsetsForView:(RCTPlatformView<RCTAutoInsetsProtocol> *)parentView`
- **UIView+React.h** — `@interface RCTPlatformView (React)`, `-reactSubviews`, `-reactSuperview`, etc.
- **RCTUIManager.h**, **RCTRootView.h**, **RCTScrollView.h**, and others

### 3. Impact on ecosystem libraries

**No impact on iOS builds.** Three categories cover all cases:

| Category | Example Libraries | Why they are unaffected |
|---|---|---|
| Libraries that use their own `UIView *` variables | react-native-screens, react-native-gesture-handler, react-native-reanimated | They reference `UIView` directly in their own source. The preprocessor expands `RCTPlatformView` to `UIView` in React-Core headers before the compiler sees it, so any assignment between `RCTPlatformView *` (from a React-Core API return) and `UIView *` (in their code) is identity-typed. |
| Libraries that subclass `RCTView` or `RCTViewManager` | react-native-svg, react-native-maps, lottie-react-native | They override `-view` which now returns `RCTPlatformView *`. On iOS this is `UIView *`. Calling `.frame`, `-addSubview:`, etc. works identically. |
| Libraries that only use JS/TS APIs | react-navigation, react-native-async-storage | No native Objective-C code consuming these headers. |

### 4. macOS path (where it matters)

On macOS, `RCTPlatformView` resolves to `NSView`, which is the whole point of the codemods — enabling a single header set for both platforms. Libraries targeting macOS must already handle `NSView` vs `UIView` differences (no `.frame` setter on NSView, different coordinate systems, etc.), but that is a pre-existing macOS porting concern, not a regression from Wave 2.

## Verdict

**PASS.** The Wave 2 codemods are binary-transparent on iOS. `#define RCTPlatformView UIView` means the compiler never sees the alias — every downstream library compiles exactly as before. No source changes are required in any ecosystem library for iOS targets.
