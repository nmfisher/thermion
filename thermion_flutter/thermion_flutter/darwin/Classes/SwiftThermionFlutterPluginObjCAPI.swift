
import Foundation

@objc public class SwiftThermionFlutterPluginObjCAPI : NSObject {
        
    @objc public static func registerTexture(texture: MetalTextureWrapper) {
        SwiftThermionFlutterPlugin.instance!.registerTexture(texture:texture);
    }
}

