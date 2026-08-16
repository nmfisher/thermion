#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import GLKit

// Previously, this plugin class was responsible for allocating/destroying platform (Metal)
// textures in response to events sent from the Dart side via method channel.
//
// This is no longer the case; Metal textures are now exclusively managed on the Dart side of
// the boundary (see darwin_platform_texture_descriptor.dart).
//
// This structure is preferred because:
// 1) Swift/ObjC refcounting & lifecycle management are now confined to a single point of failure
// 2) method channels are a Flutter-specific paradigm that predate newer objc/FFI interop
//    pathways; the latter are preferable because they decouple the package from Flutter.
//
// However, we can't remove this plugin class entirely, because it is (currently) still needed
// to capture a reference to [FlutterTextureRegistry] from [FlutterPluginRegistrar] and
// expose it to Dart. So the only reason this class still exists is to pass FlutterTextureRegistry.
@objc public class SwiftThermionFlutterPlugin: NSObject, FlutterPlugin {

    var registry: FlutterTextureRegistry

    static var instance: SwiftThermionFlutterPlugin? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let textureRegistry = registrar.textures();
        #elseif os(macOS)
        let textureRegistry = registrar.textures;
        #endif
        instance = SwiftThermionFlutterPlugin(textureRegistry: textureRegistry)
    }

    init(textureRegistry: FlutterTextureRegistry) {
        self.registry = textureRegistry
    }
}
