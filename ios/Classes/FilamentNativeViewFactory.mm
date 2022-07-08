#import "FilamentNativeViewFactory.h"
#import "FilamentMethodCallHandler.h"

using namespace polyvox;

static const FilamentMethodCallHandler* _shandler;

static ResourceBuffer loadResource(const char* name) {
  return [_shandler loadResource:name];
}

static void* freeResource(ResourceBuffer rb) {
  [_shandler freeResource:rb ];
  return nullptr;
}

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
   FilamentViewer* _viewer;
   FilamentMethodCallHandler* _handler;
   void* _layer;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (self = [super init]) {
    _view = [[FilamentView alloc] init];
    _layer = (__bridge_retained void*)[_view layer];
    _viewer = new FilamentViewer(_layer, loadResource, freeResource);
    [_view setViewer:_viewer];
    _handler = [[FilamentMethodCallHandler alloc] initWithRegistrar:registrar viewId:viewId viewer:_viewer ];
    _shandler = _handler;
  }
  return self;
}

- (UIView*)view {
  return _view;
}


@end
