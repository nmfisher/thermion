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

// These defines are set in the "Preprocessor Macros" build setting for each scheme.
#include "FilamentView.h"
#include "FilamentViewer.hpp"
#import <Foundation/Foundation.h>

using namespace std;

@interface FilamentView ()
- (void)initCommon;
- (void)setViewer:(polyvox::FilamentViewer*)viewer;
@end

@implementation FilamentView {
    polyvox::FilamentViewer* _viewer;
}

- (void)setViewer:(polyvox::FilamentViewer*)viewer {
    _viewer = viewer;
    _viewer->updateViewportAndCameraProjection(self.bounds.size.width, self.bounds.size.height, self.contentScaleFactor);
}


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initCommon];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    if (self = [super initWithCoder:coder]) {
        [self initCommon];
    }
    return self;
}

- (void)initCommon {
    [self initializeGLLayer];
}

- (void)initializeGLLayer {
    CAEAGLLayer* glLayer = (CAEAGLLayer*)self.layer;
    glLayer.opaque = YES;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if(_viewer) {
        _viewer->updateViewportAndCameraProjection(self.bounds.size.width, self.bounds.size.height, self.contentScaleFactor);
    }
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor {
    [super setContentScaleFactor:contentScaleFactor];
    if(_viewer) {
        _viewer->updateViewportAndCameraProjection(self.bounds.size.width, self.bounds.size.height, self.contentScaleFactor);
    }
}

@end
