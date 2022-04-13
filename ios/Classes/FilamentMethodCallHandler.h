#ifndef FilamentMethodCallHandler_h
#define FilamentMethodCallHandler_h
#endif /* FilamentNativeViewFactory_h */

#import <Flutter/Flutter.h>

#include "FilamentViewer.hpp"

using namespace polyvox;

static const id VIEW_TYPE = @"app.polyvox.filament/filament_view";

@interface FilamentMethodCallHandler : FlutterMethodChannel
- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:( FlutterResult _Nonnull)result;
- (polyvox::FilamentViewer*) _viewer;
- (polyvox::ResourceBuffer)loadResource:(const char* const)path;
- (void)freeResource:(polyvox::ResourceBuffer)rb;
- (void)ready;
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar viewId:(int64_t)viewId viewer:(FilamentViewer*)viewer;
@end
