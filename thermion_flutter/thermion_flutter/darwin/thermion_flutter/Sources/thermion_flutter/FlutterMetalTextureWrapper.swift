import Foundation
import GLKit
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

// To register a native Metal texture with the Flutter compositor/texture registry, we need a wrapper
// that implements the [FlutterTexture] protocol.
//
// This is no longer managed by the native platform channel; all texture lifecycle ownership
// (register/unregister/textureFrameAvailable) now lives in [darwin_platform_texture_descriptor.dart].
public class FlutterMetalTextureWrapper : NSObject, FlutterTexture {

    private var texture: MetalTextureWrapper

    @objc public init(texture: MetalTextureWrapper) {
        self.texture = texture
        super.init()
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if self.texture.pixelBuffer == nil {
            return nil
        }
        return Unmanaged.passRetained(self.texture.pixelBuffer!)
    }

    public func onTextureUnregistered(_ texture: FlutterTexture) {
        // Hook for the future #178 bug-2 safe surface release: this fires on
        // the raster thread once Flutter is done with the texture, which is the
        // ordering the Dart side needs before releasing the wrapper.
        print("Texture unregistered")
    }
}
