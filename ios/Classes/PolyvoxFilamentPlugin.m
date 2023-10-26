#import "FlutterFilamentPlugin.h"
#if __has_include(<flutter_filament/flutter_filament-Swift.h>)
#import <flutter_filament/flutter_filament-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_filament-Swift.h"
#endif

#include "FlutterFilamentApi.h"

@implementation FlutterFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterFilamentPlugin registerWithRegistrar:registrar];
  ios_dummy();
}
@end
