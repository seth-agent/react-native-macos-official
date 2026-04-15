# Wave 2 UIKit Audit: Shared React-Core Headers

**Date:** 2026-04-01
**Scope:** `React/Base/*.h`, `React/Views/*.h`, `React/Modules/*.h`, `React/Fabric/**/*.h`
**Method:** Whole-word grep for all UIKit type symbols across `.h` files

---

## 1. Summary Totals

| Metric | Count |
|--------|-------|
| **Total UIKit type references** | **237** |
| **Total files affected** | **61** |
| **Distinct UIKit types found** | **24** |
| **Direct `#import <UIKit/...>` statements** | **32** (across all scoped dirs + CoreModules/DevSupport) |

---

## 2. Breakdown by UIKit Type

| UIKit Type | Proposed Replacement | Refs | Files | Priority |
|------------|---------------------|------|-------|----------|
| `UIView` | `RNPlatformView` | 85 | 34 | **P0 - Critical** |
| `UIEdgeInsets` | `RNPlatformEdgeInsets` | 26 | 15 | **P0 - Critical** |
| `UIColor` | `RNPlatformColor` | 18 | 5 | **P1 - High** |
| `UIViewController` | `RNPlatformViewController` | 18 | 10 | **P1 - High** |
| `UIScrollView` | `RNPlatformScrollView` | 17 | 8 | **P1 - High** |
| `UIFont` | `RNPlatformFont` | 14 | 3 | **P1 - High** |
| `UIImage` | `RNPlatformImage` | 10 | 2 | **P2 - Medium** |
| `UIAccessibilityTraits` | Platform-agnostic traits | 9 | 4 | **P2 - Medium** |
| `UIGestureRecognizer` | `RNPlatformGestureRecognizer` | 7 | 5 | **P2 - Medium** |
| `UIBezierPath` | `RNPlatformBezierPath` | 7 | 1 | **P3 - Low** |
| `UIEvent` | `RNPlatformEvent` | 6 | 2 | **P2 - Medium** |
| `UIApplication` | `RNPlatformApplication` | 4 | 1 | **P3 - Low** |
| `UIScrollViewDelegate` | `RNPlatformScrollViewDelegate` | 4 | 2 | **P1 - High** (tied to UIScrollView) |
| `UIAccessibilityTraitNone` | Platform-agnostic constant | 2 | 2 | **P2 - Medium** |
| `UIAccessibilityElement` | Platform-agnostic element | 2 | 1 | **P2 - Medium** |
| `UIAdaptivePresentationControllerDelegate` | Platform-agnostic delegate | 2 | 2 | **P3 - Low** |
| `UITextFieldViewMode` | Platform-agnostic enum | 2 | 2 | **P3 - Low** |
| `UIWindow` | `RNPlatformWindow` | 1 | 1 | **P3 - Low** |
| `UIUserInterfaceStyle` | `RNPlatformUserInterfaceStyle` | 1 | 1 | **P3 - Low** |
| `UITouch` | `RNPlatformTouch` | 1 | 1 | **P3 - Low** |
| `UILabel` | `RNPlatformLabel` | 1 | 1 | **P3 - Low** |
| `UIScrollViewKeyboardDismissMode` | Platform-agnostic enum | 1 | 1 | **P3 - Low** |
| `UITextInputPasswordRules` | Platform-agnostic type | 1 | 1 | **P3 - Low** |
| `UIImageView` | `RNPlatformImageView` | 1 | 1 | **P3 - Low** |

---

## 3. Breakdown by Directory

