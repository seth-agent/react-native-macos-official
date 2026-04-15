#!/bin/bash
# codemod-rctconvert-split.sh
#
# Splits UIKit-specific methods out of RCTConvert.h/.mm into
# RCTConvert+UIKit.h/.mm category files.
#
# Usage: ./codemod-rctconvert-split.sh <path-to-clean-rn-checkout>
# Example: ./codemod-rctconvert-split.sh upstream-rn-0.84.1/
#
# This script is idempotent: it checks for the existence of the
# category files before running.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-clean-rn-checkout>" >&2
  exit 1
fi

RN_ROOT="$1"
BASE_DIR="${RN_ROOT}/React/Base"
HEADER="${BASE_DIR}/RCTConvert.h"
IMPL="${BASE_DIR}/RCTConvert.mm"
UIKIT_HEADER="${BASE_DIR}/RCTConvert+UIKit.h"
UIKIT_IMPL="${BASE_DIR}/RCTConvert+UIKit.mm"

if [ ! -f "$HEADER" ]; then
  echo "Error: $HEADER not found" >&2
  exit 1
fi
if [ ! -f "$IMPL" ]; then
  echo "Error: $IMPL not found" >&2
  exit 1
fi

# Idempotency: if the +UIKit files already exist, skip
if [ -f "$UIKIT_HEADER" ] && [ -f "$UIKIT_IMPL" ]; then
  echo "RCTConvert+UIKit files already exist. Skipping (idempotent)."
  exit 0
fi

###############################################################################
# 1. Create RCTConvert+UIKit.h
###############################################################################

cat > "$UIKIT_HEADER" << 'HEADER_EOF'
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

#import <React/RCTConvert.h>

/**
 * UIKit-specific RCTConvert methods, extracted from RCTConvert.h/.mm
 * for platform extraction (RFC 0003).
 */
@interface RCTConvert (UIKit)

+ (UITextAutocapitalizationType)UITextAutocapitalizationType:(id)json;
+ (UITextFieldViewMode)UITextFieldViewMode:(id)json;
+ (UIKeyboardType)UIKeyboardType:(id)json;
+ (UIKeyboardAppearance)UIKeyboardAppearance:(id)json;
+ (UIReturnKeyType)UIReturnKeyType:(id)json;
+ (UIUserInterfaceStyle)UIUserInterfaceStyle:(id)json API_AVAILABLE(ios(12));
#if !TARGET_OS_TV
+ (UIInterfaceOrientationMask)UIInterfaceOrientationMask:(NSString *)orientation;
#endif
+ (UIModalPresentationStyle)UIModalPresentationStyle:(id)json;

#if !TARGET_OS_TV
+ (UIDataDetectorTypes)UIDataDetectorTypes:(id)json;
#endif

+ (UIViewContentMode)UIViewContentMode:(id)json;

+ (UIEdgeInsets)UIEdgeInsets:(id)json;

+ (UIColor *)UIColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)UIColorWithRed:(CGFloat)red
                      green:(CGFloat)green
                       blue:(CGFloat)blue
                      alpha:(CGFloat)alpha
              andColorSpace:(RCTColorSpace)colorSpace;
+ (UIColor *)UIColor:(id)json;
+ (CGColorRef)CGColor:(id)json CF_RETURNS_NOT_RETAINED;

+ (NSArray<UIColor *> *)UIColorArray:(id)json;

typedef NSArray CGColorArray;
+ (CGColorArray *)CGColorArray:(id)json;

@end

@interface RCTConvert (Deprecated)

/**
 * Use lightweight generics syntax instead, e.g. NSArray<NSString *>
 */
typedef NSArray NSArrayArray __deprecated_msg("Use NSArray<NSArray *>");
typedef NSArray NSStringArray __deprecated_msg("Use NSArray<NSString *>");
typedef NSArray NSStringArrayArray __deprecated_msg("Use NSArray<NSArray<NSString *> *>");
typedef NSArray NSDictionaryArray __deprecated_msg("Use NSArray<NSDictionary *>");
typedef NSArray NSURLArray __deprecated_msg("Use NSArray<NSURL *>");
typedef NSArray RCTFileURLArray __deprecated_msg("Use NSArray<RCTFileURL *>");
typedef NSArray NSNumberArray __deprecated_msg("Use NSArray<NSNumber *>");
typedef NSArray UIColorArray __deprecated_msg("Use NSArray<UIColor *>");

/**
 * Synchronous image loading is generally a bad idea for performance reasons.
 * If you need to pass image references, try to use `RCTImageSource` and then
 * `RCTImageLoader` instead of converting directly to a UIImage.
 */
+ (UIImage *)UIImage:(id)json;
+ (CGImageRef)CGImage:(id)json CF_RETURNS_NOT_RETAINED;

@end

HEADER_EOF

