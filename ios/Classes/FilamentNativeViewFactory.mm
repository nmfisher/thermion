#import "FilamentNativeViewFactory.h"
#import "FilamentViewController.h"
#import "FilamentMethodCallHandler.h"

@implementation FilamentNativeViewFactory   {
  NSObject<FlutterPluginRegistrar>* _registrar;
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
  }
  return self;
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  return [[FilamentNativeView alloc] initWithFrame:frame
                              viewIdentifier:viewId
                                   arguments:args
                             registrar:_registrar];
}

@end



@implementation FilamentNativeView  {
   FilamentView* _view;
   FilamentViewController* _controller;
   polyvox::FilamentViewer* _viewer;
   FilamentMethodCallHandler* _handler;
   void* _layer;
}


- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (self = [super init]) {
    _view = [[FilamentView alloc] init];
    _controller = [[FilamentViewController alloc] initWithRegistrar:registrar view:_view];
    [_controller viewDidLoad];
    _layer = (__bridge_retained void*)[_view layer];
    _handler = [[FilamentMethodCallHandler alloc] initWithController:_controller registrar:registrar viewId:viewId layer:_layer];
    [_handler ready];
  }
  return self;
}

- (UIView*)view {
  return _view;
}


@end
