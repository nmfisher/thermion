import Flutter
import UIKit
import GLKit

public class SwiftThermionFlutterPlugin: NSObject, FlutterPlugin {
    
    var registrar : FlutterPluginRegistrar
    var registry: FlutterTextureRegistry
    var textures: [Int64: ThermionFlutterTexture] = [:]
        
    var createdAt = Date()
        
    var resources:NSMutableDictionary = [:]

    static var messenger : FlutterBinaryMessenger? = nil;
    
    var loadResource : @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> ResourceBuffer = { uri, resourcesPtr in
        
        let instance:SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        
        let uriString = String(cString:uri!)
        
        var path:String? = nil
        
        // check for hot-reloaded asset
        var found : URL? = nil
        
        if(uriString.hasPrefix("asset://")) {
            let assetPath = String(uriString.dropFirst(8))
            print("Searching for hot reloaded asset under path : \(assetPath)")
            let appFolder = Bundle.main.resourceURL
            let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationDirectory,
                                                               .userDomainMask, true)
            let supportDirPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                                      .userDomainMask, true)
            let devFsPath = URL(fileURLWithPath: supportDirPaths.first!, isDirectory:true).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("tmp")
            
            
            let orderedURLs = try? FileManager.default.enumerator(at: devFsPath, includingPropertiesForKeys: [ .pathKey, .creationDateKey], options: .skipsHiddenFiles)
            
            
            for case let fileURL as URL in orderedURLs! {
                if !(fileURL.path.hasSuffix(assetPath)) {
                    continue
                }
                print("Found hot reloaded asset : \(fileURL)")
                if found == nil {
                    found = fileURL
                } else {
                    do {
                        let c1 = try found!.resourceValues(forKeys: [.creationDateKey]).creationDate
                        let c2 = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate
                        
                        if c1! < c2! {
                            found = fileURL
                            print("\(fileURL) is newer, replacing")
                        } else {
                            print("Ignoring older asset")
                        }
                    } catch {
                        
                    }
                }
            }
        }
        
        do {
            if let cd = try found?.resourceValues(forKeys:[.creationDateKey]).creationDate {
                if cd > instance.createdAt {
                    print("Using hot reloaded asset  : \(found)")
                    path = found!.path
                }
            }
        } catch {
            
        }
        if path == nil {
            if(uriString.hasPrefix("file://")) {
                path = String(uriString.dropFirst(7))
            } else if(uriString.hasPrefix("asset://")) {
                let key = instance.registrar.lookupKey(forAsset:String(uriString.dropFirst(8)))
                path = Bundle.main.path(forResource: key, ofType:nil)
                print("Found path \(path) for uri \(uriString)")
                guard path != nil else {
                    print("File not present in bundle : \(uri)")
                    return ResourceBuffer()
                }
            } else {
                let key = instance.registrar.lookupKey(forAsset:uriString)
                path = Bundle.main.path(forResource: key, ofType:nil)
                print("Found path \(path) for uri \(uriString)")
                guard path != nil else {
                    print("File not present in bundle : \(uri)")
                    return ResourceBuffer()
                }
            }
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath:path!))
            let resId = instance.resources.count
            let nsData = data as NSData
            instance.resources[resId] = nsData
            let rawPtr = nsData.bytes
            let length = Int32(nsData.count)
            print("Opened asset of length \(Int32(length)) at path \(path!)")

            return ResourceBuffer(data:rawPtr, size:length, id:Int32(resId))
        } catch {
            print("Error opening file: \(error)")
        }
        return ResourceBuffer()
    }
    
    var freeResource : @convention(c) (ResourceBuffer,UnsafeMutableRawPointer?) -> () = { rbuf, resourcesPtr in
        let instance:SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        instance.resources.removeObject(forKey:rbuf.id)
    }

    var markTextureFrameAvailable: @convention(c) (UnsafeMutableRawPointer?) -> () = { instancePtr in
        let instance: SwiftThermionFlutterPlugin = Unmanaged<SwiftThermionFlutterPlugin>.fromOpaque(instancePtr!).takeUnretainedValue()
        for (_, texture) in instance.textures {
            instance.registry.textureFrameAvailable(texture.flutterTextureId)
        }
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger();
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "dev.thermion.flutter/event", binaryMessenger: _messenger)
        let instance = SwiftThermionFlutterPlugin(textureRegistry: registrar.textures(), registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
    }
        
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName = call.method;
        switch methodName {
            case "getResourceLoaderWrapper":
                let resourceLoaderWrapper = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())
                result(unsafeBitCast(resourceLoaderWrapper, to:Int64.self))
            case "getRenderCallback":
                let renderCallback = markTextureFrameAvailable
                result([
                    unsafeBitCast(renderCallback, to:Int64.self), unsafeBitCast(Unmanaged.passUnretained(self), to:UInt64.self)])
            case "getDriverPlatform":
                result(nil)
            case "getSharedContext":
                result(nil)
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
                let args = call.arguments as! [Any]
                let flutterTextureId = args[0] as! Int64
                
                if let texture = textures[flutterTextureId] {
                    registry.unregisterTexture(flutterTextureId)
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

