import FlutterMacOS
import GLKit

public class SwiftThermionFlutterPlugin: NSObject, FlutterPlugin {
    
    var registrar : FlutterPluginRegistrar
    var registry: FlutterTextureRegistry
    var textures: [Int64: ThermionFlutterTexture] = [:]
            
    var createdAt = Date()

    var destroying = false
    
    var resources:[UInt32:NSData] = [:]
  
    static var messenger : FlutterBinaryMessenger? = nil;
    
    var loadResource : @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> ResourceBuffer = { uri, resourcesPtr in
        
        let instance:SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        
        var uriString = String(cString:uri!)
        
        var path:String? = nil

        print("Received request to load \(uriString)")
        
        if(uriString.hasPrefix("file://")) {
            path = String(uriString.dropFirst(7))
        } else {
            if(uriString.hasPrefix("asset://")) {
                uriString = String(uriString.dropFirst(8))
            }
            let bundle = Bundle.init(identifier: "io.flutter.flutter.app")!
            path = bundle.path(forResource:uriString, ofType: nil, inDirectory: "flutter_assets")
        }

        if(path != nil) {
          do {
                let data = try Data(contentsOf: URL(fileURLWithPath:path!))
                let nsData = data as NSData 
                let resId = UInt32(instance.resources.count)
                instance.resources[resId] = nsData
                let length = nsData.length
                print("Resolved asset to file of length \(Int32(length)) at path \(path!)")
                return ResourceBuffer(data:nsData.bytes, size:Int32(UInt32(nsData.length)), id:Int32(UInt32(resId)))
          } catch {
            print("ERROR LOADING RESOURCE")
          }
        }
        return ResourceBuffer()
    }
    
    var freeResource : @convention(c) (ResourceBuffer,UnsafeMutableRawPointer?) -> () = { rbuf, resourcesPtr in
        let instance:SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        instance.resources.removeValue(forKey:UInt32(rbuf.id))
    }
      

    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger;
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "dev.thermion.flutter/event", binaryMessenger: _messenger)
        let instance = SwiftThermionFlutterPlugin(textureRegistry: registrar.textures, registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    var resourceLoaderWrapper:UnsafeMutablePointer<ResourceLoaderWrapper>? = nil
    var renderCallbackHolder:[Any] = []
    
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
    }

    var markTextureFrameAvailable : @convention(c) (UnsafeMutableRawPointer?) -> () = { instancePtr in
        let instance:SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(instancePtr!).takeUnretainedValue()
        for (_, texture) in instance.textures {
            instance.registry.textureFrameAvailable(texture.flutterTextureId)
          }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName = call.method;
        switch methodName {
            case "getResourceLoaderWrapper":
                if(resourceLoaderWrapper == nil) {
                    resourceLoaderWrapper = make_resource_loader(loadResource, freeResource, Unmanaged.passUnretained(self).toOpaque())
                }
                result(Int64(Int(bitPattern: resourceLoaderWrapper!)))
            case "markTextureFrameAvailable":
                let flutterTextureId = call.arguments as! Int64
                registry.textureFrameAvailable(flutterTextureId)
                result(nil)
            case "getRenderCallback":
                if(renderCallbackHolder.isEmpty) {
                    renderCallbackHolder.append(unsafeBitCast(markTextureFrameAvailable, to:Int64.self))
                    renderCallbackHolder.append(unsafeBitCast(Unmanaged.passUnretained(self), to:UInt64.self))
                }
                result(renderCallbackHolder)
            case "getDriverPlatform":
                result(nil)
            case "getSharedContext":
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
                let args = call.arguments as! [Any]
                let flutterTextureId = args[0] as! Int64
                
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

