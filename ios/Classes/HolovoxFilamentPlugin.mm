#import "HolovoxFilamentPlugin.h"
#import "filament/FilamentNativeViewFactory.h"

FilamentNativeViewFactory* factory;

@implementation HolovoxFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  factory =
      [[FilamentNativeViewFactory alloc] initWithRegistrar:registrar];
  [registrar registerViewFactory:factory withId:@"holovox.app/filament_view"];
}
@end
