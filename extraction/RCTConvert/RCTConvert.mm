/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTConvert.h"

#import <objc/message.h>

#import <CoreText/CoreText.h>

#import "RCTDefines.h"
#import "RCTImageSource.h"
#import "RCTParserUtils.h"
#import "RCTUtils.h"

@implementation RCTConvert

RCT_CONVERTER(id, id, self)

RCT_CONVERTER(BOOL, BOOL, boolValue)
RCT_NUMBER_CONVERTER(double, doubleValue)
RCT_NUMBER_CONVERTER(float, floatValue)
RCT_NUMBER_CONVERTER(int, intValue)

RCT_NUMBER_CONVERTER(int64_t, longLongValue);
RCT_NUMBER_CONVERTER(uint64_t, unsignedLongLongValue);

RCT_NUMBER_CONVERTER(NSInteger, integerValue)
RCT_NUMBER_CONVERTER(NSUInteger, unsignedIntegerValue)

/**
 * This macro is used for creating converter functions for directly
 * representable json values that require no conversion.
 */
#if RCT_DEBUG
#define RCT_JSON_CONVERTER(type)             \
  +(type *)type : (id)json                   \
  {                                          \
    if ([json isKindOfClass:[type class]]) { \
      return json;                           \
    } else if (json) {                       \
      RCTLogConvertError(json, @ #type);     \
    }                                        \
    return nil;                              \
  }
#else
#define RCT_JSON_CONVERTER(type) \
  +(type *)type : (id)json       \
  {                              \
    return json;                 \
  }
#endif

RCT_JSON_CONVERTER(NSArray)
RCT_JSON_CONVERTER(NSDictionary)
RCT_JSON_CONVERTER(NSString)
RCT_JSON_CONVERTER(NSNumber)

RCT_CUSTOM_CONVERTER(NSSet *, NSSet, [NSSet setWithArray:json])
RCT_CUSTOM_CONVERTER(NSData *, NSData, [json dataUsingEncoding:NSUTF8StringEncoding])

+ (NSIndexSet *)NSIndexSet:(id)json
{
  json = [self NSNumberArray:json];
  NSMutableIndexSet *indexSet = [NSMutableIndexSet new];
  for (NSNumber *number in json) {
    NSInteger index = number.integerValue;
    if (RCT_DEBUG && index < 0) {
      RCTLogInfo(@"Invalid index value %lld. Indices must be positive.", (long long)index);
    }
    [indexSet addIndex:index];
  }
  return indexSet;
}

+ (NSURL *)NSURL:(id)json
{
  NSString *path = [self NSString:RCTNilIfNull(json)];
  if (!path) {
    return nil;
  }

  @try { // NSURL has a history of crashing with bad input, so let's be safe
    NSURL *URL = [NSURL URLWithString:path];
    if (URL.scheme) { // Was a well-formed absolute URL
      return URL;
    }

    // Check if it has a scheme
    if ([path rangeOfString:@"://"].location != NSNotFound) {
      NSMutableCharacterSet *urlAllowedCharacterSet = [NSMutableCharacterSet new];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLUserAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLPasswordAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLHostAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLPathAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLFragmentAllowedCharacterSet]];
      path = [path stringByAddingPercentEncodingWithAllowedCharacters:urlAllowedCharacterSet];
      URL = [NSURL URLWithString:path];
      if (URL) {
        return URL;
      }
    }

    // Assume that it's a local path
    path = path.stringByRemovingPercentEncoding;
    if ([path hasPrefix:@"~"]) {
      // Path is inside user directory
      path = path.stringByExpandingTildeInPath;
    } else if (!path.absolutePath) {
      // Assume it's a resource path
      path = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:path];
    }
    if (!(URL = [NSURL fileURLWithPath:path])) {
      RCTLogConvertError(json, @"a valid URL");
    }
    return URL;
  } @catch (__unused NSException *e) {
    RCTLogConvertError(json, @"a valid URL");
    return nil;
  }
}

RCT_ENUM_CONVERTER(
    NSURLRequestCachePolicy,
    (@{
      @"default" : @(NSURLRequestUseProtocolCachePolicy),
      @"reload" : @(NSURLRequestReloadIgnoringLocalCacheData),
      @"force-cache" : @(NSURLRequestReturnCacheDataElseLoad),
      @"only-if-cached" : @(NSURLRequestReturnCacheDataDontLoad),
    }),
    NSURLRequestUseProtocolCachePolicy,
    integerValue)

