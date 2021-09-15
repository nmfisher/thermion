#ifndef FilamentNativeViewFactory_h
#define FilamentNativeViewFactory_h
#endif /* FilamentNativeViewFactory_h */

#import <Flutter/Flutter.h>
#import "FilamentViewer.hpp"

@interface FilamentMethodCallHandler : FlutterMethodChannel
- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:( FlutterResult _Nonnull)result;
- (mimetic::FilamentViewer*) _viewer;
@end

@interface FilamentNativeViewFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;
- (mimetic::ResourceBuffer)loadResource:(const char* const)path;
- (void)freeResource:(void*)mem size:(size_t)size misc:(void*)misc;
@end

@interface FilamentNativeView : NSObject <FlutterPlatformView>

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar;

- (UIView*)view;

@end

