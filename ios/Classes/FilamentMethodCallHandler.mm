#import "FilamentMethodCallHandler.h"
#import "FilamentNativeViewFactory.h"

static int _resourceId = 0;

using namespace polyvox;

@implementation FilamentMethodCallHandler {
  FlutterMethodChannel* _channel;
  FilamentViewer* _viewer;
  
  NSObject<FlutterPluginRegistrar>* _registrar;
}
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
                         viewId:(int64_t)viewId
                          viewer:(FilamentViewer*)viewer
                         
{
  _registrar = registrar;
  _viewer = viewer;
  
  NSString* channelName = [NSString stringWithFormat:@"%@_%d",VIEW_TYPE,viewId];
  _channel = [FlutterMethodChannel
    methodChannelWithName:channelName
          binaryMessenger:[registrar messenger]];
  [_channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
    [self handleMethodCall:call result:result];
  }];
  [self ready];
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall* _Nonnull)call result:(FlutterResult _Nonnull )result {
  if(!_viewer) {
    result([FlutterError errorWithCode:@"UNAVAILABLE"
                                      message:@"View unavailable"
                                      details:nil]);
    return;
  }
  if([@"loadSkybox" isEqualToString:call.method]) {
    _viewer->loadSkybox([call.arguments[0] UTF8String], [call.arguments[1] UTF8String]);
    result(@"OK");
  } else if([@"loadGlb" isEqualToString:call.method]) {
    _viewer->loadGlb([call.arguments UTF8String]);
    result(@"OK");
  } else if([@"loadGltf" isEqualToString:call.method]) {
    _viewer->loadGltf([call.arguments[0] UTF8String], [call.arguments[1] UTF8String]);
    result(@"OK");
  } else if([@"setCamera" isEqualToString:call.method]) {
    _viewer->setCamera([call.arguments UTF8String]);
    result(@"OK");
  } else if([@"panStart" isEqualToString:call.method]) {
    _viewer->manipulator->grabBegin([call.arguments[0] intValue], [call.arguments[1] intValue], true);
    result(@"OK");
  } else if([@"panUpdate" isEqualToString:call.method]) {
    _viewer->manipulator->grabUpdate([call.arguments[0] intValue], [call.arguments[1] intValue]);
    result(@"OK");
  } else if([@"panEnd" isEqualToString:call.method]) {
    _viewer->manipulator->grabEnd();
    result(@"OK");
  } else if([@"rotateStart" isEqualToString:call.method]) {
    _viewer->manipulator->grabBegin([call.arguments[0] intValue], [call.arguments[1] intValue], false);
    result(@"OK");
  } else if([@"rotateUpdate" isEqualToString:call.method]) {
    _viewer->manipulator->grabUpdate([call.arguments[0] intValue], [call.arguments[1] intValue]);
    result(@"OK");
  } else if([@"rotateEnd" isEqualToString:call.method]) {
    _viewer->manipulator->grabEnd();
    result(@"OK");
  } else if([@"releaseSourceAssets" isEqualToString:call.method]) {
    _viewer->releaseSourceAssets();
    result(@"OK");
  } else if([@"animateWeights" isEqualToString:call.method]) {
    NSArray* frameData = call.arguments[0];
    NSNumber* numWeights = call.arguments[1];
    NSNumber* frameRate = call.arguments[2];
    NSUInteger numElements = [frameData count];

    float* framesArr = (float*)malloc([frameData count] *sizeof(float));
    for(int i =0 ; i < [frameData count]; i++) {
      *(framesArr+i) = [[frameData objectAtIndex:i] floatValue];
    }
    NSUInteger numFrames =  numElements / [ numWeights intValue ];
    _viewer->animateWeights((float*)framesArr, [numWeights intValue], numFrames, [frameRate floatValue]);
    result(@"OK");
  } else if([@"playAnimation" isEqualToString:call.method]) {
    int animationIndex = [call.arguments[0] intValue];
    bool loop = call.arguments[1];
    _viewer->playAnimation(animationIndex, loop);
    result(@"OK");
  } else if([@"getTargetNames" isEqualToString:call.method]) {
    StringList list = _viewer->getTargetNames([call.arguments UTF8String]);
    NSMutableArray* asArray = [NSMutableArray arrayWithCapacity:list.count];
    for(int i = 0; i < list.count; i++) {
      asArray[i] = [NSString stringWithFormat:@"%s", list.strings[i]];
    }
    result(asArray);
  } else if([@"applyWeights" isEqualToString:call.method]) {

    NSArray* nWeights = call.arguments;
    
    int count = [nWeights count];
    float weights[count];
    for(int i=0; i < count; i++) {
      weights[i] = [nWeights[i] floatValue];
    }
    _viewer->applyWeights(weights, count);
    result(@"OK");
  } else if([@"zoom" isEqualToString:call.method]) {
    _viewer->manipulator->scroll(0.0f, 0.0f, [call.arguments floatValue]);
    result(@"OK");
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (ResourceBuffer)loadResource:(const char* const)path {
    NSString* p = [NSString stringWithFormat:@"%s", path];
    NSString* key = [_registrar lookupKeyForAsset:p];
    NSString* nsPath = [[NSBundle mainBundle] pathForResource:key
                                                      ofType:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:nsPath]) {
        NSLog(@"Error: no file exists at %@", p);
        exit(-1);
    }

    NSData* buffer = [NSData dataWithContentsOfFile:nsPath];
    void* cpy = malloc([buffer length]);
    memcpy(cpy, [buffer bytes],  [buffer length]); // can we avoid this copy somehow?
    _resourceId++;
    ResourceBuffer rbuf(cpy, [buffer length], _resourceId);
    return rbuf;
}

- (void)freeResource:(ResourceBuffer)rb {
    free((void*)rb.data);
}

- (void)ready {
  [_channel invokeMethod:@"ready" arguments:nil];
}

@end
