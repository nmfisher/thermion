#import "PolyvoxFilamentPlugin.h"
#import "FilamentNativeViewFactory.h"

FilamentNativeViewFactory* factory;

@implementation PolyvoxFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  factory =
      [[FilamentNativeViewFactory alloc] initWithRegistrar:registrar];
  [registrar registerViewFactory:factory withId:@"holovox.app/filament_view"];
}
@end