###############################################################################
# 2. Create RCTConvert+UIKit.mm
###############################################################################

cat > "$UIKIT_IMPL" << 'IMPL_EOF'
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTConvert+UIKit.h"

#import <objc/message.h>

#import "RCTDefines.h"
#import "RCTImageSource.h"
#import "RCTParserUtils.h"
#import "RCTUtils.h"

@implementation RCTConvert (UIKit)

RCT_ENUM_CONVERTER(
    UITextAutocapitalizationType,
    (@{
      @"none" : @(UITextAutocapitalizationTypeNone),
      @"words" : @(UITextAutocapitalizationTypeWords),
      @"sentences" : @(UITextAutocapitalizationTypeSentences),
      @"characters" : @(UITextAutocapitalizationTypeAllCharacters)
    }),
    UITextAutocapitalizationTypeSentences,
    integerValue)

RCT_ENUM_CONVERTER(
    UITextFieldViewMode,
    (@{
      @"never" : @(UITextFieldViewModeNever),
      @"while-editing" : @(UITextFieldViewModeWhileEditing),
      @"unless-editing" : @(UITextFieldViewModeUnlessEditing),
      @"always" : @(UITextFieldViewModeAlways),
    }),
    UITextFieldViewModeNever,
    integerValue)

+ (UIKeyboardType)UIKeyboardType:(id)json RCT_DYNAMIC
{
  static NSDictionary<NSString *, NSNumber *> *mapping;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary<NSString *, NSNumber *> *temporaryMapping = [NSMutableDictionary dictionaryWithDictionary:@{
      @"default" : @(UIKeyboardTypeDefault),
      @"ascii-capable" : @(UIKeyboardTypeASCIICapable),
      @"numbers-and-punctuation" : @(UIKeyboardTypeNumbersAndPunctuation),
      @"url" : @(UIKeyboardTypeURL),
      @"number-pad" : @(UIKeyboardTypeNumberPad),
      @"phone-pad" : @(UIKeyboardTypePhonePad),
      @"name-phone-pad" : @(UIKeyboardTypeNamePhonePad),
      @"email-address" : @(UIKeyboardTypeEmailAddress),
      @"decimal-pad" : @(UIKeyboardTypeDecimalPad),
      @"twitter" : @(UIKeyboardTypeTwitter),
      @"web-search" : @(UIKeyboardTypeWebSearch),
      // Added for Android compatibility
      @"numeric" : @(UIKeyboardTypeDecimalPad),
    }];
    temporaryMapping[@"ascii-capable-number-pad"] = @(UIKeyboardTypeASCIICapableNumberPad);
    mapping = temporaryMapping;
  });

  UIKeyboardType type =
      (UIKeyboardType)RCTConvertEnumValue("UIKeyboardType", mapping, @(UIKeyboardTypeDefault), json).integerValue;
  return type;
}

RCT_MULTI_ENUM_CONVERTER(
    UIDataDetectorTypes,
    (@{
      @"phoneNumber" : @(UIDataDetectorTypePhoneNumber),
      @"link" : @(UIDataDetectorTypeLink),
      @"address" : @(UIDataDetectorTypeAddress),
      @"calendarEvent" : @(UIDataDetectorTypeCalendarEvent),
      @"trackingNumber" : @(UIDataDetectorTypeShipmentTrackingNumber),
      @"flightNumber" : @(UIDataDetectorTypeFlightNumber),
      @"lookupSuggestion" : @(UIDataDetectorTypeLookupSuggestion),
      @"none" : @(UIDataDetectorTypeNone),
      @"all" : @(UIDataDetectorTypeAll),
    }),
    UIDataDetectorTypePhoneNumber,
    unsignedLongLongValue)

RCT_ENUM_CONVERTER(
    UIKeyboardAppearance,
    (@{
      @"default" : @(UIKeyboardAppearanceDefault),
      @"light" : @(UIKeyboardAppearanceLight),
      @"dark" : @(UIKeyboardAppearanceDark),
    }),
    UIKeyboardAppearanceDefault,
    integerValue)

RCT_ENUM_CONVERTER(
    UIReturnKeyType,
    (@{
      @"default" : @(UIReturnKeyDefault),
      @"go" : @(UIReturnKeyGo),
      @"google" : @(UIReturnKeyGoogle),
      @"join" : @(UIReturnKeyJoin),
      @"next" : @(UIReturnKeyNext),
      @"route" : @(UIReturnKeyRoute),
      @"search" : @(UIReturnKeySearch),
      @"send" : @(UIReturnKeySend),
      @"yahoo" : @(UIReturnKeyYahoo),
      @"done" : @(UIReturnKeyDone),
      @"emergency-call" : @(UIReturnKeyEmergencyCall),
    }),
    UIReturnKeyDefault,
    integerValue)

