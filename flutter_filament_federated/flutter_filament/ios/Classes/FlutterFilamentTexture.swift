import Foundation
import GLKit
import Flutter

public class FlutterFilamentTexture : NSObject, FlutterTexture {
    
    public var pixelBuffer: CVPixelBuffer?
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary

    var flutterTextureId: Int64 = -1
    var registry: FlutterTextureRegistry?
    
    init(width:Int64, height:Int64, registry:FlutterTextureRegistry) {
        self.registry = registry

        super.init()
        
        if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                               kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess) {
            print("Error allocating pixel buffer")
        } else { 
            self.flutterTextureId = registry.register(self)
        }
    }
        
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return Unmanaged.passRetained(pixelBuffer!);
    }
    
    public func onTextureUnregistered(_ texture:FlutterTexture) {
        print("Texture unregistered")
    }
    
    public func destroy() {
        if(self.flutterTextureId != -1) {
            self.registry!.unregisterTexture(self.flutterTextureId)
        }

        self.pixelBuffer = nil
    }
    
}
