import FlutterMacOS
import GLKit

public class SwiftThermionFlutterPlugin: NSObject, FlutterPlugin {
    
    var registrar : FlutterPluginRegistrar
    var registry: FlutterTextureRegistry
    var textures: [Int64: ThermionFlutterTexture] = [:]

    var destroying = false
  
    static var messenger : FlutterBinaryMessenger? = nil;

    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger;
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "dev.thermion.flutter/event", binaryMessenger: _messenger)
        let instance = SwiftThermionFlutterPlugin(textureRegistry: registrar.textures, registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
        
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName = call.method;
        switch methodName {
            case "markTextureFrameAvailable":
                let flutterTextureId = call.arguments as! Int64
                registry.textureFrameAvailable(flutterTextureId)
                result(nil)
            case "createTexture":
                let args = call.arguments as! [Any]
                let width = args[0] as! Int64
                let height = args[1] as! Int64
            
                let texture = ThermionFlutterTexture(registry: registry, width: width, height: height)

                if texture.texture.metalTextureAddress == -1 {
                    result(nil)
                } else {
                    textures[texture.flutterTextureId] = texture
                    result([texture.flutterTextureId, texture.texture.metalTextureAddress, nil])
                }
            case "destroyTexture":
                let flutterTextureId = call.arguments as! Int64
                
                if let texture = textures[flutterTextureId] {
                    texture.destroy()
                    textures.removeValue(forKey: flutterTextureId)
                    result(true)
                } else {
                    result(false)
                }
            default:
                result(FlutterMethodNotImplemented)
        }
    }
}

