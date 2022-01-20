#ifndef FilamentMethodCallHandler_h
#define FilamentMethodCallHandler_h
#endif /* FilamentNativeViewFactory_h */

#import <Flutter/Flutter.h>
#import "FilamentViewController.h"

#include "FilamentViewer.hpp"

static const id VIEW_TYPE = @"holovox.app/filament_view";

@interface FilamentMethodCallHandler : FlutterMethodChannel
- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:( FlutterResult _Nonnull)result;
- (polyvox::FilamentViewer*) _viewer;
- (polyvox::ResourceBuffer)loadResource:(const char* const)path;
- (void)freeResource:(void*)mem size:(size_t)size misc:(void*)misc;
- (void)ready;
- (instancetype)initWithController:(FilamentViewController*)controller
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar
                    viewId:(int64_t)viewId
                    layer:(void*)layer;

@end
