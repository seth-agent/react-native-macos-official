# RCTConvert Audit - React Native 0.84.1

Source files:
- `React/Base/RCTConvert.h`
- `React/Base/RCTConvert.mm`

## Header Imports

The header file imports `<UIKit/UIKit.h>` and `<QuartzCore/QuartzCore.h>` unconditionally.
This means the entire file is currently compiled against UIKit. For macOS, `UIKit` would need
to be replaced with `AppKit` (or the `React/RCTUIKit.h` compatibility shim used in react-native-macos).

## Method Classification

### @implementation RCTConvert (main)

| Method / Category | Return Type | Classification | Notes |
|---|---|---|---|
| `+id:` | `id` | Core | Identity passthrough |
| `+BOOL:` | `BOOL` | Core | Primitive type |
| `+double:` | `double` | Core | Primitive type |
| `+float:` | `float` | Core | Primitive type |
| `+int:` | `int` | Core | Primitive type |
| `+int64_t:` | `int64_t` | Core | Primitive type |
| `+uint64_t:` | `uint64_t` | Core | Primitive type |
| `+NSInteger:` | `NSInteger` | Core | Foundation type |
| `+NSUInteger:` | `NSUInteger` | Core | Foundation type |
| `+NSArray:` | `NSArray *` | Core | Foundation type |
| `+NSDictionary:` | `NSDictionary *` | Core | Foundation type |
| `+NSString:` | `NSString *` | Core | Foundation type |
| `+NSNumber:` | `NSNumber *` | Core | Foundation type |
| `+NSSet:` | `NSSet *` | Core | Foundation type |
| `+NSData:` | `NSData *` | Core | Foundation type |
| `+NSIndexSet:` | `NSIndexSet *` | Core | Foundation type |
| `+NSURL:` | `NSURL *` | Core | Foundation type |
| `+NSURLRequestCachePolicy:` | `NSURLRequestCachePolicy` | Core | Foundation enum |
| `+NSURLRequest:` | `NSURLRequest *` | Core | Foundation type |
| `+RCTFileURL:` | `RCTFileURL *` (typedef of NSURL) | Core | Foundation type |
| `+NSDate:` | `NSDate *` | Core | Foundation type |
| `+NSLocale:` | `NSLocale *` | Core | Foundation type |
| `+NSTimeZone:` | `NSTimeZone *` | Core | Foundation type |
| `+NSTimeInterval:` | `NSTimeInterval` | Core | Foundation type |
| `+NSLineBreakMode:` | `NSLineBreakMode` | Core | Available in both UIKit and AppKit (NSParagraphStyle) |
| `+NSTextAlignment:` | `NSTextAlignment` | Core | Available in both UIKit and AppKit |
| `+NSUnderlineStyle:` | `NSUnderlineStyle` | Core | Available in both UIKit and AppKit |
| `+NSWritingDirection:` | `NSWritingDirection` | Core | Available in both UIKit and AppKit |
| `+NSLineBreakStrategy:` | `NSLineBreakStrategy` | Core | Available in both UIKit and AppKit (iOS 14+/macOS 11+). Uses `@available(iOS 14.0, *)` -- needs macOS availability guard too. |
| `+UITextAutocapitalizationType:` | `UITextAutocapitalizationType` | **UIKit** | No AppKit equivalent. macOS does not have autocapitalization. |
| `+UITextFieldViewMode:` | `UITextFieldViewMode` | **UIKit** | UIKit-only enum for text field accessory view visibility. |
| `+UIKeyboardType:` | `UIKeyboardType` | **UIKit** | UIKit-only. macOS has a physical keyboard; no equivalent enum. |
| `+UIKeyboardAppearance:` | `UIKeyboardAppearance` | **UIKit** | UIKit-only (light/dark keyboard). No macOS equivalent. |
| `+UIReturnKeyType:` | `UIReturnKeyType` | **UIKit** | UIKit-only. No macOS equivalent. |
| `+UIUserInterfaceStyle:` | `UIUserInterfaceStyle` | **UIKit** | macOS uses `NSAppearance` instead. Needs mapping. |
| `+UIInterfaceOrientationMask:` | `UIInterfaceOrientationMask` | **UIKit** | iOS-only (guarded by `!TARGET_OS_TV`). No macOS equivalent. |
| `+UIModalPresentationStyle:` | `UIModalPresentationStyle` | **UIKit** | iOS-only modal presentation. macOS uses `NSWindow` modal styles. |
| `+UIDataDetectorTypes:` | `UIDataDetectorTypes` | **UIKit** | Guarded by `!TARGET_OS_TV`. macOS has `NSTextCheckingType` as partial equivalent. |
| `+UIViewContentMode:` | `UIViewContentMode` | **UIKit** | No direct AppKit equivalent. macOS uses layer contentsGravity or custom drawing. |
| `+RCTCursor:` | `RCTCursor` | Core | RN-defined enum (RCTCursor.h). Platform-agnostic definition, but implementation may vary. |
| `+CGFloat:` | `CGFloat` | Core | CoreGraphics type |
| `+CGPoint:` | `CGPoint` | Core | CoreGraphics type |
| `+CGSize:` | `CGSize` | Core | CoreGraphics type |
| `+CGRect:` | `CGRect` | Core | CoreGraphics type |
| `+UIEdgeInsets:` | `UIEdgeInsets` | **UIKit** | macOS uses `NSEdgeInsets` instead. Struct layout is identical but type name differs. |
| `+CGLineCap:` | `CGLineCap` | Core | CoreGraphics enum |
| `+CGLineJoin:` | `CGLineJoin` | Core | CoreGraphics enum |
| `+CGAffineTransform:` | `CGAffineTransform` | Core | CoreGraphics type |
| `+UIColorWithRed:green:blue:alpha:` | `UIColor *` | **UIKit** | macOS uses `NSColor`. Implementation uses `[UIColor colorWithRed:...]` and `[UIColor colorWithDisplayP3Red:...]`. |
| `+UIColorWithRed:green:blue:alpha:andColorSpace:` | `UIColor *` | **UIKit** | Same as above, with color space parameter. |
| `+RCTColorSpaceFromString:` | `RCTColorSpace` | Core | Returns RN-defined enum. No platform types used. |
| `+UIColor:` | `UIColor *` | **UIKit** | Heavy UIKit usage: `[UIColor colorNamed:]`, `[UIColor colorWithDynamicProvider:]`, `UITraitCollection`, `UIAccessibilityContrastHigh`. Core color logic is platform-agnostic but wrapped in UIKit APIs. |
| `+CGColor:` | `CGColorRef` | **Gray area** | CGColorRef is CoreGraphics (shared), but implementation calls `[self UIColor:json].CGColor` -- depends on UIKit. |
| `+YGValue:` | `YGValue` | Core | Yoga layout type, fully cross-platform. |
| `+NSArrayArray:` | `NSArray<NSArray *> *` | Core | Foundation type |
| `+NSStringArray:` | `NSArray<NSString *> *` | Core | Foundation type |
| `+NSStringArrayArray:` | `NSArray<NSArray<NSString *> *> *` | Core | Foundation type |
| `+NSDictionaryArray:` | `NSArray<NSDictionary *> *` | Core | Foundation type |
| `+NSURLArray:` | `NSArray<NSURL *> *` | Core | Foundation type |
| `+RCTFileURLArray:` | `NSArray<RCTFileURL *> *` | Core | Foundation type |
| `+NSNumberArray:` | `NSArray<NSNumber *> *` | Core | Foundation type |
| `+UIColorArray:` | `NSArray<UIColor *> *` | **UIKit** | Array of UIColor. |
| `+CGColorArray:` | `CGColorArray *` (NSArray typedef) | **Gray area** | Returns NSArray of CGColorRef. Implementation calls `[self CGColor:]` which depends on UIColor. |
| `+NSPropertyList:` | `NSPropertyList` (id typedef) | Core | Foundation types only |
| `+css_backface_visibility_t:` | `css_backface_visibility_t` (BOOL typedef) | Core | Primitive type |
| `+YGOverflow:` | `YGOverflow` | Core | Yoga enum |
| `+YGDisplay:` | `YGDisplay` | Core | Yoga enum |
| `+YGFlexDirection:` | `YGFlexDirection` | Core | Yoga enum |
| `+YGJustify:` | `YGJustify` | Core | Yoga enum |
| `+YGAlign:` | `YGAlign` | Core | Yoga enum |
| `+YGPositionType:` | `YGPositionType` | Core | Yoga enum |
| `+YGWrap:` | `YGWrap` | Core | Yoga enum |
| `+YGDirection:` | `YGDirection` | Core | Yoga enum |
| `+RCTPointerEvents:` | `RCTPointerEvents` | Core | RN-defined enum |
| `+RCTAnimationType:` | `RCTAnimationType` | Core | RN-defined enum |
| `+RCTBorderStyle:` | `RCTBorderStyle` | Core | RN-defined enum |
| `+RCTBorderCurve:` | `RCTBorderCurve` | Core | RN-defined enum |
| `+RCTTextDecorationLineType:` | `RCTTextDecorationLineType` | Core | RN-defined enum |

