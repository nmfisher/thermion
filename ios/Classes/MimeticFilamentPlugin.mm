#import "MimeticFilamentPlugin.h"
#import "filament/FilamentNativeViewFactory.h"

FilamentNativeViewFactory* factory;

@implementation MimeticFilamentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  factory =
      [[FilamentNativeViewFactory alloc] initWithRegistrar:registrar];
  [registrar registerViewFactory:factory withId:@"mimetic.app/filament_view"];
}
@end
