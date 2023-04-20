import Flutter
import UIKit
import GLKit

public class SwiftPolyvoxFilamentPlugin: NSObject, FlutterPlugin, FlutterTexture {
  
    var registrar : FlutterPluginRegistrar
    var flutterTextureId: Int64?
    var registry: FlutterTextureRegistry
   
    var pixelBuffer: CVPixelBuffer?;
    
    var createdAt = Date()
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary

    var resources:NSMutableDictionary = [:]
  
    var displayLink:CADisplayLink? = nil
    
    static var messenger : FlutterBinaryMessenger? = nil;
  
    var loadResourcePtr: UnsafeMutableRawPointer? = nil
    var freeResourcePtr: UnsafeMutableRawPointer? = nil
 
  
    var loadResource : @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> ResourceBuffer = { uri, resourcesPtr in
      
        let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()

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
        print("Opening data from path \(path)")
        let data = try Data(contentsOf: URL(fileURLWithPath:path!))
        let resId = instance.resources.count
        let nsData = data as NSData
        instance.resources[resId] = nsData
        let rawPtr = nsData.bytes
        return ResourceBuffer(data:rawPtr, size:UInt32(nsData.count), id:UInt32(resId))
      } catch {
          print("Error opening file: \(error)")
      }
      return ResourceBuffer()
    }
  
    var freeResource : @convention(c) (ResourceBuffer,UnsafeMutableRawPointer?) -> () = { rbuf, resourcesPtr in
      let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr!).takeUnretainedValue()
        instance.resources.removeObject(forKey:rbuf.id)
    }
    
    @objc func doRender() {
        
    }
  
    func createDisplayLink() {
      displayLink = CADisplayLink(target: self,
                                      selector: #selector(doRender))
      displayLink!.add(to: .current, forMode:  RunLoop.Mode.default)
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(pixelBuffer == nil) {
            print("empty")
            return nil;
        } 
        return Unmanaged.passRetained(pixelBuffer!);
    }
  
    public func onTextureUnregistered(_ texture:FlutterTexture) {
        print("Texture unregistered")
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger();
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "app.polyvox.filament/event", binaryMessenger: _messenger)
      let instance = SwiftPolyvoxFilamentPlugin(textureRegistry: registrar.textures(), registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
  
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
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
  
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let methodName = call.method;
      print(methodName)
      switch methodName {
        case "createTexture":
          let args = call.arguments as! Array<Int32>
          createPixelBuffer(width:Int(args[0]), height:Int(args[1]))
          createDisplayLink()
          result(self.flutterTextureId)
          //          print("texture id \(pixelBufferflutterTextureId)")
        case "getLoadResourceFn":

          let callback = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())

          result(unsafeBitCast(callback,  to:Int64.self))
        case "getFreeResourceFn":
          result(unsafeBitCast(freeResource,  to:Int64.self))
        case "getGlTextureId":
          result(FlutterMethodNotImplemented)
      case "getSurface":
          var pixelBufferTextureId = Int64(Int(bitPattern:unsafeBitCast(pixelBuffer!, to: UnsafeMutableRawPointer.self)))
          result(pixelBufferTextureId)

        case "getContext":
           result(0) //nullptr
        case "resize":
          result(self.flutterTextureId);
        case "tick":
          self.registry.textureFrameAvailable(flutterTextureId!)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
      }
    }
}