RCT_ENUM_CONVERTER(
    UIUserInterfaceStyle,
    (@{
      @"unspecified" : @(UIUserInterfaceStyleUnspecified),
      @"light" : @(UIUserInterfaceStyleLight),
      @"dark" : @(UIUserInterfaceStyleDark),
    }),
    UIUserInterfaceStyleUnspecified,
    integerValue)

#if !TARGET_OS_TV
RCT_ENUM_CONVERTER(
    UIInterfaceOrientationMask,
    (@{
      @"ALL" : @(UIInterfaceOrientationMaskAll),
      @"PORTRAIT" : @(UIInterfaceOrientationMaskPortrait),
      @"LANDSCAPE" : @(UIInterfaceOrientationMaskLandscape),
      @"LANDSCAPE_LEFT" : @(UIInterfaceOrientationMaskLandscapeLeft),
      @"LANDSCAPE_RIGHT" : @(UIInterfaceOrientationMaskLandscapeRight),
    }),
    NSNotFound,
    unsignedIntegerValue)
#endif

RCT_ENUM_CONVERTER(
    UIModalPresentationStyle,
    (@{
      @"fullScreen" : @(UIModalPresentationFullScreen),
      @"pageSheet" : @(UIModalPresentationPageSheet),
      @"formSheet" : @(UIModalPresentationFormSheet),
      @"overFullScreen" : @(UIModalPresentationOverFullScreen),
    }),
    UIModalPresentationFullScreen,
    integerValue)

RCT_ENUM_CONVERTER(
    UIViewContentMode,
    (@{
      @"scale-to-fill" : @(UIViewContentModeScaleToFill),
      @"scale-aspect-fit" : @(UIViewContentModeScaleAspectFit),
      @"scale-aspect-fill" : @(UIViewContentModeScaleAspectFill),
      @"redraw" : @(UIViewContentModeRedraw),
      @"center" : @(UIViewContentModeCenter),
      @"top" : @(UIViewContentModeTop),
      @"bottom" : @(UIViewContentModeBottom),
      @"left" : @(UIViewContentModeLeft),
      @"right" : @(UIViewContentModeRight),
      @"top-left" : @(UIViewContentModeTopLeft),
      @"top-right" : @(UIViewContentModeTopRight),
      @"bottom-left" : @(UIViewContentModeBottomLeft),
      @"bottom-right" : @(UIViewContentModeBottomRight),
      // Cross-platform values
      @"cover" : @(UIViewContentModeScaleAspectFill),
      @"contain" : @(UIViewContentModeScaleAspectFit),
      @"stretch" : @(UIViewContentModeScaleToFill),
    }),
    UIViewContentModeScaleAspectFill,
    integerValue)

+ (UIEdgeInsets)UIEdgeInsets:(id)json
{
  static NSArray *fields;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    fields = @[ @"top", @"left", @"bottom", @"right" ];
  });

  if ([json isKindOfClass:[NSNumber class]]) {
    CGFloat value = [json doubleValue];
    return UIEdgeInsetsMake(value, value, value, value);
  } else {
    UIEdgeInsets result;
    convertCGStruct("UIEdgeInsets", fields, (CGFloat *)&result, json);
    return result;
  }
}

static NSString *const RCTFallback = @"fallback";
static NSString *const RCTFallbackARGB = @"fallback-argb";
static NSString *const RCTSelector = @"selector";
static NSString *const RCTIndex = @"index";

/** The following dictionary defines the react-native semantic colors for ios.
 *  If the value for a given name is empty then the name itself
 *  is used as the UIColor selector.
 *  If the RCTSelector key is present then that value is used for a selector instead
 *  of the key name.
 *  If the given selector is not available on the running OS version then
 *  the RCTFallback selector is used instead.
 *  If the RCTIndex key is present then object returned from UIColor is an
 *  NSArray and the object at index RCTIndex is to be used.
 */