+ (NSURLRequest *)NSURLRequest:(id)json
{
  if ([json isKindOfClass:[NSString class]]) {
    NSURL *URL = [self NSURL:json];
    return URL ? [NSURLRequest requestWithURL:URL] : nil;
  }
  if ([json isKindOfClass:[NSDictionary class]]) {
    NSString *URLString = json[@"uri"] ?: json[@"url"];

    NSURL *URL;
    NSString *bundleName = json[@"bundle"];
    if (bundleName) {
      URLString = [NSString stringWithFormat:@"%@.bundle/%@", bundleName, URLString];
    }

    URL = [self NSURL:URLString];
    if (!URL) {
      return nil;
    }

    NSData *body = [self NSData:json[@"body"]];
    NSString *method = [self NSString:json[@"method"]].uppercaseString ?: @"GET";
    NSURLRequestCachePolicy cachePolicy = [self NSURLRequestCachePolicy:json[@"cache"]];
    NSDictionary *headers = [self NSDictionary:json[@"headers"]];
    if ([method isEqualToString:@"GET"] && headers == nil && body == nil &&
        cachePolicy == NSURLRequestUseProtocolCachePolicy) {
      return [NSURLRequest requestWithURL:URL];
    }

    if (headers) {
      __block BOOL allHeadersAreStrings = YES;
      [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, id header, BOOL *stop) {
        if (![header isKindOfClass:[NSString class]]) {
          RCTLogInfo(
              @"Values of HTTP headers passed must be  of type string. "
               "Value of header '%@' is not a string.",
              key);
          allHeadersAreStrings = NO;
          *stop = YES;
        }
      }];
      if (!allHeadersAreStrings) {
        // Set headers to nil here to avoid crashing later.
        headers = nil;
      }
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPBody = body;
    request.HTTPMethod = method;
    request.cachePolicy = cachePolicy;
    request.allHTTPHeaderFields = headers;
    return [request copy];
  }
  if (json) {
    RCTLogConvertError(json, @"a valid URLRequest");
  }
  return nil;
}

+ (RCTFileURL *)RCTFileURL:(id)json
{
  NSURL *fileURL = [self NSURL:json];
  if (!fileURL.fileURL) {
    RCTLogInfo(@"URI must be a local file, '%@' isn't.", fileURL);
    return nil;
  }
  if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
    RCTLogInfo(@"File '%@' could not be found.", fileURL);
    return nil;
  }
  return fileURL;
}

+ (NSDate *)NSDate:(id)json
{
  if ([json isKindOfClass:[NSNumber class]]) {
    return [NSDate dateWithTimeIntervalSince1970:[self NSTimeInterval:json]];
  } else if ([json isKindOfClass:[NSString class]]) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      formatter = [NSDateFormatter new];
      formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
      formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
      formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    });
    NSDate *date = [formatter dateFromString:json];
    if (!date) {
      RCTLogInfo(
          @"JSON String '%@' could not be interpreted as a date. "
           "Expected format: YYYY-MM-DD'T'HH:mm:ss.sssZ",
          json);
    }
    return date;
  } else if (json) {
    RCTLogConvertError(json, @"a date");
  }
  return nil;
}

+ (NSLocale *)NSLocale:(id)json
{
  if ([json isKindOfClass:[NSString class]]) {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:json];
    if (!locale) {
      RCTLogInfo(@"JSON String '%@' could not be interpreted as a valid locale. ", json);
    }
    return locale;
  } else if (json) {
    RCTLogConvertError(json, @"a locale");
  }
  return nil;
}

// JS Standard for time is milliseconds
RCT_CUSTOM_CONVERTER(NSTimeInterval, NSTimeInterval, [self double:json] / 1000.0)

// JS standard for time zones is minutes.
RCT_CUSTOM_CONVERTER(NSTimeZone *, NSTimeZone, [NSTimeZone timeZoneForSecondsFromGMT:[self double:json] * 60.0])

