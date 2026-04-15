/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// [macOS]
#if TARGET_OS_OSX

#import <Foundation/Foundation.h>

/**
 * macOS equivalent of CADisplayLink.
 * Uses CVDisplayLink to provide vsync-aligned callbacks on macOS,
 * where CADisplayLink is not available.
 */
@interface RCTPlatformDisplayLink : NSObject

+ (RCTPlatformDisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel;

- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
- (void)invalidate;

@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSTimeInterval duration;

@end

#endif // TARGET_OS_OSX