static NSDictionary<NSString *, NSDictionary *> *RCTSemanticColorsMap(void)
{
  static NSDictionary<NSString *, NSDictionary *> *colorMap = nil;
  if (colorMap == nil) {
    NSMutableDictionary<NSString *, NSDictionary *> *map = [@{
      // https://developer.apple.com/documentation/uikit/uicolor/ui_element_colors
      // Label Colors
      @"labelColor" : @{
        // iOS 13.0
        RCTFallbackARGB :
            @(0xFF000000) // fallback for iOS<=12: RGBA returned by this semantic color in light mode on iOS 13
      },
      @"secondaryLabelColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x993c3c43)
      },
      @"tertiaryLabelColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x4c3c3c43)
      },
      @"quaternaryLabelColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x2d3c3c43)
      },
      // Fill Colors
      @"systemFillColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x33787880)
      },
      @"secondarySystemFillColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x28787880)
      },
      @"tertiarySystemFillColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x1e767680)
      },
      @"quaternarySystemFillColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x14747480)
      },
      // Text Colors
      @"placeholderTextColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x4c3c3c43)
      },
      // Standard Content Background Colors
      @"systemBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFffffff)
      },
      @"secondarySystemBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFf2f2f7)
      },
      @"tertiarySystemBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFffffff)
      },
      // Grouped Content Background Colors
      @"systemGroupedBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFf2f2f7)
      },
      @"secondarySystemGroupedBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFffffff)
      },
      @"tertiarySystemGroupedBackgroundColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFf2f2f7)
      },
      // Separator Colors
      @"separatorColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x493c3c43)
      },
      @"opaqueSeparatorColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFc6c6c8)
      },
      // Link Color
      @"linkColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFF007aff)
      },
      // Nonadaptable Colors
      @"darkTextColor" : @{},
      @"lightTextColor" : @{},
      // https://developer.apple.com/documentation/uikit/uicolor/standard_colors
      // Adaptable Colors
      @"systemBlueColor" : @{},
      @"systemBrownColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFa2845e)
      },
      @"systemCyanColor" : @{},
      @"systemGreenColor" : @{},
      @"systemIndigoColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFF5856d6)
      },
      @"systemMintColor" : @{},
      @"systemOrangeColor" : @{},
      @"systemPinkColor" : @{},
      @"systemPurpleColor" : @{},
      @"systemRedColor" : @{},
      @"systemTealColor" : @{},
      @"systemYellowColor" : @{},
      // Adaptable Gray Colors
      @"systemGrayColor" : @{},
      @"systemGray2Color" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFaeaeb2)
      },
      @"systemGray3Color" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFc7c7cc)
      },
      @"systemGray4Color" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFd1d1d6)
      },
      @"systemGray5Color" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFe5e5ea)
      },
      @"systemGray6Color" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0xFFf2f2f7)
      },
      // Transparent Color
      @"clearColor" : @{
        // iOS 13.0
        RCTFallbackARGB : @(0x00000000)
      },
    } mutableCopy];
    // The color names are the Objective-C UIColor selector names,
    // but Swift selector names are valid as well, so make aliases.
    static NSString *const RCTColorSuffix = @"Color";
    NSMutableDictionary<NSString *, NSDictionary *> *aliases = [NSMutableDictionary new];
    for (NSString *objcSelector in map) {
      RCTAssert(
          [objcSelector hasSuffix:RCTColorSuffix], @"A selector in the color map did not end with the suffix Color.");
      NSMutableDictionary *entry = [map[objcSelector] mutableCopy];
      RCTAssert([entry objectForKey:RCTSelector] == nil, @"Entry should not already have an RCTSelector");
      NSString *swiftSelector = [objcSelector substringToIndex:[objcSelector length] - [RCTColorSuffix length]];
      entry[RCTSelector] = objcSelector;
      aliases[swiftSelector] = entry;
    }
    [map addEntriesFromDictionary:aliases];
#if DEBUG
    [map addEntriesFromDictionary:@{
      // The follow exist for Unit Tests
      @"unitTestFallbackColor" : @{RCTFallback : @"gridColor"},
      @"unitTestFallbackColorIOS" : @{RCTFallback : @"blueColor"},
      @"unitTestFallbackColorEven" : @{
        RCTSelector : @"unitTestFallbackColorEven",
        RCTIndex : @0,
        RCTFallback : @"controlAlternatingRowBackgroundColors"
      },
      @"unitTestFallbackColorOdd" : @{
        RCTSelector : @"unitTestFallbackColorOdd",
        RCTIndex : @1,
        RCTFallback : @"controlAlternatingRowBackgroundColors"
      },
    }];
#endif
    colorMap = [map copy];
  }

  return colorMap;
}

/** Returns a UIColor based on a semantic color name.
 *  Returns nil if the semantic color name is invalid.
 */
static UIColor *RCTColorFromSemanticColorName(NSString *semanticColorName)
{
  NSDictionary<NSString *, NSDictionary *> *colorMap = RCTSemanticColorsMap();
  UIColor *color = nil;
  NSDictionary<NSString *, id> *colorInfo = colorMap[semanticColorName];
  if (colorInfo) {
    NSString *semanticColorSelector = colorInfo[RCTSelector];
    if (semanticColorSelector == nil) {
      semanticColorSelector = semanticColorName;
    }
    SEL selector = NSSelectorFromString(semanticColorSelector);
    if (![UIColor respondsToSelector:selector]) {
      NSNumber *fallbackRGB = colorInfo[RCTFallbackARGB];
      if (fallbackRGB != nil) {
        RCTAssert([fallbackRGB isKindOfClass:[NSNumber class]], @"fallback ARGB is not a number");
        return [RCTConvert UIColor:fallbackRGB];
      }
      semanticColorSelector = colorInfo[RCTFallback];
      selector = NSSelectorFromString(semanticColorSelector);
    }
    RCTAssert([UIColor respondsToSelector:selector], @"RCTUIColor does not respond to a semantic color selector.");
    Class klass = [UIColor class];
    IMP imp = [klass methodForSelector:selector];
    id (*getSemanticColorObject)(id, SEL) = (id (*)(id, SEL))imp;
    id colorObject = getSemanticColorObject(klass, selector);
    if ([colorObject isKindOfClass:[UIColor class]]) {
      color = colorObject;
    } else if ([colorObject isKindOfClass:[NSArray class]]) {
      NSArray *colors = colorObject;
      NSNumber *index = colorInfo[RCTIndex];
      RCTAssert(index, @"index should not be null");
      color = colors[[index unsignedIntegerValue]];
    } else {
      RCTAssert(false, @"selector return an unknown object type");
    }
  }
  return color;
}