NSNumber *RCTConvertEnumValue(const char *typeName, NSDictionary *mapping, NSNumber *defaultValue, id json)
{
  if (!json) {
    return defaultValue;
  }
  if ([json isKindOfClass:[NSNumber class]]) {
    NSArray *allValues = mapping.allValues;
    if ([allValues containsObject:json] || [json isEqual:defaultValue]) {
      return json;
    }
    RCTLogInfo(@"Invalid %s '%@'. should be one of: %@", typeName, json, allValues);
    return defaultValue;
  }
  if (RCT_DEBUG && ![json isKindOfClass:[NSString class]]) {
    RCTLogInfo(@"Expected NSNumber or NSString for %s, received %@: %@", typeName, [json classForCoder], json);
  }
  id value = mapping[json];
  if (RCT_DEBUG && !value && [json description].length > 0) {
    RCTLogInfo(
        @"Invalid %s '%@'. should be one of: %@",
        typeName,
        json,
        [[mapping allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]);
  }
  return value ?: defaultValue;
}

NSNumber *RCTConvertMultiEnumValue(const char *typeName, NSDictionary *mapping, NSNumber *defaultValue, id json)
{
  if ([json isKindOfClass:[NSArray class]]) {
    if ([json count] == 0) {
      return defaultValue;
    }
    long long result = 0;
    for (id arrayElement in json) {
      NSNumber *value = RCTConvertEnumValue(typeName, mapping, defaultValue, arrayElement);
      result |= value.longLongValue;
    }
    return @(result);
  }
  return RCTConvertEnumValue(typeName, mapping, defaultValue, json);
}

RCT_ENUM_CONVERTER(
    NSLineBreakMode,
    (@{
      @"clip" : @(NSLineBreakByClipping),
      @"head" : @(NSLineBreakByTruncatingHead),
      @"tail" : @(NSLineBreakByTruncatingTail),
      @"middle" : @(NSLineBreakByTruncatingMiddle),
      @"wordWrapping" : @(NSLineBreakByWordWrapping),
      @"char" : @(NSLineBreakByCharWrapping),
    }),
    NSLineBreakByTruncatingTail,
    integerValue)

RCT_ENUM_CONVERTER(
    NSTextAlignment,
    (@{
      @"auto" : @(NSTextAlignmentNatural),
      @"left" : @(NSTextAlignmentLeft),
      @"center" : @(NSTextAlignmentCenter),
      @"right" : @(NSTextAlignmentRight),
      @"justify" : @(NSTextAlignmentJustified),
    }),
    NSTextAlignmentNatural,
    integerValue)

RCT_ENUM_CONVERTER(
    NSUnderlineStyle,
    (@{
      @"solid" : @(NSUnderlineStyleSingle),
      @"double" : @(NSUnderlineStyleDouble),
      @"dotted" : @(NSUnderlinePatternDot | NSUnderlineStyleSingle),
      @"dashed" : @(NSUnderlinePatternDash | NSUnderlineStyleSingle),
    }),
    NSUnderlineStyleSingle,
    integerValue)

RCT_ENUM_CONVERTER(
    RCTBorderStyle,
    (@{
      @"solid" : @(RCTBorderStyleSolid),
      @"dotted" : @(RCTBorderStyleDotted),
      @"dashed" : @(RCTBorderStyleDashed),
    }),
    RCTBorderStyleSolid,
    integerValue)

RCT_ENUM_CONVERTER(
    RCTBorderCurve,
    (@{
      @"circular" : @(RCTBorderCurveCircular),
      @"continuous" : @(RCTBorderCurveContinuous),
    }),
    RCTBorderCurveCircular,
    integerValue)

RCT_ENUM_CONVERTER(
    RCTTextDecorationLineType,
    (@{
      @"none" : @(RCTTextDecorationLineTypeNone),
      @"underline" : @(RCTTextDecorationLineTypeUnderline),
      @"line-through" : @(RCTTextDecorationLineTypeStrikethrough),
      @"underline line-through" : @(RCTTextDecorationLineTypeUnderlineStrikethrough),
    }),
    RCTTextDecorationLineTypeNone,
    integerValue)

RCT_ENUM_CONVERTER(
    NSWritingDirection,
    (@{
      @"auto" : @(NSWritingDirectionNatural),
      @"ltr" : @(NSWritingDirectionLeftToRight),
      @"rtl" : @(NSWritingDirectionRightToLeft),
    }),
    NSWritingDirectionNatural,
    integerValue)

+ (NSLineBreakStrategy)NSLineBreakStrategy:(id)json RCT_DYNAMIC
{
  if (@available(iOS 14.0, *)) {
    static NSDictionary *mapping;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      mapping = @{
        @"none" : @(NSLineBreakStrategyNone),
        @"standard" : @(NSLineBreakStrategyStandard),
        @"hangul-word" : @(NSLineBreakStrategyHangulWordPriority),
        @"push-out" : @(NSLineBreakStrategyPushOut)
      };
    });
    return RCTConvertEnumValue("NSLineBreakStrategy", mapping, @(NSLineBreakStrategyNone), json).integerValue;
  } else {
    return NSLineBreakStrategyNone;
  }
}

