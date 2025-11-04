import Foundation
import GLKit
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

public class FlutterMetalTextureWrapper : NSObject, FlutterTexture {
    
    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry
    var texture: MetalTextureWrapper 
    
    init(registry:FlutterTextureRegistry, texture: MetalTextureWrapper) {
        self.registry = registry
        self.texture = texture
        super.init()
        self.flutterTextureId = registry.register(self)
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(self.texture.pixelBuffer == nil) {
            return nil
        }
        return Unmanaged.passRetained(self.texture.pixelBuffer!);
    }
    
    public func onTextureUnregistered(_ texture:FlutterTexture) {

    }
    
    public func destroy() {
        self.registry.unregisterTexture(self.flutterTextureId)
        self.texture.destroyTexture()
    }
    
}