/** Returns an alphabetically sorted comma separated list of the valid semantic color names
 */
static NSString *RCTSemanticColorNames(void)
{
  NSMutableString *names = [NSMutableString new];
  NSDictionary<NSString *, NSDictionary *> *colorMap = RCTSemanticColorsMap();
  NSArray *allKeys =
      [[[colorMap allKeys] mutableCopy] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

  for (id key in allKeys) {
    if ([names length]) {
      [names appendString:@", "];
    }
    [names appendString:key];
  }
  return names;
}

+ (UIColor *)UIColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
  RCTColorSpace space = RCTGetDefaultColorSpace();
  return [self UIColorWithRed:red green:green blue:blue alpha:alpha andColorSpace:space];
}
+ (UIColor *)UIColorWithRed:(CGFloat)red
                      green:(CGFloat)green
                       blue:(CGFloat)blue
                      alpha:(CGFloat)alpha
              andColorSpace:(RCTColorSpace)colorSpace
{
  if (colorSpace == RCTColorSpaceDisplayP3) {
    return [UIColor colorWithDisplayP3Red:red green:green blue:blue alpha:alpha];
  }
  return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (UIColor *)UIColor:(id)json
{
  if (!json) {
    return nil;
  }
  if ([json isKindOfClass:[NSArray class]]) {
    NSArray *components = [self NSNumberArray:json];
    CGFloat alpha = components.count > 3 ? [self CGFloat:components[3]] : 1.0;
    return [self UIColorWithRed:[self CGFloat:components[0]]
                          green:[self CGFloat:components[1]]
                           blue:[self CGFloat:components[2]]
                          alpha:alpha];
  } else if ([json isKindOfClass:[NSNumber class]]) {
    NSUInteger argb = [self NSUInteger:json];
    CGFloat a = ((argb >> 24) & 0xFF) / 255.0;
    CGFloat r = ((argb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((argb >> 8) & 0xFF) / 255.0;
    CGFloat b = (argb & 0xFF) / 255.0;
    return [self UIColorWithRed:r green:g blue:b alpha:a];
  } else if ([json isKindOfClass:[NSDictionary class]]) {
    NSDictionary *dictionary = json;
    id value = nil;
    NSString *rawColorSpace = [dictionary objectForKey:@"space"];
    if ([rawColorSpace isEqualToString:@"display-p3"] || [rawColorSpace isEqualToString:@"srgb"]) {
      CGFloat r = [[dictionary objectForKey:@"r"] floatValue];
      CGFloat g = [[dictionary objectForKey:@"g"] floatValue];
      CGFloat b = [[dictionary objectForKey:@"b"] floatValue];
      CGFloat a = [[dictionary objectForKey:@"a"] floatValue];
      RCTColorSpace colorSpace = [self RCTColorSpaceFromString:rawColorSpace];
      return [self UIColorWithRed:r green:g blue:b alpha:a andColorSpace:colorSpace];
    } else if ((value = [dictionary objectForKey:@"semantic"])) {
      if ([value isKindOfClass:[NSString class]]) {
        NSString *semanticName = value;
        UIColor *color = [UIColor colorNamed:semanticName];
        if (color != nil) {
          return color;
        }
        color = RCTColorFromSemanticColorName(semanticName);
        if (color == nil) {
          RCTLogConvertError(
              json,
              [@"a UIColor.  Expected one of the following values: " stringByAppendingString:RCTSemanticColorNames()]);
        }
        return color;
      } else if ([value isKindOfClass:[NSArray class]]) {
        for (id name in value) {
          UIColor *color = [UIColor colorNamed:name];
          if (color != nil) {
            return color;
          }
          color = RCTColorFromSemanticColorName(name);
          if (color != nil) {
            return color;
          }
        }
        RCTLogConvertError(
            json,
            [@"a UIColor.  None of the names in the array were one of the following values: "
                stringByAppendingString:RCTSemanticColorNames()]);
        return nil;
      }
      RCTLogConvertError(
          json, @"a UIColor.  Expected either a single name or an array of names but got something else.");
      return nil;
    } else if ((value = [dictionary objectForKey:@"dynamic"])) {
      NSDictionary *appearances = value;
      id light = [appearances objectForKey:@"light"];
      UIColor *lightColor = [RCTConvert UIColor:light];
      id dark = [appearances objectForKey:@"dark"];
      UIColor *darkColor = [RCTConvert UIColor:dark];
      id highContrastLight = [appearances objectForKey:@"highContrastLight"];
      UIColor *highContrastLightColor = [RCTConvert UIColor:highContrastLight];
      id highContrastDark = [appearances objectForKey:@"highContrastDark"];
      UIColor *highContrastDarkColor = [RCTConvert UIColor:highContrastDark];
      if (lightColor != nil && darkColor != nil) {
        UIColor *color = [UIColor colorWithDynamicProvider:^UIColor *_Nonnull(UITraitCollection *_Nonnull collection) {
          if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            if (collection.accessibilityContrast == UIAccessibilityContrastHigh && highContrastDarkColor != nil) {
              return highContrastDarkColor;
            } else {
              return darkColor;
            }
          } else {
            if (collection.accessibilityContrast == UIAccessibilityContrastHigh && highContrastLightColor != nil) {
              return highContrastLightColor;
            } else {
              return lightColor;
            }
          }
        }];
        return color;

      } else {
        RCTLogConvertError(json, @"a UIColor. Expected an iOS dynamic appearance aware color.");
        return nil;
      }
    } else {
      RCTLogConvertError(json, @"a UIColor. Expected an iOS semantic color or dynamic appearance aware color.");
      return nil;
    }
  } else {
    RCTLogConvertError(json, @"a UIColor. Did you forget to call processColor() on the JS side?");
    return nil;
  }
}

+ (CGColorRef)CGColor:(id)json
{
  return [self UIColor:json].CGColor;
}

RCT_ARRAY_CONVERTER(UIColor)

// Can't use RCT_ARRAY_CONVERTER due to bridged cast
+ (NSArray *)CGColorArray:(id)json
{
  NSMutableArray *colors = [NSMutableArray new];
  for (id value in [self NSArray:json]) {
    [colors addObject:(__bridge id)[self CGColor:value]];
  }
  return colors;
}

@end

@interface RCTImageSource (Packager)

@property (nonatomic, assign) BOOL packagerAsset;

@end

@implementation RCTConvert (Deprecated)

/* This method is only used when loading images synchronously, e.g. for tabbar icons */
+ (UIImage *)UIImage:(id)json
{
  if (!json) {
    return nil;
  }

  RCTImageSource *imageSource = [self RCTImageSource:json];
  if (!imageSource) {
    return nil;
  }

  __block UIImage *image;
  if (!RCTIsMainQueue()) {
    // It seems that none of the UIImage loading methods can be guaranteed
    // thread safe, so we'll pick the lesser of two evils here and block rather
    // than run the risk of crashing
    RCTLogWarn(@"Calling [RCTConvert UIImage:] on a background thread is not recommended");
    RCTUnsafeExecuteOnMainQueueSync(^{
      image = [self UIImage:json];
    });
    return image;
  }

  NSURL *URL = imageSource.request.URL;
  NSString *scheme = URL.scheme.lowercaseString;
  if ([scheme isEqualToString:@"file"]) {
    image = RCTImageFromLocalAssetURL(URL);
    // There is a case where this may fail when the image is at the bundle location.
    // RCTImageFromLocalAssetURL only checks for the image in the same location as the jsbundle
    // Hence, if the bundle is CodePush-ed, it will not be able to find the image.
    // This check is added here instead of being inside RCTImageFromLocalAssetURL, since
    // we don't want breaking changes to RCTImageFromLocalAssetURL, which is called in a lot of places
    // This is a deprecated method, and hence has the least impact on existing code. Basically,
    // instead of crashing the app, it tries one more location for the image.
    if (!image) {
      image = RCTImageFromLocalBundleAssetURL(URL);
    }
    if (!image) {
      RCTLogConvertError(json, @"an image. File not found.");
    }
  } else if ([scheme isEqualToString:@"data"]) {
    image = [UIImage imageWithData:[NSData dataWithContentsOfURL:URL]];
  } else if ([scheme isEqualToString:@"http"] && imageSource.packagerAsset) {
    image = [UIImage imageWithData:[NSData dataWithContentsOfURL:URL]];
  } else {
    RCTLogConvertError(json, @"an image. Only local files or data URIs are supported.");
    return nil;
  }

  CGFloat scale = imageSource.scale;
  if (!scale && imageSource.size.width) {
    // If no scale provided, set scale to image width / source width
    scale = CGImageGetWidth(image.CGImage) / imageSource.size.width;
  }

  if (scale) {
    image = [UIImage imageWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
  }

  if (!CGSizeEqualToSize(imageSource.size, CGSizeZero) && !CGSizeEqualToSize(imageSource.size, image.size)) {
    RCTLogInfo(
        @"Image source %@ size %@ does not match loaded image size %@.",
        URL.path.lastPathComponent,
        NSStringFromCGSize(imageSource.size),
        NSStringFromCGSize(image.size));
  }

  return image;
}

+ (CGImageRef)CGImage:(id)json
{
  return [self UIImage:json].CGImage;
}

@end
IMPL_EOF

###############################################################################
# 3. Modify RCTConvert.h -- remove UIKit method declarations, add compat import
###############################################################################

TMPFILE=$(mktemp)
python3 -c "
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    lines = f.readlines()

output = []
i = 0
while i < len(lines):
    line = lines[i]

    # Skip single-line UIKit enum declarations
    if any(t in line for t in [
        'UITextAutocapitalizationType)UITextAutocapitalizationType:',
        'UITextFieldViewMode)UITextFieldViewMode:',
        'UIKeyboardType)UIKeyboardType:',
        'UIKeyboardAppearance)UIKeyboardAppearance:',
        'UIReturnKeyType)UIReturnKeyType:',
        'UIUserInterfaceStyle)UIUserInterfaceStyle:',
        'UIModalPresentationStyle)UIModalPresentationStyle:',
        'UIViewContentMode)UIViewContentMode:',
        'UIEdgeInsets)UIEdgeInsets:',
    ]):
        i += 1
        continue

    # Skip #if !TARGET_OS_TV blocks containing UIKit types
    if line.strip() == '#if !TARGET_OS_TV':
        j = i + 1
        while j < len(lines) and lines[j].strip() != '#endif':
            j += 1
        block_content = ''.join(lines[i+1:j])
        if 'UIInterfaceOrientationMask' in block_content or 'UIDataDetectorTypes' in block_content:
            i = j + 1
            # Skip trailing blank line
            while i < len(lines) and lines[i].strip() == '':
                i += 1
            continue

    # Skip multi-line UIColorWithRed declarations
    if '+ (UIColor *)UIColorWithRed:' in line:
        if line.rstrip().endswith(';'):
            i += 1
            continue
        else:
            while i < len(lines) and not lines[i].rstrip().endswith(';'):
                i += 1
            i += 1
            continue

    # Skip UIColor: and CGColor: declarations
    if '+ (UIColor *)UIColor:(id)json;' in line:
        i += 1
        continue
    if '+ (CGColorRef)CGColor:(id)json' in line:
        i += 1
        continue

    # Skip UIColorArray declaration
    if 'UIColorArray:(id)json;' in line and 'NSArray<UIColor' in line:
        i += 1
        continue

    # Skip CGColorArray typedef and declaration
    if line.strip() == 'typedef NSArray CGColorArray;':
        i += 1
        continue
    if '+ (CGColorArray *)CGColorArray:(id)json;' in line:
        i += 1
        continue

    # Skip the entire Deprecated category block (it moves to +UIKit.h)
    if '@interface RCTConvert (Deprecated)' in line:
        while i < len(lines) and lines[i].strip() != '@end':
            i += 1
        i += 1  # skip @end
        # Also skip trailing blank line
        while i < len(lines) and lines[i].strip() == '':
            i += 1
        continue

    output.append(line)
    i += 1

# Insert compat re-export after the main @end
final_output = []
main_end_found = False
for line in output:
    final_output.append(line)
    if not main_end_found and line.strip() == '@end':
        main_end_found = True
        final_output.append('\n')
        final_output.append('// Compatibility: re-export UIKit category so existing importers\n')
        final_output.append('// of <React/RCTConvert.h> continue to get UIKit methods.\n')
        final_output.append('#import <React/RCTConvert+UIKit.h>\n')

with open(sys.argv[2], 'w') as f:
    f.writelines(final_output)
" "$HEADER" "$TMPFILE"
mv "$TMPFILE" "$HEADER"
echo "Modified $HEADER"

###############################################################################
# 4. Modify RCTConvert.mm -- remove UIKit method implementations
###############################################################################

TMPFILE=$(mktemp)
python3 -c "
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

lines = content.split('\n')
output = []
i = 0
n = len(lines)

def skip_rct_enum_converter(start):
    j = start
    paren_depth = 0
    while j < n:
        for ch in lines[j]:
            if ch == '(':
                paren_depth += 1
            elif ch == ')':
                paren_depth -= 1
        if paren_depth <= 0:
            return j + 1
        j += 1
    return j

def skip_method_block(start):
    j = start
    brace_depth = 0
    found_open = False
    while j < n:
        for ch in lines[j]:
            if ch == '{':
                brace_depth += 1
                found_open = True
            elif ch == '}':
                brace_depth -= 1
        if found_open and brace_depth <= 0:
            return j + 1
        j += 1
    return j

while i < n:
    line = lines[i]

    # Skip RCT_ENUM_CONVERTER / RCT_MULTI_ENUM_CONVERTER for UIKit types
    if 'RCT_ENUM_CONVERTER(' in line or 'RCT_MULTI_ENUM_CONVERTER(' in line:
        peek = '\n'.join(lines[i:min(i+3, n)])
        uikit_enums = [
            'UITextAutocapitalizationType',
            'UITextFieldViewMode',
            'UIKeyboardAppearance',
            'UIReturnKeyType',
            'UIUserInterfaceStyle',
            'UIInterfaceOrientationMask',
            'UIModalPresentationStyle',
            'UIViewContentMode',
            'UIDataDetectorTypes',
        ]
        if any(e in peek for e in uikit_enums):
            i = skip_rct_enum_converter(i)
            while i < n and lines[i].strip() == '':
                i += 1
            continue

    # Skip #if !TARGET_OS_TV blocks with UIKit content
    if line.strip() == '#if !TARGET_OS_TV':
        j = i + 1
        end_j = j
        while end_j < n and lines[end_j].strip() != '#endif':
            end_j += 1
        block = '\n'.join(lines[i:end_j+1])
        if 'UIInterfaceOrientationMask' in block or 'UIDataDetectorTypes' in block:
            i = end_j + 1
            while i < n and lines[i].strip() == '':
                i += 1
            continue

    # Skip UIKeyboardType method
    if '+ (UIKeyboardType)UIKeyboardType:' in line:
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip UIEdgeInsets method
    if '+ (UIEdgeInsets)UIEdgeInsets:' in line:
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip static color string constants (RCTFallback etc.)
    if line.startswith('static NSString *const RCTFallback ') or line.startswith('static NSString *const RCTFallbackARGB ') or line.startswith('static NSString *const RCTSelector ') or line.startswith('static NSString *const RCTIndex '):
        i += 1
        while i < n and lines[i].startswith('static NSString *const RCT'):
            i += 1
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip RCTSemanticColorsMap function and its preceding comment
    if 'static NSDictionary<NSString *, NSDictionary *> *RCTSemanticColorsMap' in line:
        # Remove preceding comment block
        while output and (output[-1].strip().startswith('/**') or output[-1].strip().startswith('*') or output[-1].strip() == ''):
            output.pop()
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip RCTColorFromSemanticColorName function and its preceding comment
    if 'static UIColor *RCTColorFromSemanticColorName' in line:
        while output and (output[-1].strip().startswith('/**') or output[-1].strip().startswith('*') or output[-1].strip() == ''):
            output.pop()
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip RCTSemanticColorNames function and its preceding comment
    if 'static NSString *RCTSemanticColorNames' in line:
        while output and (output[-1].strip().startswith('/**') or output[-1].strip().startswith('*') or output[-1].strip() == ''):
            output.pop()
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip UIColorWithRed methods (two consecutive)
    if '+ (UIColor *)UIColorWithRed:' in line:
        i = skip_method_block(i)
        if i < n and '+ (UIColor *)UIColorWithRed:' in lines[i]:
            i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip UIColor: method
    if line.startswith('+ (UIColor *)UIColor:(id)json'):
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip CGColor: method
    if '+ (CGColorRef)CGColor:(id)json' in line:
        i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip RCT_ARRAY_CONVERTER(UIColor)
    if line.strip() == 'RCT_ARRAY_CONVERTER(UIColor)':
        i += 1
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip CGColorArray method and its comment
    if line.strip() == \"// Can't use RCT_ARRAY_CONVERTER due to bridged cast\":
        i += 1  # skip comment
        if i < n and '+ (NSArray *)CGColorArray:' in lines[i]:
            i = skip_method_block(i)
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip @interface RCTImageSource (Packager)
    if '@interface RCTImageSource (Packager)' in line:
        while i < n and lines[i].strip() != '@end':
            i += 1
        i += 1  # skip @end
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    # Skip @implementation RCTConvert (Deprecated) through its @end
    if '@implementation RCTConvert (Deprecated)' in line:
        # Find the matching @end (last @end in the file for this impl)
        depth = 0
        while i < n:
            if lines[i].strip() == '@end':
                break
            i += 1
        i += 1  # skip @end
        while i < n and lines[i].strip() == '':
            i += 1
        continue

    output.append(line)
    i += 1

with open(sys.argv[2], 'w') as f:
    f.write('\n'.join(output))
" "$IMPL" "$TMPFILE"
mv "$TMPFILE" "$IMPL"
echo "Modified $IMPL"

echo "Codemod complete. Created:"
echo "  $UIKIT_HEADER"
echo "  $UIKIT_IMPL"
echo "Modified:"
echo "  $HEADER"
echo "  $IMPL"