| Directory | UIKit Refs | Files Affected | % of Total |
|-----------|-----------|----------------|------------|
| **Base/** | 93 | 12 | 39.2% |
| **Views/** | 74 | 21 | 31.2% |
| **Fabric/** | 57 | 27 | 24.1% |
| **Modules/** | 13 | 1 | 5.5% |
| **Total** | **237** | **61** | **100%** |

**Key observation:** `Base/` has the highest density (93 refs in just 12 files), driven heavily
by `RCTUIKit.h` which is the existing platform abstraction layer. `Views/` is the most spread
out (74 refs across 21 files). `Fabric/` has moderate density spread across its component views.

---

## 4. Top 20 Most-Referenced Files

| Rank | File | UIKit Refs |
|------|------|-----------|
| 1 | `Base/RCTUIKit.h` | 61 |
| 2 | `Views/UIView+React.h` | 16 |
| 3 | `Views/RCTView.h` | 16 |
| 4 | `Modules/RCTUIManager.h` | 13 |
| 5 | `Base/RCTRootView.h` | 9 |
| 6 | `Base/RCTConvert+UIKit.h` | 9 |
| 7 | `Views/ScrollView/RCTScrollView.h` | 8 |
| 8 | `Views/RCTFont.h` | 8 |
| 9 | `Fabric/Mounting/ComponentViews/View/RCTViewComponentView.h` | 7 |
| 10 | `Fabric/RCTConversions.h` | 6 |
| 11 | `Fabric/Mounting/ComponentViews/ScrollView/RCTScrollViewComponentView.h` | 5 |
| 12 | `Fabric/Mounting/ComponentViews/Modal/RCTModalHostViewComponentView.h` | 5 |
| 13 | `Views/RCTBorderDrawing.h` | 4 |
| 14 | `Fabric/Surface/RCTFabricSurface.h` | 4 |
| 15 | `Fabric/Mounting/ComponentViews/ScrollView/RCTEnhancedScrollView.h` | 4 |
| 16 | `Views/RCTShadowView+Layout.h` | 3 |
| 17 | `Views/RCTModalHostViewManager.h` | 3 |
| 18 | `Fabric/Mounting/RCTComponentViewProtocol.h` | 3 |
| 19 | `Base/Surface/SurfaceHostingView/RCTSurfaceHostingView.h` | 3 |
| 20 | `Base/Surface/RCTSurfaceProtocol.h` | 3 |

---

## 5. Recommendations: Prioritized Extraction Order

### Phase 1 (Highest Impact, Foundation Layer)

**`UIView` (85 refs, 34 files) -- Tackle first.**
- This is the single most pervasive UIKit type. It appears in every directory.
- `RCTUIKit.h` already defines `RCTPlatformView` and `RCTUIView` as typedefs/macros for `UIView`.
  The existing abstraction proves the pattern works; Wave 2 should promote these to the
  canonical `RNPlatformView` type and ensure all 34 files use it consistently.
- Start with `UIView+React.h` (16 refs) and `RCTView.h` (16 refs) since they define the
  core view protocol that everything else depends on.

**`UIEdgeInsets` (26 refs, 15 files) -- Tackle alongside UIView.**
- Frequently co-located with `UIView` in layout code. Appears in layout headers
  (`RCTShadowView+Layout.h`, `RCTBorderDrawing.h`, `RCTLayout.h`), scroll views, and Fabric conversions.
- On macOS this maps to `NSEdgeInsets`; a simple typedef makes this trivial.

### Phase 2 (High Impact, Moderate Complexity)

**`UIColor` (18 refs, 5 files)** -- Already partially abstracted as `RCTUIColor` in border drawing.
Concentrated in just 5 files, making it a quick win.

**`UIViewController` (18 refs, 10 files)** -- Spread across modal hosts and wrapper controllers.
The macOS equivalent (`NSViewController`) has a different API surface, so this needs careful
interface design.

**`UIScrollView` + `UIScrollViewDelegate` (21 refs combined, 10 files)** -- Critical for
scroll-heavy RN apps. The Fabric `RCTEnhancedScrollView` already uses `RCTUIScrollView`;
extend this pattern to old-arch scroll views.

**`UIFont` (14 refs, 3 files)** -- Concentrated in `RCTFont.h`. Maps to `NSFont` on macOS.
Low file count means low blast radius.

### Phase 3 (Medium Impact)

**`UIImage` (10 refs, 2 files)** -- Already abstracted as `RCTPlatformImage`/`RCTUIImage`
in `RCTUIKit.h`. Ensure all consumers use the abstract type.

**`UIAccessibilityTraits` (13 refs total including sub-types, 4 files)** -- Concentrated in
`RCTConversions.h`. Needs a platform-agnostic accessibility trait enum.

**`UIGestureRecognizer` (7 refs, 5 files)** -- Used by Fabric touch/pointer handlers.
Maps to `NSGestureRecognizer` on macOS but with different API.

**`UIEvent` (6 refs, 2 files)** -- Appears in hit-testing code. Maps to `NSEvent` on macOS.

### Phase 4 (Low Impact, Long Tail)

The remaining 10 types (`UIBezierPath`, `UIApplication`, `UIWindow`, `UITouch`, `UILabel`,
etc.) have 1-7 refs each, mostly in single files. These can be handled opportunistically
as their containing files are touched for other reasons.

---

## 6. Existing Abstraction Layer (Important Context)

`Base/RCTUIKit.h` already defines platform macros for the iOS path:
```objc
#define RCTPlatformView  UIView
#define RCTUIView        UIView
#define RCTUIScrollView  UIScrollView
#define RCTPlatformImage UIImage
#define RCTUIImage       UIImage
```

**47 of the 61 affected files do NOT use these abstractions** -- they reference raw UIKit types
directly. The primary work of Wave 2 is migrating those 47 files to use the existing
`RCT*` abstractions (or the new `RNPlatform*` names if rebranding), NOT inventing new ones.

---

## 7. Risk Notes

- `RCTUIKit.h` (61 refs) is itself the abstraction layer -- it intentionally references UIKit
  types to define the mappings. These 61 refs should NOT be changed; they are the source of truth.
- Some refs are in comments/documentation (e.g., `UIViewNoIntrinsicMetric` in `RCTShadowView.h`).
  These are informational and low-priority but should still be updated for correctness.
- `UIAdaptivePresentationControllerDelegate` has no direct AppKit equivalent -- modal
  presentation works differently on macOS. This needs custom protocol design, not just a typedef.
