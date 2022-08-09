#import "FilamentMethodCallHandler.h"
#import "FilamentNativeViewFactory.h"

static int _resourceId = 0;

using namespace polyvox;
using namespace std;

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
    _viewer->loadSkybox([call.arguments UTF8String]);
    result(@"OK");
  } else if([@"removeSkybox" isEqualToString:call.method]) {
    _viewer->removeSkybox();
    result(@"OK");
  } else if([@"loadIbl" isEqualToString:call.method]) {
    _viewer->loadIbl([call.arguments UTF8String]);
    result(@"OK");
  } else if([@"removeIbl" isEqualToString:call.method]) {
    _viewer->removeIbl();
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
  } else if([@"animateWeights" isEqualToString:call.method]) {
    NSArray* frameData = call.arguments[0];
    NSNumber* numWeights = call.arguments[1];
    NSNumber* numFrames = call.arguments[2];
    NSNumber* frameLenInMs = call.arguments[3];
    
    float* framesArr = (float*)malloc([frameData count] *sizeof(float));
    for(int i =0 ; i < [frameData count]; i++) {
      *(framesArr+i) = [[frameData objectAtIndex:i] floatValue];
    }

    _viewer->animateWeights((float*)framesArr, [numWeights intValue], [numFrames intValue], [frameLenInMs floatValue]);
    result(@"OK");
  } else if([@"playAnimation" isEqualToString:call.method]) {
    int animationIndex = [call.arguments[0] intValue];
    bool loop = call.arguments[1];
    _viewer->playAnimation(animationIndex, loop);
    result(@"OK");
  } else if ([@"stopAnimation" isEqualToString:call.method]) {
    _viewer->stopAnimation();
    result(@"OK");
  } else if([@"getTargetNames" isEqualToString:call.method]) {
    NSMutableArray* names = [self getTargetNames:call.arguments];
    result(names);
  } else if([@"getAnimationNames" isEqualToString:call.method]) {
    NSMutableArray* names = [self getAnimationNames];
    result(names);
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

- (NSMutableArray*) getAnimationNames { 
    unique_ptr<vector<string>> list = _viewer->getAnimationNames();
    NSMutableArray* asArray = [NSMutableArray arrayWithCapacity:list->size()];
    for(int i = 0; i < list->size(); i++) {
      asArray[i] = [NSString stringWithFormat:@"%s", list->at(i).c_str()];
    }
    return asArray;
}

- (NSMutableArray*) getTargetNames:(NSString*) meshName {
  unique_ptr<vector<string>> list = _viewer->getTargetNames([meshName UTF8String]);
  NSMutableArray* asArray = [NSMutableArray arrayWithCapacity:list->size()];
  for(int i = 0; i < list->size(); i++) {
    asArray[i] = [NSString stringWithFormat:@"%s", list->at(i).c_str()];
  }
  return asArray;
}

@end
