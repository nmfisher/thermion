
import Foundation

@objc public class SwiftThermionFlutterPluginObjCAPI : NSObject {
        
    @objc public static func registerTexture(texture: MetalTextureWrapper) -> Int64 {
        if texture.metalTextureAddress == -1 {
            return -1
        }
        let flutterTextureId = SwiftThermionFlutterPlugin.instance!.registerTexture(texture:texture);
        print("Registeredtexture : \(flutterTextureId)")
        return flutterTextureId
    }

    @objc public static func unregisterFlutterTexture(flutterTextureId: Int64) {
        SwiftThermionFlutterPlugin.instance!.unregisterTexture(flutterTextureId:flutterTextureId);

    }
    
    @objc public static func markTextureFrameAvailable(flutterTextureId: Int64) {
        SwiftThermionFlutterPlugin.instance!.markTextureFrameAvailable(flutterTextureId:flutterTextureId);
    }
}

