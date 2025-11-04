#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import GLKit

@objc public class SwiftThermionFlutterPlugin: NSObject, FlutterPlugin {
    
    var registrar : FlutterPluginRegistrar
    var registry: FlutterTextureRegistry
    var textures: [Int64: FlutterMetalTextureWrapper] = [:]
  
    static var messenger : FlutterBinaryMessenger? = nil;
    static var instance : SwiftThermionFlutterPlugin? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let binaryMessenger = registrar.messenger()
        let textureRegistry = registrar.textures();
        #elseif os(macOS)
        let binaryMessenger = registrar.messenger
        let textureRegistry = registrar.textures;
        #endif
        messenger = binaryMessenger;
        let channel = FlutterMethodChannel(name: "dev.thermion.flutter/event", binaryMessenger: binaryMessenger)
        instance = SwiftThermionFlutterPlugin(textureRegistry: textureRegistry, registrar:registrar)
        registrar.addMethodCallDelegate(instance!, channel: channel)
    }

    public func registerTexture(texture:MetalTextureWrapper) -> Int {
        let texture = FlutterMetalTextureWrapper(registry: registry, texture: texture)

        if texture.texture.metalTextureAddress == -1 {
            return -1
        }

        textures[texture.flutterTextureId] = texture
        return texture.texture.metalTextureAddress
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
            
                let texture =  MetalTextureWrapper.allocate(width: width, height: height, isDepth:false, isStencil:false)
                let flutterTexture = FlutterMetalTextureWrapper(registry:registry, texture:texture)

                if texture.metalTextureAddress == -1 {
                    result(nil)
                } else {
                    textures[flutterTexture.flutterTextureId] = flutterTexture
                    result([flutterTexture.flutterTextureId, texture.metalTextureAddress, nil])
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

