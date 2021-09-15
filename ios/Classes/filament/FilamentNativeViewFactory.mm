#import "FilamentNativeViewFactory.h"
#import "FilamentViewController.h"

static const id VIEW_TYPE = @"mimetic.app/filament_view";

static const FilamentNativeViewFactory* _factory;

static mimetic::ResourceBuffer loadResource(const char* const name) {
  return [_factory loadResource:name];
}

static void* freeResource(void* mem, size_t size, void* misc) {
  [_factory freeResource:mem size:size misc:misc ];
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
  _factory = self;
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

@implementation FilamentMethodCallHandler {
  FilamentViewController *_controller;
  FlutterMethodChannel* _channel;
  mimetic::FilamentViewer* _viewer;
  void* _layer;
}
- (instancetype)initWithController:(FilamentViewController*)controller
                         registrar:(NSObject<FlutterPluginRegistrar>*)registrar
                         viewId:(int64_t)viewId
                         layer:(void*)layer
                          {
  _layer = layer;
  _controller = controller;
  NSString* channelName = [NSString stringWithFormat:@"%@_%d",VIEW_TYPE,viewId];
  _channel = [FlutterMethodChannel
    methodChannelWithName:channelName
          binaryMessenger:[registrar messenger]];
  [_channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
    [self handleMethodCall:call result:result];
  }];
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:(FlutterResult _Nonnull )result {
  if([@"initialize" isEqualToString:call.method]) {
    [self initialize];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (mimetic::ResourceBuffer)loadResource:(const char* const)path {

    NSString* documentPath = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString* pathComponent = [NSString stringWithUTF8String:path];
    NSString* nsPath = [documentPath stringByAppendingPathComponent:pathComponent];

    if (![[NSFileManager defaultManager] fileExistsAtPath:nsPath]) {
        NSLog(@"Error: no file exists at %@", nsPath);
        exit(-1);
    }

    NSData* buffer = [NSData dataWithContentsOfFile:nsPath];

    mimetic::ResourceBuffer rbuf([buffer bytes], [buffer length]);
    return rbuf;
}

- (void)freeResource:(void*)mem size:(size_t)s misc:(void *)m {
  // TODO
}

-(void)initialize {
  _viewer = new mimetic::FilamentViewer(_layer, loadResource, freeResource);
}
@end

@implementation FilamentNativeView  {
   FilamentView *_view;
   FilamentViewController *_controller;
   FilamentMethodCallHandler *_handler;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (self = [super init]) {
    _view = [[FilamentView alloc] init];
    _controller = [[FilamentViewController alloc] initWithRegistrar:registrar];
    _controller.modelView = _view;
    [_controller viewDidLoad];
    [_controller startDisplayLink];   
    _handler = [[FilamentMethodCallHandler alloc] initWithController:_controller registrar:registrar viewId:viewId layer:(__bridge void*)[_view layer]];
  }
  return self;
}

- (UIView*)view {
  return _view;
}


@end
