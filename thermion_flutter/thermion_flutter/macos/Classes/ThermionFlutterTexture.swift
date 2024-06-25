import Foundation
import GLKit
import FlutterMacOS

public class ThermionFlutterTexture : NSObject, FlutterTexture {
    
    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry
    var texture: ThermionDartTexture 
    
    init(registry:FlutterTextureRegistry, width:Int64, height:Int64) {
        self.registry = registry
        self.texture = ThermionDartTexture(width:width, height: height)
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
        print("Texture unregistered")
    }
    
    public func destroy() {
        self.registry.unregisterTexture(self.flutterTextureId)
        self.texture.destroyTexture()
    }
    
}
