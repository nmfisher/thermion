#import "PolyvoxFilamentPlugin.h"
#if __has_include(<polyvox_filament/polyvox_filament-Swift.h>)
#import <polyvox_filament/polyvox_filament-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "polyvox_filament-Swift.h"
#endif

@implementation PolyvoxFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPolyvoxFilamentPlugin registerWithRegistrar:registrar];
}
@end

// - (ResourceBuffer)loadResource:(const char* const)path {
//     NSString* p = [NSString stringWithFormat:@"%s", path];
//     NSString* key = [_registrar lookupKeyForAsset:p];
//     NSString* nsPath = [[NSBundle mainBundle] pathForResource:key
//                                                       ofType:nil];
//     if (![[NSFileManager defaultManager] fileExistsAtPath:nsPath]) {
//         NSLog(@"Error: no file exists at %@", p);
//         exit(-1);
//     }

//     NSData* buffer = [NSData dataWithContentsOfFile:nsPath];
//     void* cpy = malloc([buffer length]);
//     memcpy(cpy, [buffer bytes],  [buffer length]); // can we avoid this copy somehow?
//     _resourceId++;
//     ResourceBuffer rbuf(cpy, [buffer length], _resourceId);
//     return rbuf;
// }

// - (void)freeResource:(ResourceBuffer)rb {
//     free((void*)rb.data);
// }

// - (void)ready {
//   [_channel invokeMethod:@"ready" arguments:nil];
// }

// - (NSMutableArray*) getAnimationNames { 
//     unique_ptr<vector<string>> list = _viewer->getAnimationNames();
//     NSMutableArray* asArray = [NSMutableArray arrayWithCapacity:list->size()];
//     for(int i = 0; i < list->size(); i++) {
//       asArray[i] = [NSString stringWithFormat:@"%s", list->at(i).c_str()];
//     }
//     return asArray;
// }

// - (NSMutableArray*) getTargetNames:(NSString*) meshName {
//   unique_ptr<vector<string>> list = _viewer->getTargetNames([meshName UTF8String]);
//   NSMutableArray* asArray = [NSMutableArray arrayWithCapacity:list->size()];
//   for(int i = 0; i < list->size(); i++) {
//     asArray[i] = [NSString stringWithFormat:@"%s", list->at(i).c_str()];
//   }
//   return asArray;
// }

// @end

// @end