### @implementation RCTConvert (Deprecated)

| Method / Category | Return Type | Classification | Notes |
|---|---|---|---|
| `+UIImage:` | `UIImage *` | **UIKit** | Uses `UIImage`, `RCTImageFromLocalAssetURL`, `RCTImageFromLocalBundleAssetURL`, `RCTIsMainQueue`, `RCTUnsafeExecuteOnMainQueueSync`. macOS uses `NSImage`. |
| `+CGImage:` | `CGImageRef` | **Gray area** | CGImageRef is CoreGraphics, but implementation calls `[self UIImage:json].CGImage`. |

### Static / Helper Functions (not class methods, but used internally)

| Function | Classification | Notes |
|---|---|---|
| `convertCGStruct(...)` | Core | Uses only CoreGraphics types |
| `RCTConvertEnumValue(...)` | Core | Foundation-only logic |
| `RCTConvertMultiEnumValue(...)` | Core | Foundation-only logic |
| `RCTConvertArrayValue(...)` | Core | Foundation-only logic |
| `RCTConvertPropertyListValue(...)` | Core | Foundation-only logic |
| `RCTSemanticColorsMap()` | **UIKit** | Returns UIColor semantic color map using UIColor selectors. Deeply iOS-specific (color names reference iOS system colors). |
| `RCTColorFromSemanticColorName(...)` | **UIKit** | Uses `[UIColor respondsToSelector:]` and returns UIColor. |
| `RCTSemanticColorNames()` | **UIKit** | Depends on RCTSemanticColorsMap. |
| `RCTGetDefaultColorSpace()` | Core | Returns RCTColorSpace enum |
| `RCTSetDefaultColorSpace(...)` | Core | Sets RCTColorSpace enum |

