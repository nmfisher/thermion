#import "PolyvoxFilamentPlugin.h"
#import "FilamentNativeViewFactory.h"

FilamentNativeViewFactory* factory;

@implementation PolyvoxFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  factory =
      [[FilamentNativeViewFactory alloc] initWithRegistrar:registrar];
  [registrar registerViewFactory:factory withId:@"app.polyvox.filament/filament_view"];
}
@end
