#import <Foundation/Foundation.h>
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CAMediaTiming.h>
#import <dispatch/dispatch.h>
#import <math.h>
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
            // Flexible minimum: a rigid min == preferred == max range forces
            // ProMotion to hold the preferred rate even under thermal load
            // or for non-divisor rates; letting the system downshift to the
            // floor (capped at 30) keeps frame delivery smooth instead.
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fminf(30.0f, rate), rate, rate);
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
    // targetTimestamp is the vsync this callback is preparing a frame for;
    // `timestamp` is the previous displayed frame and lags a full interval,
    // so poses evaluated against it consistently miss scanout by one frame.
    // Convert seconds since system boot to nanoseconds.
    uint64_t nanos = (uint64_t)(link.targetTimestamp * 1.0e9);
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

uint64_t CADisplayLinkWrapper_currentTimeNanos(void) {
    return (uint64_t)(CACurrentMediaTime() * 1.0e9);
}
