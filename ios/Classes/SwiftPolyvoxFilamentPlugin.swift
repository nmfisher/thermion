import Flutter
import UIKit
import GLKit

public class SwiftPolyvoxFilamentPlugin: NSObject, FlutterPlugin, FlutterTexture {
  
    var registrar : FlutterPluginRegistrar
    var textureId: Int64?
    var registry: FlutterTextureRegistry

    var width: Double = 0
    var height: Double = 0
  
    
    var targetPixelBuffer: CVPixelBuffer?;
    // var context: EAGLContext?;
    // var textureCache: CVOpenGLESTextureCache?;
    // var texture: CVOpenGLESTexture? = nil;
    // var frameBuffer: GLuint = 0;
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary

    var resources:NSMutableDictionary = [:]
    var viewer:UnsafeMutableRawPointer? = nil
  
    var displayLink:CADisplayLink? = nil
    
    static var messenger : FlutterBinaryMessenger? = nil;
  
    var loadResourcePtr: UnsafeMutableRawPointer? = nil
    var freeResourcePtr: UnsafeMutableRawPointer? = nil
    var resourcesPtr : UnsafeMutableRawPointer? = nil
  
    var _rendering = true
  
    var loadResource : @convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer) -> ResourceBuffer = { uri, resourcesPtr in
      
      let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr).takeUnretainedValue()

      let uriString = String(cString:uri.assumingMemoryBound(to: UInt8.self))

      var path:String? = nil
      
      let appFolder = Bundle.main.resourceURL
      let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationDirectory,
                    .userDomainMask, true)
      let supportDirPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                    .userDomainMask, true)
      let devFsPath = URL(fileURLWithPath: supportDirPaths.first!, isDirectory:true).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("tmp")
      
      var found : URL? = nil

      let orderedURLs = try? FileManager.default.enumerator(at: devFsPath, includingPropertiesForKeys: [ .pathKey, .creationDateKey], options: .skipsHiddenFiles)
      for case let fileURL as URL in orderedURLs! {
        if !(fileURL.path.hasSuffix(uriString)) {
          continue
        }
        if found == nil {
          found = fileURL
        } else {
          do {
            let c1 = try found!.resourceValues(forKeys: [.creationDateKey]).creationDate
            let c2 = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate
            if c1! < c2! {
              found = fileURL
            }
          } catch {
            
          }
        }
      }
      
      if found != nil {
        path = found?.path
      } else {
        if(uriString.hasPrefix("file://")) {
          path = String(uriString.dropFirst(7))
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
          return ResourceBuffer()
      }
        return ResourceBuffer()
    }
  
    var freeResource : @convention(c) (UInt32,UnsafeMutableRawPointer) -> () = { rid, resourcesPtr in
      let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr).takeUnretainedValue()
      instance.resources.removeObject(forKey:rid)
    }
  
    func createDisplayLink() {
      displayLink = CADisplayLink(target: self,
                                      selector: #selector(doRender))
      displayLink!.add(to: .current, forMode:  RunLoop.Mode.default)
    }
  
    @objc func doRender() {
        guard _rendering == true, let textureId = self.textureId, let viewer = viewer else {
          return
        }
        render(viewer, 0)
        self.registry.textureFrameAvailable(textureId)
    }
  
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(targetPixelBuffer == nil) {
            print("empty")
            return nil;
        } 
        return Unmanaged.passRetained(targetPixelBuffer!);
    }
  
    public func onTextureUnregistered(texture:FlutterTexture) {
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
      
      if(targetPixelBuffer != nil) {
        destroy_swap_chain(self.viewer)
      }
      if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                                      kCVPixelFormatType_32BGRA, pixelBufferAttrs, &targetPixelBuffer) != kCVReturnSuccess) {
        print("Error allocating pixel buffer")
      }
      print("Pixel buffer created")
    }
  
    private func initialize(width:Int32, height:Int32) {

      if(self.viewer != nil) { 
        clear_assets(self.viewer)
        clear_lights(self.viewer)
        destroy_swap_chain(self.viewer)
        filament_viewer_delete(self.viewer)
      }

      print("Initializing with size \(width)x\(height)")

      createPixelBuffer(width:Int(width), height:Int(height))
      self.textureId = self.registry.register(self)

      loadResourcePtr = unsafeBitCast(loadResource, to: UnsafeMutableRawPointer.self)
      freeResourcePtr = unsafeBitCast(freeResource, to: UnsafeMutableRawPointer.self)

      viewer = filament_viewer_new_ios(
        nil,
        loadResourcePtr!,
        freeResourcePtr!,
        Unmanaged.passUnretained(self).toOpaque()
      )

      create_swap_chain(
        self.viewer, 
        unsafeBitCast(targetPixelBuffer!, to: UnsafeMutableRawPointer.self),
        UInt32(width), UInt32(height))

      update_viewport_and_camera_projection(self.viewer!, width, height, 1.0);
      
      createDisplayLink()

    }
  
  private func resize(width:Int32, height:Int32) {
    print("Resizing to size \(width)x\(height)")
    if(self.textureId != nil) {
      self.registry.unregisterTexture(self.textureId!)
    }
    createPixelBuffer(width: Int(width), height:Int(height))

    create_swap_chain(
      self.viewer,
      unsafeBitCast(targetPixelBuffer!, to: UnsafeMutableRawPointer.self),
      UInt32(width), UInt32(height))

    update_viewport_and_camera_projection(self.viewer!, width, height, 1.0);

    self.textureId = self.registry.register(self)
  }
  
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let methodName = call.method;

      switch methodName {
        
          case "addLight":
            let args = call.arguments as! Array<Any>
            let entity = add_light(
              self.viewer,
              args[0] as! UInt8,
              Float(args[1] as! Double),
              Float(args[2] as! Double),
              Float(args[3] as! Double),
              Float(args[4] as! Double),
              Float(args[5] as! Double),
              Float(args[6] as! Double),
              Float(args[7] as! Double),
              Float(args[8] as! Double),
              args[9] as! Bool)
            result(entity);
          case "setAnimation":
            let args = call.arguments as! Array<Any?>
            let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
            let entityName = args[1] as! String
            let morphData = (args[2] as! FlutterStandardTypedData)
            
            let numMorphWeights = args[3] as! Int
            
            let boneAnimations = args[4] as! Array<Array<Any?>>
            let numBoneAnimations = boneAnimations.count
            
            var boneAnimStructs = UnsafeMutableBufferPointer<BoneAnimation>.allocate(capacity: numBoneAnimations)
            if numBoneAnimations > 0 {
              for i in 0...numBoneAnimations - 1 {
                let boneNames = boneAnimations[i][0] as! Array<String>
                let meshNames = boneAnimations[i][1] as! Array<String>
                let frameData = (boneAnimations[i][2] as! FlutterStandardTypedData)
                let frameDataNative =  UnsafeMutableBufferPointer<Float>.allocate(capacity: Int(frameData.elementCount))
                
                frameData.data.withUnsafeBytes{ (floatPtr: UnsafePointer<Float>) in
                  for i in 0...Int(frameData.elementCount - 1) {
                    frameDataNative[i] = floatPtr.advanced(by: i).pointee
                  }
                }
                
                var boneNameArray =  UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: boneNames.count)
                
                for i in 0...boneNames.count - 1 {
                  boneNameArray[i] = UnsafePointer(strdup(boneNames[i]))
                }
                
                var meshNameArray =  UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: meshNames.count)
                
                for i in 0...meshNames.count - 1 {
                  meshNameArray[i] = UnsafePointer(strdup(meshNames[i]))
                }
                boneAnimStructs[i] = BoneAnimation(
                  boneNames: boneNameArray.baseAddress,
                  meshNames:meshNameArray.baseAddress,
                  data:frameDataNative.baseAddress,
                  numBones: boneNames.count,
                  numMeshTargets: meshNames.count
                )
              }
            }
            
                  
            let numFrames = args[5] as! Int
            let frameLenInMs = args[6] as! Double
            morphData.data.withUnsafeBytes { (morphDataNative: UnsafePointer<Float>) in
              set_animation(
                assetPtr,
                entityName,
                morphDataNative,
                Int32(numMorphWeights),
                boneAnimStructs.baseAddress,
                Int32(boneAnimations.count),
                Int32(numFrames),
                Float(frameLenInMs)
              )
            }
            
            boneAnimStructs.forEach { (boneAnimStruct:BoneAnimation) in

              for i in 0...boneAnimStruct.numBones - 1 {
                boneAnimStruct.boneNames[i]?.deallocate()
              }
              boneAnimStruct.boneNames.deallocate()
              
              for i in 0...boneAnimStruct.numMeshTargets - 1 {
                boneAnimStruct.meshNames[i]?.deallocate()
              }
              boneAnimStruct.meshNames.deallocate()
              
              boneAnimStruct.data.deallocate();
              
            }
            boneAnimStructs.deallocate()
            result("OK")
        case "initialize":
            let args = call.arguments as! Array<Int32>
            initialize(width:args[0], height:args[1])
            result(self.textureId);        
        case "clearLights":
           clear_lights(self.viewer);
           result(true);
        case "loadSkybox":
            load_skybox(self.viewer!, call.arguments as! String)
            result("OK");
        case "removeSkybox":
            remove_skybox(self.viewer!)
            result("OK");
        case "loadGlb":
            let assetPtr = load_glb(self.viewer, call.arguments as! String)
            result(unsafeBitCast(assetPtr, to:Int64.self));
        case "loadGltf":
          let args = call.arguments as! Array<Any?>
          result(load_gltf(self.viewer, args[0] as! String, args[1] as! String));
        case "removeAsset":
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: call.arguments as! Int)
          remove_asset(viewer!, assetPtr)
          result("OK")
        case "clearAssets":
          clear_assets(viewer!)
          result("OK")
        case "loadIbl":
          load_ibl(self.viewer, call.arguments as! String)
          result("OK");
        case "removeIbl":
          remove_ibl(self.viewer)
          result("OK");
        case "setCamera":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          set_camera(self.viewer, assetPtr, args[1] as! String)
          result("OK");
        case "playAnimation":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let animationIndex = args[1] as! Int32;
          let loop = args[2] as! Bool;
          let reverse = args[3] as! Bool;
          play_animation(assetPtr, animationIndex, loop, reverse)
          result("OK");
        case "setAnimationFrame":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let animationIndex = args[1] as! Int32;
          let animationFrame = args[2] as! Int32;
          set_animation_frame(assetPtr, animationIndex, animationFrame)
          result("OK");
        case "stopAnimation":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let animationIndex = args[1] as! Int32
          stop_animation(assetPtr, animationIndex) // TODO
          result("OK");
        case "getMorphTargetNames":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let meshName = args[1] as! String
          let numNames = get_morph_target_name_count(assetPtr, meshName)
          var names = [String]()
          if(numNames > 0) {
            for i in 0...numNames - 1 {
              let outPtr = UnsafeMutablePointer<CChar>.allocate(capacity:256)
              get_morph_target_name(assetPtr, meshName, outPtr, i)
              names.append(String(cString:outPtr))
            }
          }
          result(names);
        case "getAnimationNames":
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: call.arguments as! Int)
          let numNames = get_animation_count(assetPtr)
          var names = [String]()
          for i in 0..<numNames {
            let outPtr = UnsafeMutablePointer<CChar>.allocate(capacity:256)
            get_animation_name(assetPtr, outPtr, i)
            names.append(String(cString:outPtr))
          }
          result(names);
        case "setMorphTargetWeights":
          let args = call.arguments as! Array<Any?>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let entityName = args[1] as! String
          let weights = args[2] as! Array<Float>
          let count = args[3] as! Int
          weights.map { Float($0) }.withUnsafeBufferPointer {
            apply_weights(assetPtr, entityName, UnsafeMutablePointer<Float>.init(mutating:$0.baseAddress), Int32(count))

          }
          result("OK")
        case "panStart":
          let args = call.arguments as! Array<Any>
          grab_begin(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double), true)
          result("OK")
        case "panUpdate":
          let args = call.arguments as! Array<Any>
          grab_update(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double))
          result("OK")
        case "panEnd":
          grab_end(self.viewer)
          result("OK")
        case "removeLight":
           remove_light(self.viewer,call.arguments as! Int32)
           result(true);
        case "render":
          doRender()
          result("OK")
        case "resize":
          let args = call.arguments as! Array<Double>
          let width = Int32(args[0])
          let height = Int32(args[1])
        resize(width:width, height:height)
          result(self.textureId)
        case "rotateStart":
          let args = call.arguments as! Array<Any>
          grab_begin(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double), false)
          result("OK")
        case "rotateUpdate":
          let args = call.arguments as! Array<Any>
          grab_update(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double))
          result("OK")
        case "rotateEnd":
          grab_end(self.viewer)
          result("OK")
        case "setBackgroundImage":
            let uri = call.arguments as! String
            set_background_image(self.viewer!, uri)
            render(self.viewer!, 0)
            self.registry.textureFrameAvailable(self.textureId!)
            result("OK")
        case "setBackgroundImagePosition":
            let args = call.arguments as! Array<Any>
            set_background_image_position(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double), args[2] as! Bool)
            result("OK");
        case "setPosition":
          let args = call.arguments as! Array<Any>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          let x = Float(args[1] as! Double)
          set_position(assetPtr, x, Float(args[2] as! Double), Float(args[3] as! Double))
          result("OK")
        case "setRotation":
          let args = call.arguments as! Array<Any>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          set_rotation(assetPtr, Float(args[1] as! Double), Float(args[2] as! Double), Float(args[3] as! Double), Float(args[4] as! Double))
          result("OK")
        case "setScale":
          let args = call.arguments as! Array<Any>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          set_scale(assetPtr, Float(args[1] as! Double))
          result("OK");
        case "setCameraPosition":
          let args = call.arguments as! Array<Any>
          set_camera_position(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double), Float(args[2] as! Double))
          result("OK");
        case "setCameraRotation":
          let args = call.arguments as! Array<Any>
          set_camera_rotation(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double), Float(args[2] as! Double),Float(args[3] as! Double))
          result("OK")
        case "setCameraModelMatrix":
          let matrix = call.arguments as! FlutterStandardTypedData
          matrix.data.withUnsafeBytes{ (floatPtr: UnsafePointer<Float>) in
            set_camera_model_matrix(self.viewer, floatPtr)
          }
          result("OK")
        case "setCameraFocalLength":
          set_camera_focal_length(self.viewer, Float(call.arguments as! Double))
          result("OK");
        case "setCameraFocusDistance":
          // TODO
        //          set_camera_focus_distance(self.viewer, Float(call.arguments as! Double))
        //          result("OK");
          break
        case "setFrameInterval":
          set_frame_interval(self.viewer, Float(call.arguments as! Double));
          result("OK")
        case "setRendering":
          _rendering = call.arguments as! Bool
          result("OK")
        case "setTexture":
          let args = call.arguments as! Array<Any>
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
          load_texture(assetPtr, args[1] as! String, args[2] as! Int32)
          result("OK");
        case "transformToUnitCube":
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: call.arguments as! Int)
          transform_to_unit_cube(assetPtr)
          result("OK");
        case "zoomBegin":
          scroll_begin(self.viewer)
          result("OK")
        case "zoomUpdate":
          let args = call.arguments as! Array<Any?>
          scroll_update(self.viewer, Float(args[0] as! Double), Float(args[1] as! Double),Float(args[2] as! Double))
          result("OK")
        case "zoomEnd":
          scroll_end(self.viewer)
          result("OK")
        default:
          result(FlutterMethodNotImplemented)
      }
    }
}

