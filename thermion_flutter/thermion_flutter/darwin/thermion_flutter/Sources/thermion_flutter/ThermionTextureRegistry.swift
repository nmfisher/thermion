import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/// Concrete forwarder over Flutter's texture registry.
///
/// The Dart bindings name this class explicitly. Generated ffigen wrappers
/// resolve it with `objc_getClass` and check `isKindOfClass:`, so a class
/// that only exists in the header-generation stub is not enough — the Dart
/// side would be handed a `FlutterTextureRegistry`-conforming object of some
/// other class and the check would fail.
///
/// Holding the registry and forwarding the three selectors keeps the ObjC
/// class identity honest while preserving the selector signatures Dart
/// expects.
@objc public class ThermionTextureRegistry: NSObject {
    private let registry: FlutterTextureRegistry

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
    }

    @objc public func registerTexture(_ texture: NSObject) -> Int64 {
        guard let texture = texture as? FlutterTexture else { return 0 }
        return registry.register(texture)
    }

    @objc public func textureFrameAvailable(_ textureId: Int64) {
        registry.textureFrameAvailable(textureId)
    }

    @objc public func unregisterTexture(_ textureId: Int64) {
        registry.unregisterTexture(textureId)
    }
}
