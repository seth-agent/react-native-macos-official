# Library Compatibility Report: RCTConvert Header Split

**Date:** 2026-04-15
**Issue:** #11 - Verify top ecosystem libraries compile against compat headers
**Split:** RCTConvert.h (core) + RCTConvert+UIKit.h (UIKit category), with compat re-export

## Header Split Summary

**Core (RCTConvert.h):** BOOL, double, float, int, int64_t, uint64_t, NSInteger, NSUInteger,
NSArray, NSDictionary, NSString, NSNumber, NSSet, NSData, NSIndexSet, NSURL, NSURLRequest,
NSDate, NSLocale, NSTimeZone, NSTimeInterval, NSLineBreakMode, NSTextAlignment,
NSUnderlineStyle, NSWritingDirection, NSLineBreakStrategy, CGFloat, CGPoint, CGSize, CGRect,
CGLineCap, CGLineJoin, CGAffineTransform, RCTColorSpace, RCTCursor, YGValue, YG* enums,
RCTPointerEvents, RCTAnimationType, RCTBorderStyle, RCTBorderCurve, RCTTextDecorationLineType,
NSNumberArray, NSStringArray, NSDictionaryArray, NSURLArray, RCTFileURLArray, macros
(RCT_CONVERTER, RCT_ENUM_CONVERTER, etc.)

**UIKit Category (RCTConvert+UIKit.h):** UIColor, CGColor, UIImage, CGImage, UIEdgeInsets,
UITextAutocapitalizationType, UITextFieldViewMode, UIKeyboardType, UIDataDetectorTypes,
UIKeyboardAppearance, UIReturnKeyType, UIUserInterfaceStyle, UIInterfaceOrientationMask,
UIModalPresentationStyle, UIViewContentMode, UIColorArray, CGColorArray

**Compat mechanism:** RCTConvert.h has `#import <React/RCTConvert+UIKit.h>` at the bottom.

## CRITICAL FINDING

**The current RCTConvert+UIKit.h is a stub** containing only `// Stub - UIKit category not needed for this test`.
It has NO method declarations. This means:

- `[RCTConvert UIColor:]` produces `-Wobjc-method-access` warning (return type defaults to `id`)
- `[RCTConvert UIEdgeInsets:]` produces a compile ERROR (struct return from `id` is incompatible)
- All other UIKit category methods similarly lack declarations

**The stub .h must be replaced with proper @interface declarations** for the compat re-export to work.
The .mm implementation file has the full implementations, but the .h doesn't declare them.

---

## Library Results

### 1. react-native-screens

**References RCTConvert:** YES (heavy usage)
**Import style:** `#import <React/RCTConvert.h>` (multiple files)
**Categories defined:** RCTConvert (RNSScreenStackHeaderSubview), (RNSScreenStackHeader), (RNSScreen), (RNScreens), (RNSTabs), (RNSSafeAreaViewEdges)

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `BOOL:` | core | Core |
| `UIColor:` | UIKit | **UIKit** |
| `UITextAutocapitalizationType:` | UIKit | **UIKit** |
| `UIInterfaceOrientationMask:` | UIKit | **UIKit** |
| `UIStatusBarAnimation:` | custom (RNScreens) | Custom |
| `RCTImageSource:` | other RN header | Other |
| `UIImage:` | UIKit | **UIKit** |
| `UIOffset:` | custom (RNSTabs) | Custom |

**Verdict:** FAIL - Uses UIColor, UITextAutocapitalizationType, UIInterfaceOrientationMask, UIImage from UIKit category. With stub .h, these have no declarations.

---

### 2. react-native-gesture-handler

**References RCTConvert:** YES (moderate usage)
**Import style:** `#import <React/RCTConvert.h>` (multiple files)

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `BOOL:` | core | Core |
| `NSNumberArray:` | core | Core |
| `CGFloat:` | core | Core |
| `NSInteger:` | core | Core |
| `UIEdgeInsets:` | UIKit | **UIKit** |
| `RCTPointerEvents:` | core | Core |

**Verdict:** FAIL - Uses UIEdgeInsets from UIKit category (in RNGestureHandlerButtonManager.mm). This is a struct return, so it will be a compile error, not just a warning.

---

### 3. react-native-reanimated

**References RCTConvert:** NO
**Import style:** N/A

**Verdict:** PASS - No RCTConvert references in native code.

---

### 4. react-native-svg

