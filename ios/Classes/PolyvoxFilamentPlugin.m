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
