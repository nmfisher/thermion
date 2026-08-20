#import <Foundation/Foundation.h>
#import <QuartzCore/CADisplayLink.h>
#import <dispatch/dispatch.h>
#include "rendering/CADisplayLinkWrapper.h"

@interface ThermionDisplayLinkHelper : NSObject {
    CADisplayLink* _displayLink;
    CADisplayLinkFrameCallback _callback;
    void* _context;
}
- (instancetype)initWithCallback:(CADisplayLinkFrameCallback)callback context:(void*)context;
- (void)setTargetFps:(int)fps;
- (void)start;
- (void)stop;
- (void)displayLinkFired:(CADisplayLink*)link;
@end

@implementation ThermionDisplayLinkHelper

- (instancetype)initWithCallback:(CADisplayLinkFrameCallback)callback context:(void*)context {
    self = [super init];
    if (self) {
        _callback = callback;
        _context = context;
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    }
    return self;
}

- (void)setTargetFps:(int)fps {
    if (@available(iOS 15.0, *)) {
        if (fps > 0) {
            const float rate = (float)fps;
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(rate, rate, rate);
        } else {
            _displayLink.preferredFrameRateRange = CAFrameRateRangeDefault;
        }
    } else {
        _displayLink.preferredFramesPerSecond = fps > 0 ? fps : 0;
    }
}

- (void)start {
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)displayLinkFired:(CADisplayLink*)link {
    // Convert timestamp (seconds since system boot) to nanoseconds
    uint64_t nanos = (uint64_t)(link.timestamp * 1.0e9);
    _callback(nanos, _context);
}

@end

void* CADisplayLinkWrapper_create(CADisplayLinkFrameCallback callback, void* context) {
    ThermionDisplayLinkHelper* helper = [[ThermionDisplayLinkHelper alloc] initWithCallback:callback context:context];
    return (__bridge_retained void*)helper;
}

void CADisplayLinkWrapper_setTargetFps(void* wrapper, int fps) {
    if (!wrapper) return;
    ThermionDisplayLinkHelper* helper = (__bridge ThermionDisplayLinkHelper*)wrapper;
    if ([NSThread isMainThread]) {
        [helper setTargetFps:fps];
    } else {
        // CADisplayLink is attached to the main run loop. The block retains the
        // helper, so a concurrent stop can safely invalidate it before this runs.
        dispatch_async(dispatch_get_main_queue(), ^{
            [helper setTargetFps:fps];
        });
    }
}

void CADisplayLinkWrapper_start(void* wrapper) {
    ThermionDisplayLinkHelper* helper = (__bridge ThermionDisplayLinkHelper*)wrapper;
    [helper start];
}

void CADisplayLinkWrapper_stop(void* wrapper) {
    ThermionDisplayLinkHelper* helper = (__bridge ThermionDisplayLinkHelper*)wrapper;
    [helper stop];
}

void CADisplayLinkWrapper_destroy(void* wrapper) {
    ThermionDisplayLinkHelper* helper = (__bridge_transfer ThermionDisplayLinkHelper*)wrapper;
    [helper stop];
    // ARC releases helper here
}
