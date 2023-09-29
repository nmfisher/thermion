import FlutterMacOS
import GLKit

public class SwiftPolyvoxFilamentPlugin: NSObject, FlutterPlugin, FlutterTexture {
    
    var registrar : FlutterPluginRegistrar
    var flutterTextureId: Int64?
    var registry: FlutterTextureRegistry
    
    var pixelBuffer: CVPixelBuffer?;
    
    var createdAt = Date()
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ABGR ),
       kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary
    
    var resources:[UInt32:NSData] = [:]
    
    var viewer:UnsafeRawPointer? = nil
    var displayLink:CVDisplayLink? = nil
    var rendering:Bool = false
    
    var frameInterval:Double = 1 / 60.0
    
    static var messenger : FlutterBinaryMessenger? = nil;
    
    var loadResource : @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> ResourceBuffer = { uri, resourcesPtr in
        
        let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        
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
                print("Resolved asset to file of length \(length) at path \(path!)")
                        
              return ResourceBuffer(data:nsData.bytes, size:Int64(nsData.length), id:UInt32(resId))
          } catch {
            print("ERROR LOADING RESOURCE")
          }
        }
        return ResourceBuffer()
    }
    
    var freeResource : @convention(c) (ResourceBuffer,UnsafeMutableRawPointer?) -> () = { rbuf, resourcesPtr in
        let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        instance.resources.removeValue(forKey:rbuf.id)
    }

    var markTextureFrameAvailable : @convention(c) (UnsafeMutableRawPointer?) -> () = { instancePtr in
        let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(instancePtr!).takeUnretainedValue()
        instance.registry.textureFrameAvailable(instance.flutterTextureId!)
    }
    
   var displayLinkRenderCallback : @convention(c) (CVDisplayLink, UnsafePointer<CVTimeStamp>, UnsafePointer<CVTimeStamp>, CVOptionFlags, UnsafeMutablePointer<CVOptionFlags>, UnsafeMutableRawPointer?) -> CVReturn = { displayLink, ts1, ts2, options, optionsPtr, resourcesPtr in
       let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()

       if(instance.viewer != nil && instance.rendering) {
           instance.doRender()
       }
       return 0
    }
    
    func doRender() {
        DispatchQueue.main.async {
            render(self.viewer, 0)
            self.registry.textureFrameAvailable(self.flutterTextureId!)
        }
    }
    
    func createDisplayLink() {
        let displayID = CGMainDisplayID()
        let error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
        if (error != 0)
        {
            print("DisplayLink created with error \(error)");
        }
        CVDisplayLinkSetOutputCallback(displayLink!, displayLinkRenderCallback, unsafeBitCast(self, to:UnsafeMutableRawPointer.self))
        
        CVDisplayLinkStart(displayLink!);

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
        let instance = SwiftPolyvoxFilamentPlugin(textureRegistry: registrar.textures, registrar:registrar)
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
    
    private func resize(width:Int32, height:Int32) {
        if(self.flutterTextureId != nil) {
            self.registry.unregisterTexture(self.flutterTextureId!)
        }
        createPixelBuffer(width: Int(width), height:Int(height))
    }
    
    var cvMetalTextureCache:CVMetalTextureCache? = nil
    var cvMetalTexture:CVMetalTexture? = nil
    var metalTexture:MTLTexture? = nil
    var metalDevice:MTLDevice? = nil
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName = call.method;
        switch methodName {
        case "getSharedContext":
            result(nil)
        case "getResourceLoaderWrapper":
            let resourceLoaderWrapper = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())
            result(unsafeBitCast(resourceLoaderWrapper, to:Int64.self))
        case "getRenderCallback":
            let renderCallback = markTextureFrameAvailable
            result([
                unsafeBitCast(renderCallback, to:Int64.self), unsafeBitCast(Unmanaged.passUnretained(self), to:UInt64.self)])
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
            metalTexture = CVMetalTextureGetTexture(cvMetalTexture!);
            // createDisplayLink()
            let pixelBufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer!);
            let pixelBufferAddress = Int(bitPattern:pixelBufferPtr);
            let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
            let metalTextureAddress = Int(bitPattern:metalTexturePtr)

            let callback = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())
                                                                                            
            result([self.flutterTextureId as Any, nil, metalTextureAddress])
        case "destroyTexture":
            if(viewer != nil) {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Destroy the viewer before destroying the texture", details: nil))
            } else {
                
                if(self.flutterTextureId != nil) {
                    self.registry.unregisterTexture(self.flutterTextureId!)
                }
                self.flutterTextureId = nil 
                self.pixelBuffer = nil
            }
        case "destroyViewer":
            if(viewer != nil) {
                destroy_swap_chain(viewer)
                destroy_filament_viewer(viewer)
                viewer = nil
            }
            result(true)
        case "resize":
            if(viewer == nil) {
                print("Error: cannot resize before a viewer has been created")
                result(nil);
            }
            rendering = false
            destroy_swap_chain(viewer)
            let args = call.arguments as! [Any]
            let width = UInt32(args[0] as! Int64)
            let height = UInt32(args[1] as! Int64)
            resize(width:Int32(width), height:Int32(height))
            create_swap_chain(viewer, CVPixelBufferGetBaseAddress(pixelBuffer!), width, height)
            let metalTextureId = Int(bitPattern:Unmanaged.passUnretained(metalTexture!).toOpaque())
            create_render_target(viewer, metalTextureId, width, height);
            update_viewport_and_camera_projection(viewer, width, height, Float(args[2] as! Double))
            rendering = true
            print("Resized to \(args[0])x\(args[1])")
            result(self.flutterTextureId);
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

