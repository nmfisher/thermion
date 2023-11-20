import FlutterMacOS
import GLKit

public class SwiftFlutterFilamentPlugin: NSObject, FlutterPlugin, FlutterTexture {
    
    var registrar : FlutterPluginRegistrar
    var flutterTextureId: Int64?
    var registry: FlutterTextureRegistry
    
    var pixelBuffer: CVPixelBuffer?;
    
    var createdAt = Date()
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ABGR ),
       kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ] as CFDictionary
    
    var resources:[UInt32:NSData] = [:]
  
    static var messenger : FlutterBinaryMessenger? = nil;
    
    var loadResource : @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> ResourceBuffer = { uri, resourcesPtr in
        
        let instance:SwiftFlutterFilamentPlugin = Unmanaged<SwiftFlutterFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        
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
        let instance:SwiftFlutterFilamentPlugin = Unmanaged<SwiftFlutterFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        instance.resources.removeValue(forKey:UInt32(rbuf.id))
    }

    var markTextureFrameAvailable : @convention(c) (UnsafeMutableRawPointer?) -> () = { instancePtr in
        let instance:SwiftFlutterFilamentPlugin = Unmanaged<SwiftFlutterFilamentPlugin>.fromOpaque(instancePtr!).takeUnretainedValue()
        if(instance.flutterTextureId != nil) {
            instance.registry.textureFrameAvailable(instance.flutterTextureId!)
        }
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(pixelBuffer == nil) {
            return nil;
        }
        return Unmanaged.passRetained(pixelBuffer!);
    }
    
    public func onTextureUnregistered(_ texture:FlutterTexture) {
        print("Texture unregistered")
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger;
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "app.polyvox.filament/event", binaryMessenger: _messenger)
        let instance = SwiftFlutterFilamentPlugin(textureRegistry: registrar.textures, registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
        self.metalDevice = MTLCreateSystemDefaultDevice()!
    }
    
    private func createPixelBuffer(width:Int, height:Int) {
        if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                               kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess) {
            print("Error allocating pixel buffer")
        }
        self.flutterTextureId = self.registry.register(self)
    }
    
    
    var cvMetalTextureCache:CVMetalTextureCache? = nil
    var cvMetalTexture:CVMetalTexture? = nil
    var metalTexture:MTLTexture? = nil
    var metalDevice:MTLDevice? = nil
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName = call.method;
        switch methodName {
        case "getResourceLoaderWrapper":
            let resourceLoaderWrapper = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())
            result(unsafeBitCast(resourceLoaderWrapper, to:Int64.self))
        case "getRenderCallback":
            let renderCallback = markTextureFrameAvailable
            let resultArray:[Any] = [
                unsafeBitCast(renderCallback, to:Int64.self), unsafeBitCast(Unmanaged.passUnretained(self), to:UInt64.self)]
            result(resultArray)
        case "createTexture":
            let args = call.arguments as! [Any]
            let width = UInt32(args[0] as! Int64)
            let height = UInt32(args[1] as! Int64)
            createPixelBuffer(width:Int(width), height:Int(height))
           
            var cvret = CVMetalTextureCacheCreate(
                            kCFAllocatorDefault,
                            nil,
                            metalDevice!,
                            nil,
                            &cvMetalTextureCache);
            if(cvret != 0) { 
                result(FlutterError())
                return
            }
            cvret = CVMetalTextureCacheCreateTextureFromImage(
                            kCFAllocatorDefault,
                            cvMetalTextureCache!,
                            pixelBuffer!, nil,
                            MTLPixelFormat.bgra8Unorm,
                            Int(width), Int(height),
                            0,
                            &cvMetalTexture);
            if(cvret != 0) { 
                result(FlutterError())
                return
            }
            metalTexture = CVMetalTextureGetTexture(cvMetalTexture!);
            
            let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
            let metalTextureAddress = Int(bitPattern:metalTexturePtr)
                                                                                            
            result([self.flutterTextureId as Any, nil, metalTextureAddress, nil])
        case "destroyTexture":
            if(self.flutterTextureId != nil) {
                self.registry.unregisterTexture(self.flutterTextureId!)
            }
            self.flutterTextureId = nil 
            self.pixelBuffer = nil
            self.metalTexture = nil
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