**References RCTConvert:** YES (heavy usage)
**Import style:** `#import <React/RCTConvert.h>` (via RCTConvert+RNSVG.h), `#import <React/RCTConvert+Transform.h>`
**Categories defined:** RCTConvert (RNSVG) - defines custom types RNSVGLength, RNSVGBrush, RNSVGColor, etc.

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `RNSVGLength:` | custom (RNSVG) | Custom |
| `RNSVGLengthArray:` | custom (RNSVG) | Custom |
| `RNSVGBrush:` | custom (RNSVG) | Custom |
| `RNSVGColor:offset:` | custom (RNSVG) | Custom |
| `RNSVGCGGradient:` | custom (RNSVG) | Custom |
| `UIEdgeInsets:` | UIKit | **UIKit** |
| `RCTPointerEvents:` | core | Core |
| `CATransform3D:` | other RN header (RCTConvert+Transform.h) | Other |

**Verdict:** FAIL - Uses UIEdgeInsets from UIKit category (in RNSVGSvgViewManager.mm). Struct return = compile error.

---

### 5. lottie-react-native

**References RCTConvert:** YES (light usage)
**Import style:** `#import <React/RCTConvert.h>` (via RCTConvert+Lottie.h)
**Categories defined:** RCTConvert (Lottie)

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `UIColor:` | UIKit | **UIKit** |

**Verdict:** FAIL - Uses UIColor from UIKit category. Will produce warning (return type defaults to `id`, which is assignable to `UIColor *` but unsafe).

---

### 6. react-native-safe-area-context

**References RCTConvert:** YES (light usage)
**Import style:** `#import <React/RCTConvert.h>`
**Categories defined:** RCTConvert (RNCSafeAreaView), (RNCSafeAreaViewEdges), (RNCSafeAreaViewEdgeMode)

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `RNCSafeAreaViewEdgeMode:` | custom | Custom |

**Verdict:** PASS - Only uses custom category methods defined by the library itself. Does not call any UIKit category methods. Uses RCT_ENUM_CONVERTER macro from core header.

---

### 7. react-native-device-info

**References RCTConvert:** NO
**Import style:** N/A

**Verdict:** PASS - No RCTConvert references in native code.

---

### 8. react-native-linear-gradient

**References RCTConvert:** YES (light usage)
**Import style:** `#import <React/RCTConvert.h>`

| Method Called | Category | Core or UIKit? |
|---|---|---|
| `UIColor:` | UIKit | **UIKit** |

**Verdict:** FAIL - Uses UIColor from UIKit category. Will produce warning with stub header.

---

## Summary

| Library | References RCTConvert | UIKit Methods Used | Verdict |
|---|---|---|---|
| react-native-screens | Yes | UIColor, UIImage, UIEdgeInsets, UITextAutocapitalizationType, UIInterfaceOrientationMask | **FAIL** |
| react-native-gesture-handler | Yes | UIEdgeInsets | **FAIL** |
| react-native-reanimated | No | None | **PASS** |
| react-native-svg | Yes | UIEdgeInsets | **FAIL** |
| lottie-react-native | Yes | UIColor | **FAIL** |
| react-native-safe-area-context | Yes | None (custom categories only) | **PASS** |
| react-native-device-info | No | None | **PASS** |
| react-native-linear-gradient | Yes | UIColor | **FAIL** |

**Result: 5 of 8 libraries FAIL** because the RCTConvert+UIKit.h stub lacks method declarations.

## Remediation

The RCTConvert+UIKit.h stub must be replaced with a proper header declaring:

```objc
@interface RCTConvert (UIKit)
+ (UIColor *)UIColor:(id)json;
+ (UIColor *)UIColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)UIColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha andColorSpace:(RCTColorSpace)colorSpace;
+ (CGColorRef)CGColor:(id)json;
+ (UIEdgeInsets)UIEdgeInsets:(id)json;
+ (UIImage *)UIImage:(id)json;
+ (CGImageRef)CGImage:(id)json;
+ (NSArray<UIColor *> *)UIColorArray:(id)json;
+ (NSArray *)CGColorArray:(id)json;
@end
```

Plus enum converter declarations generated by RCT_ENUM_CONVERTER (UITextAutocapitalizationType, UIKeyboardType, UIViewContentMode, etc.).

Once the .h has proper declarations, all 8 libraries will PASS since the compat re-export at the bottom of RCTConvert.h ensures they get all declarations transparently.