## Summary

### Counts

| Classification | Method Count |
|---|---|
| Core (platform-agnostic) | ~50 methods/functions |
| UIKit-specific | ~18 methods/functions |
| Gray area | 3 methods |

### UIKit Methods Requiring macOS Adaptation

These are the methods that must be either replaced, conditionally compiled, or abstracted for macOS support:

1. **Text input enums** (no macOS equivalent -- stub or omit):
   - `UITextAutocapitalizationType`
   - `UITextFieldViewMode`
   - `UIKeyboardType`
   - `UIKeyboardAppearance`
   - `UIReturnKeyType`

2. **UI appearance / presentation** (need AppKit mapping):
   - `UIUserInterfaceStyle` -> `NSAppearance`
   - `UIModalPresentationStyle` -> `NSWindow` modal APIs
   - `UIInterfaceOrientationMask` -> N/A on macOS (omit)
   - `UIViewContentMode` -> layer `contentsGravity` or custom enum

3. **Data detection** (partial equivalent):
   - `UIDataDetectorTypes` -> `NSTextCheckingType`

4. **Color system** (major effort):
   - `UIColor` -> `NSColor` (or RCTUIColor compatibility typedef)
   - `UIColorWithRed:green:blue:alpha:` -> `NSColor` factory methods
   - `UIColorArray` -> `NSColorArray`
   - `RCTSemanticColorsMap()` -> needs entirely different semantic color names for macOS
   - `RCTColorFromSemanticColorName()` -> needs to use `NSColor` selectors
   - `CGColor:` / `CGColorArray:` -> implementation depends on UIColor, needs rewiring

5. **Edge insets**:
   - `UIEdgeInsets` -> `NSEdgeInsets` (same memory layout, different type name)

6. **Image** (Deprecated category):
   - `UIImage` -> `NSImage`
   - `CGImage:` -> depends on UIImage

### Recommended Approach for macOS Port

The react-native-macos project typically uses a compatibility header (`RCTUIKit.h`) that provides:
- `typedef NSColor RCTUIColor` (macOS) / `typedef UIColor RCTUIColor` (iOS)
- `typedef NSImage RCTUIImage` / `typedef UIImage RCTUIImage`
- `typedef NSEdgeInsets RCTUIEdgeInsets` / `typedef UIEdgeInsets RCTUIEdgeInsets`
- Conditional `#if TARGET_OS_OSX` / `#else` blocks for platform-specific enum converters

The cleanest separation would be:
1. Keep all Core methods in `RCTConvert.h/.mm` unchanged.
2. Move UIKit-specific methods into a category `RCTConvert+UIKit.h/.mm` (iOS) and `RCTConvert+AppKit.h/.mm` (macOS), or use `#if TARGET_OS_OSX` guards inline.
3. Replace `UIColor` with `RCTUIColor` (or platform-appropriate type) in the shared color methods.
4. Provide a macOS-specific semantic color map in `RCTSemanticColorsMap()`.
