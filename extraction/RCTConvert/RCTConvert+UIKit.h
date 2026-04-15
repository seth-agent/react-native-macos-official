/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

#import <React/RCTConvert.h>

/**
 * UIKit-specific RCTConvert methods. These are separated from the core
 * RCTConvert class so that platform-agnostic code can use RCTConvert
 * without pulling in UIKit.
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

@interface RCTConvert (UIKit_Deprecated)

/**
 * Synchronous image loading is generally a bad idea for performance reasons.
 * If you need to pass image references, try to use `RCTImageSource` and then
 * `RCTImageLoader` instead of converting directly to a UIImage.
 */
+ (UIImage *)UIImage:(id)json;
+ (CGImageRef)CGImage:(id)json CF_RETURNS_NOT_RETAINED;

@end
