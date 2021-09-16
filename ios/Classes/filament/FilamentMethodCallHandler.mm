#import "FilamentMethodCallHandler.h"
#import "FilamentViewController.h"
#import "FilamentNativeViewFactory.h"

static const FilamentMethodCallHandler* _handler;

static mimetic::ResourceBuffer loadResourceGlobal(const char* name) {
  return [_handler loadResource:name];
}

static void* freeResourceGlobal(void* mem, size_t size, void* misc) {
  [_handler freeResource:mem size:size misc:misc ];
  return nullptr;
}

@implementation FilamentMethodCallHandler {
  FilamentViewController *_controller;
  FlutterMethodChannel* _channel;
  mimetic::FilamentViewer* _viewer;
  void* _layer;
  
  NSObject<FlutterPluginRegistrar>* _registrar;
}
- (instancetype)initWithController:(FilamentViewController*)controller
                         registrar:(NSObject<FlutterPluginRegistrar>*)registrar
                         viewId:(int64_t)viewId
                         layer:(void*)layer
{
  _layer = layer;
  _registrar = registrar;
  _controller = controller;
  NSString* channelName = [NSString stringWithFormat:@"%@_%d",VIEW_TYPE,viewId];
  _channel = [FlutterMethodChannel
    methodChannelWithName:channelName
          binaryMessenger:[registrar messenger]];
  [_channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
    [self handleMethodCall:call result:result];
  }];
  _handler = self;
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:(FlutterResult _Nonnull )result {
  if([@"initialize" isEqualToString:call.method]) {
	    _viewer = new mimetic::FilamentViewer(_layer, loadResourceGlobal, freeResourceGlobal);
      [_controller setViewer:_viewer];
      [_controller startDisplayLink];
      result(@"OK");
  } else if([@"loadSkybox" isEqualToString:call.method]) {
    if(!_viewer)
      return;
    _viewer->loadSkybox([call.arguments[0] UTF8String], [call.arguments[1] UTF8String]);
    result(@"OK");
  } else if([@"loadGltf" isEqualToString:call.method]) {
    if(!_viewer)
      return;
    _viewer->loadGltf([call.arguments[0] UTF8String], [call.arguments[1] UTF8String]);
    result(@"OK");
  } else if([@"panStart" isEqualToString:call.method]) {
    if(!_viewer)
      return;
    _viewer->manipulator->grabBegin([call.arguments[0] intValue], [call.arguments[1] intValue], true);
  } else if([@"panUpdate" isEqualToString:call.method]) {
    if(!_viewer)
      return;
    _viewer->manipulator->grabUpdate([call.arguments[0] intValue], [call.arguments[1] intValue]);
  } else if([@"panEnd" isEqualToString:call.method]) {
    if(!_viewer)
      return;
    _viewer->manipulator->grabEnd();
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (mimetic::ResourceBuffer)loadResource:(const char* const)path {
    NSString* p = [NSString stringWithFormat:@"%s", path];
    NSString* key = [_registrar lookupKeyForAsset:p];
    NSString* nsPath = [[NSBundle mainBundle] pathForResource:key
                                                      ofType:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:nsPath]) {
        NSLog(@"Error: no file exists at %@", nsPath);
        exit(-1);
    }

    NSData* buffer = [NSData dataWithContentsOfFile:nsPath];
    void* cpy = malloc([buffer length]);
    memcpy(cpy, [buffer bytes],  [buffer length]); // can we avoid this copy somehow?
    mimetic::ResourceBuffer rbuf(cpy, [buffer length]);
    return rbuf;
}

- (void)freeResource:(void*)mem size:(size_t)s misc:(void *)m {
    free(mem);
}

@end
