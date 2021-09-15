/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FilamentViewController.h"
#import "FilamentView.h"

#import <Flutter/Flutter.h>

@implementation FilamentViewController {
    CADisplayLink* _displayLink;
    NSObject<FlutterPluginRegistrar>* _registrar;
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    if (self = [super init]) {
      _registrar = registrar;
    }
    return self;
}
#pragma mark UIViewController methods

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self startDisplayLink];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stopDisplayLink];
}

- (void)startDisplayLink {
    [self stopDisplayLink];

    // Call our render method 60 times a second.
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
    _displayLink.preferredFramesPerSecond = 60;
    [_displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
}

- (void)stopDisplayLink {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)render {   
    
}

- (void)dealloc {

}

@end
