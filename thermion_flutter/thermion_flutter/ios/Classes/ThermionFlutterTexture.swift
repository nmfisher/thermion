import Foundation
import GLKit
import Flutter

public class ThermionFlutterTexture : NSObject, FlutterTexture {
    
    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry
    var texture: ThermionTextureSwift 
    
    init(registry:FlutterTextureRegistry, width:Int64, height:Int64) {
        self.registry = registry
        self.texture = ThermionTextureSwift(width:width, height: height)
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
