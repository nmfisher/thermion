import Foundation
import GLKit
import FlutterMacOS

public class FlutterFilamentTexture : NSObject, FlutterTexture {
    
    var texture:DartFilamentTexture
    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry
    
    init(registry:FlutterTextureRegistry, texture:DartFilamentTexture) {
        self.texture = texture
        self.registry = registry
        super.init()

        self.flutterTextureId = registry.register(self)

    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return Unmanaged.passRetained(texture.pixelBuffer!);
    }
    
    public func onTextureUnregistered(_ texture:FlutterTexture) {
        print("Texture unregistered")
    }
    
    public func destroy() {
        self.registry.unregisterTexture(self.flutterTextureId)
        self.texture.destroyTexture()
    }
    
}