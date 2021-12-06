#ifndef FilamentNativeViewFactory_h
#define FilamentNativeViewFactory_h
#endif /* FilamentNativeViewFactory_h */

#import <Flutter/Flutter.h>
#import "FilamentView.h"

#include "FilamentViewer.hpp"


@interface FilamentNativeViewFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;
@end

@interface FilamentNativeView : NSObject <FlutterPlatformView>

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar;

- (UIView*)view;

@end

