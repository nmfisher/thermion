import Foundation
import GLKit
import FlutterMacOS

public class ThermionFlutterTexture : ThermionDartTexture,  FlutterTexture {
    
    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry
    
    init(registry:FlutterTextureRegistry, width:Int64, height:Int64) {
        self.registry = registry
        super.init(width:width, height:height)    
        self.flutterTextureId = registry.register(self)
            
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return Unmanaged.passRetained(pixelBuffer!);
    }
    
    public func onTextureUnregistered(_ texture:FlutterTexture) {
        print("Texture unregistered")
    }
    
    public func destroy() {
        self.registry.unregisterTexture(self.flutterTextureId)
        self.destroyTexture()
    }
    
}