RCT_ENUM_CONVERTER(
    RCTCursor,
    (@{
      @"auto" : @(RCTCursorAuto),
      @"pointer" : @(RCTCursorPointer),
    }),
    RCTCursorAuto,
    integerValue)

static void convertCGStruct(const char *type, NSArray *fields, CGFloat *result, id json)
{
  NSUInteger count = fields.count;
  if ([json isKindOfClass:[NSArray class]]) {
    if (RCT_DEBUG && [json count] != count) {
      RCTLogInfo(
          @"Expected array with count %llu, but count is %llu: %@",
          (unsigned long long)count,
          (unsigned long long)[json count],
          json);
    } else {
      for (NSUInteger i = 0; i < count; i++) {
        result[i] = [RCTConvert CGFloat:RCTNilIfNull(json[i])];
      }
    }
  } else if ([json isKindOfClass:[NSDictionary class]]) {
    for (NSUInteger i = 0; i < count; i++) {
      result[i] = [RCTConvert CGFloat:RCTNilIfNull(json[fields[i]])];
    }
  } else if (json) {
    RCTLogConvertError(json, @(type));
  }
}

/**
 * This macro is used for creating converter functions for structs that consist
 * of a number of CGFloat properties, such as CGPoint, CGRect, etc.
 */
#define RCT_CGSTRUCT_CONVERTER(type, values)                  \
  +(type)type : (id)json                                      \
  {                                                           \
    static NSArray *fields;                                   \
    static dispatch_once_t onceToken;                         \
    dispatch_once(&onceToken, ^{                              \
      fields = values;                                        \
    });                                                       \
    type result;                                              \
    convertCGStruct(#type, fields, (CGFloat *)&result, json); \
    return result;                                            \
  }

RCT_CUSTOM_CONVERTER(CGFloat, CGFloat, [self double:json])

RCT_CGSTRUCT_CONVERTER(CGPoint, (@[ @"x", @"y" ]))
RCT_CGSTRUCT_CONVERTER(CGSize, (@[ @"width", @"height" ]))
RCT_CGSTRUCT_CONVERTER(CGRect, (@[ @"x", @"y", @"width", @"height" ]))

RCT_ENUM_CONVERTER(
    CGLineJoin,
    (@{
      @"miter" : @(kCGLineJoinMiter),
      @"round" : @(kCGLineJoinRound),
      @"bevel" : @(kCGLineJoinBevel),
    }),
    kCGLineJoinMiter,
    intValue)

RCT_ENUM_CONVERTER(
    CGLineCap,
    (@{
      @"butt" : @(kCGLineCapButt),
      @"round" : @(kCGLineCapRound),
      @"square" : @(kCGLineCapSquare),
    }),
    kCGLineCapButt,
    intValue)

RCT_CGSTRUCT_CONVERTER(CGAffineTransform, (@[ @"a", @"b", @"c", @"d", @"tx", @"ty" ]))

// The iOS side is kept in synch with the C++ side by using the
// RCTAppDelegate which, at startup, sets the default color space.
// The usage of dispatch_once and of once_flag ensoure that those are
// set only once when the app starts and that they can't change while
// the app is running.
static RCTColorSpace _defaultColorSpace = RCTColorSpaceSRGB;
RCTColorSpace RCTGetDefaultColorSpace(void)
{
  return _defaultColorSpace;
}
void RCTSetDefaultColorSpace(RCTColorSpace colorSpace)
{
  _defaultColorSpace = colorSpace;
}

+ (RCTColorSpace)RCTColorSpaceFromString:(NSString *)colorSpace
{
  if ([colorSpace isEqualToString:@"display-p3"]) {
    return RCTColorSpaceDisplayP3;
  } else if ([colorSpace isEqualToString:@"srgb"]) {
    return RCTColorSpaceSRGB;
  }
  return RCTGetDefaultColorSpace();
}

+ (YGValue)YGValue:(id)json
{
  if (!json) {
    return YGValueUndefined;
  } else if ([json isKindOfClass:[NSNumber class]]) {
    return (YGValue){[json floatValue], YGUnitPoint};
  } else if ([json isKindOfClass:[NSString class]]) {
    NSString *s = (NSString *)json;
    if ([s isEqualToString:@"auto"]) {
      return (YGValue){YGUndefined, YGUnitAuto};
    } else if ([s hasSuffix:@"%"]) {
      float floatValue;
      if ([[NSScanner scannerWithString:s] scanFloat:&floatValue]) {
        return (YGValue){floatValue, YGUnitPercent};
      }
    } else {
      RCTLogAdvice(
          @"\"%@\" is not a valid dimension. Dimensions must be a number, \"auto\", or a string suffixed with \"%%\".",
          s);
    }
  }
  return YGValueUndefined;
}

NSArray *RCTConvertArrayValue(SEL type, id json)
{
  __block BOOL copy = NO;
  __block NSArray *values = json = [RCTConvert NSArray:json];
  [json enumerateObjectsUsingBlock:^(id jsonValue, NSUInteger idx, __unused BOOL *stop) {
    id value = ((id (*)(Class, SEL, id))objc_msgSend)([RCTConvert class], type, jsonValue);
    if (copy) {
      if (value) {
        [(NSMutableArray *)values addObject:value];
      }
    } else if (value != jsonValue) {
      // Converted value is different, so we'll need to copy the array
      values = [[NSMutableArray alloc] initWithCapacity:values.count];
      for (NSUInteger i = 0; i < idx; i++) {
        [(NSMutableArray *)values addObject:json[i]];
      }
      if (value) {
        [(NSMutableArray *)values addObject:value];
      }
      copy = YES;
    }
  }];
  return values;
}

RCT_ARRAY_CONVERTER(NSURL)
RCT_ARRAY_CONVERTER(RCTFileURL)

/**
 * This macro is used for creating converter functions for directly
 * representable json array values that require no conversion.
 */
#if RCT_DEBUG
#define RCT_JSON_ARRAY_CONVERTER_NAMED(type, name) RCT_ARRAY_CONVERTER_NAMED(type, name)
#else
#define RCT_JSON_ARRAY_CONVERTER_NAMED(type, name) \
  +(NSArray *)name##Array : (id)json               \
  {                                                \
    return json;                                   \
  }
#endif
#define RCT_JSON_ARRAY_CONVERTER(type) RCT_JSON_ARRAY_CONVERTER_NAMED(type, type)

RCT_JSON_ARRAY_CONVERTER(NSArray)
RCT_JSON_ARRAY_CONVERTER(NSString)
RCT_JSON_ARRAY_CONVERTER_NAMED(NSArray<NSString *>, NSStringArray)
RCT_JSON_ARRAY_CONVERTER(NSDictionary)
RCT_JSON_ARRAY_CONVERTER(NSNumber)

static id RCTConvertPropertyListValue(id json)
{
  if (!json || json == (id)kCFNull) {
    return nil;
  }

  if ([json isKindOfClass:[NSDictionary class]]) {
    __block BOOL copy = NO;
    NSMutableDictionary *values = [[NSMutableDictionary alloc] initWithCapacity:[json count]];
    [json enumerateKeysAndObjectsUsingBlock:^(NSString *key, id jsonValue, __unused BOOL *stop) {
      id value = RCTConvertPropertyListValue(jsonValue);
      if (value) {
        values[key] = value;
      }
      copy |= value != jsonValue;
    }];
    return copy ? values : json;
  }

  if ([json isKindOfClass:[NSArray class]]) {
    __block BOOL copy = NO;
    __block NSArray *values = json;
    [json enumerateObjectsUsingBlock:^(id jsonValue, NSUInteger idx, __unused BOOL *stop) {
      id value = RCTConvertPropertyListValue(jsonValue);
      if (copy) {
        if (value) {
          [(NSMutableArray *)values addObject:value];
        }
      } else if (value != jsonValue) {
        // Converted value is different, so we'll need to copy the array
        values = [[NSMutableArray alloc] initWithCapacity:values.count];
        for (NSUInteger i = 0; i < idx; i++) {
          [(NSMutableArray *)values addObject:json[i]];
        }
        if (value) {
          [(NSMutableArray *)values addObject:value];
        }
        copy = YES;
      }
    }];
    return values;
  }

  // All other JSON types are supported by property lists
  return json;
}

+ (NSPropertyList)NSPropertyList:(id)json
{
  return RCTConvertPropertyListValue(json);
}

RCT_ENUM_CONVERTER(css_backface_visibility_t, (@{@"hidden" : @NO, @"visible" : @YES}), YES, boolValue)

RCT_ENUM_CONVERTER(
    YGOverflow,
    (@{
      @"hidden" : @(YGOverflowHidden),
      @"visible" : @(YGOverflowVisible),
      @"scroll" : @(YGOverflowScroll),
    }),
    YGOverflowVisible,
    intValue)

RCT_ENUM_CONVERTER(
    YGDisplay,
    (@{
      @"flex" : @(YGDisplayFlex),
      @"none" : @(YGDisplayNone),
    }),
    YGDisplayFlex,
    intValue)

RCT_ENUM_CONVERTER(
    YGFlexDirection,
    (@{
      @"row" : @(YGFlexDirectionRow),
      @"row-reverse" : @(YGFlexDirectionRowReverse),
      @"column" : @(YGFlexDirectionColumn),
      @"column-reverse" : @(YGFlexDirectionColumnReverse)
    }),
    YGFlexDirectionColumn,
    intValue)

RCT_ENUM_CONVERTER(
    YGJustify,
    (@{
      @"flex-start" : @(YGJustifyFlexStart),
      @"flex-end" : @(YGJustifyFlexEnd),
      @"center" : @(YGJustifyCenter),
      @"space-between" : @(YGJustifySpaceBetween),
      @"space-around" : @(YGJustifySpaceAround),
      @"space-evenly" : @(YGJustifySpaceEvenly)
    }),
    YGJustifyFlexStart,
    intValue)

RCT_ENUM_CONVERTER(
    YGAlign,
    (@{
      @"flex-start" : @(YGAlignFlexStart),
      @"flex-end" : @(YGAlignFlexEnd),
      @"center" : @(YGAlignCenter),
      @"auto" : @(YGAlignAuto),
      @"stretch" : @(YGAlignStretch),
      @"baseline" : @(YGAlignBaseline),
      @"space-between" : @(YGAlignSpaceBetween),
      @"space-around" : @(YGAlignSpaceAround),
      @"space-evenly" : @(YGAlignSpaceEvenly)
    }),
    YGAlignFlexStart,
    intValue)

RCT_ENUM_CONVERTER(
    YGDirection,
    (@{
      @"inherit" : @(YGDirectionInherit),
      @"ltr" : @(YGDirectionLTR),
      @"rtl" : @(YGDirectionRTL),
    }),
    YGDirectionInherit,
    intValue)

RCT_ENUM_CONVERTER(
    YGPositionType,
    (@{@"absolute" : @(YGPositionTypeAbsolute), @"relative" : @(YGPositionTypeRelative)}),
    YGPositionTypeRelative,
    intValue)

RCT_ENUM_CONVERTER(
    YGWrap,
    (@{@"wrap" : @(YGWrapWrap), @"nowrap" : @(YGWrapNoWrap), @"wrap-reverse" : @(YGWrapWrapReverse)}),
    YGWrapNoWrap,
    intValue)

RCT_ENUM_CONVERTER(
    RCTPointerEvents,
    (@{
      @"none" : @(RCTPointerEventsNone),
      @"box-only" : @(RCTPointerEventsBoxOnly),
      @"box-none" : @(RCTPointerEventsBoxNone),
      @"auto" : @(RCTPointerEventsUnspecified)
    }),
    RCTPointerEventsUnspecified,
    integerValue)

RCT_ENUM_CONVERTER(
    RCTAnimationType,
    (@{
      @"spring" : @(RCTAnimationTypeSpring),
      @"linear" : @(RCTAnimationTypeLinear),
      @"easeIn" : @(RCTAnimationTypeEaseIn),
      @"easeOut" : @(RCTAnimationTypeEaseOut),
      @"easeInEaseOut" : @(RCTAnimationTypeEaseInEaseOut),
      @"keyboard" : @(RCTAnimationTypeKeyboard),
    }),
    RCTAnimationTypeEaseInEaseOut,
    integerValue)

@end
