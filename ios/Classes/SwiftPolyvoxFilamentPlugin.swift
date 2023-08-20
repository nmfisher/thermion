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
    
    var viewer:UnsafeRawPointer? = nil
    var displayLink:CADisplayLink? = nil
    var rendering:Bool = false
    
    static var messenger : FlutterBinaryMessenger? = nil;
    
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
        if(viewer != nil && rendering) {
            render(viewer, 0)
            self.registry.textureFrameAvailable(flutterTextureId!)
        }
    }
    
    func createDisplayLink() {
        displayLink = CADisplayLink(target: self,
                                    selector: #selector(doRender))
        displayLink!.add(to: .current, forMode:  RunLoop.Mode.default)
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
        switch methodName {
        case "createTexture":
            let args = call.arguments as! Array<Int32>
            createPixelBuffer(width:Int(args[0]), height:Int(args[1]))
            createDisplayLink()
            result(self.flutterTextureId)
        case "resize":
            if(viewer == nil) {
                print("Error: cannot resize before a viewer has been created")
                result(nil);
            }
            rendering = false
            destroy_swap_chain(viewer)
            let args = call.arguments as! [Any]
            resize(width:args[0] as! Int32, height:args[1] as! Int32)
            var pixelBufferTextureId = unsafeBitCast(pixelBuffer!, to: UnsafeRawPointer.self)
            create_swap_chain(viewer, pixelBufferTextureId, UInt32(args[0] as! Int64), UInt32(args[1] as! Int64))
            update_viewport_and_camera_projection(viewer, Int32(args[0] as! Int64), Int32(args[1] as! Int64), Float(args[2] as! Double))
            rendering = true
            print("Resized to \(args[0])x\(args[1])")
            result(self.flutterTextureId);
        case "createFilamentViewer":
            let callback = make_resource_loader(loadResource, freeResource,  Unmanaged.passUnretained(self).toOpaque())
            let args = call.arguments as! [Any]
            let width = args[0] as! Int64
            let height = args[1] as! Int64
            viewer = create_filament_viewer(nil, callback)
            var pixelBufferTextureId = unsafeBitCast(pixelBuffer!, to: UnsafeRawPointer.self)
            create_swap_chain(viewer, pixelBufferTextureId, UInt32(width), UInt32(height))
            update_viewport_and_camera_projection(viewer, Int32(args[0] as! Int64), Int32(args[1] as! Int64), 1.0)
            result(unsafeBitCast(viewer, to:Int64.self))
        case "deleteFilamentViewer":
            delete_filament_viewer(viewer)
            viewer = nil
            result(true)
        case "getAssetManager":
            let assetManager = get_asset_manager(viewer)
            result(unsafeBitCast(assetManager, to:Int64.self))
        case "clearBackgroundImage":
            clear_background_image(viewer)
            result(true)
        case "setBackgroundImage":
            set_background_image(viewer, call.arguments as! String)
            result(true)
        case "setBackgroundImagePosition":
            let args = call.arguments as! [Any]
            set_background_image_position(viewer, Float(args[0] as! Double), Float(args[1] as! Double), args[2] as! Bool)
            result(true)
        case "setBackgroundColor":
            guard let args = call.arguments as? [Double], args.count == 4 else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected RGBA values for setBackgroundColor", details: nil))
                return
            }
            set_background_color(viewer, Float(args[0]), Float(args[1]), Float(args[2]), Float(args[3]))
            result(true)
        
        case "loadSkybox":
            
            load_skybox(viewer, call.arguments as! String)
            result(true)
        case "loadIbl":
            let args = call.arguments as! [Any]
            load_ibl(viewer, args[0] as! String, args[1] as! Float)
            result(true)
        case "removeSkybox":
            remove_skybox(viewer)
            result(true)
        case "removeIbl":
            remove_ibl(viewer)
            result(true)
        case "addLight":
            guard let args = call.arguments as? [Any], args.count == 10,
                  let type = args[0] as? Int32,
                  let colour = args[1] as? Double,
                  let intensity = args[2] as? Double,
                  let posX = args[3] as? Double,
                  let posY = args[4] as? Double,
                  let posZ = args[5] as? Double,
                  let dirX = args[6] as? Double,
                  let dirY = args[7] as? Double,
                  let dirZ = args[8] as? Double,
                  let shadows = args[9] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected viewer and light parameters for addLight", details: nil))
                return
            }
            let entityId = add_light(viewer, UInt8(type), Float(colour), Float(intensity),Float(posX), Float(posY), Float(posZ), Float(dirX), Float(dirY), Float(dirZ), shadows)
            result(entityId)
            
        case "removeLight":
            remove_light(viewer, Int32(call.arguments as! Int64))
            result(true)
        case "clearLights":
            clear_lights(viewer)
            result(true)
        case "loadGlb":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let assetPath = args[1] as? String,
                  let unlit = args[2] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected assetManager, assetPath, and unlit for load_glb", details: nil))
                return
            }
            let entityId = load_glb(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), assetPath, unlit)
            result(entityId)
        case "loadGltf":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let assetPath = args[1] as? String,
                  let relativePath = args[2] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected assetManager, assetPath, and relativePath for load_gltf", details: nil))
                return
            }
            let entityId = load_gltf(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), assetPath, relativePath)
            result(entityId)
        case "transformToUnitCube":
            let args = call.arguments as! [Any]
            transform_to_unit_cube(unsafeBitCast(args[0] as! Int64, to:UnsafeMutableRawPointer.self), args[1] as! EntityId)
            result(true)
        case "render":
            render(viewer, 0)
            result(true)
        case "setRendering":
            rendering = call.arguments as! Bool
            result(true)
        case "setFrameInterval":
            let interval = call.arguments as! Double
            displayLink!.preferredFramesPerSecond = Int(1 / interval)
            print("Set preferred frames er second to \(displayLink!.preferredFramesPerSecond)")
            let fInterval = Float(interval)
            print("Set filament interval to \(fInterval)")
            set_frame_interval(viewer, fInterval)
            result(true)
        case "updateViewportAndCameraProjection":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let width = args[0] as? Int,
                  let height = args[1] as? Int,
                  let scaleFactor = args[2] as? Float else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected viewer, width, height, and scaleFactor for update_viewport_and_camera_projection", details: nil))
                return
            }
            update_viewport_and_camera_projection(viewer, Int32(width), Int32(height), scaleFactor)
            result(true)
        case "scrollBegin":
            scroll_begin(viewer)
            result(true)
        case "scrollUpdate":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let x = args[0] as? Double,
                  let y = args[1] as? Double,
                  let z = args[2] as? Double else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected viewer, x, y, and z for scroll_update", details: nil))
                return
            }
            scroll_update(viewer, Float(x), Float(y), Float(z))
            result(true)
            
        case "scrollEnd":
            scroll_end(viewer)
            result(true)
        case "grabBegin":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let x = args[0] as? Double,
                  let y = args[1] as? Double,
                  let pan = args[2] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected viewer, x, y, and pan for grab_begin", details: nil))
                return
            }
            grab_begin(viewer, Float(x), Float(y), pan)
            result(true)
            
        case "grabUpdate":
            guard let args = call.arguments as? [Any], args.count == 2,
                  let x = args[0] as? Float,
                  let y = args[1] as? Float else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected viewer, x, and y for grab_update", details: nil))
                return
            }
            grab_update(viewer, x, y)
            result(true)
            
        case "grabEnd":
            grab_end(viewer)
            result(true)
        case "applyWeights":
            guard let args = call.arguments as? [Any], args.count == 5,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let entityName = args[2] as? String,
                  let weights = args[3] as? [Float],
                  let count = args[4] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for apply_weights", details: nil))
                return
            }
            //                  apply_weights(assetManager, asset, entityName, UnsafeMutablePointer(&weights), Int32(count))
            result(true)
        case "setMorphTargetWeights":
            guard let args = call.arguments as? [Any], args.count == 5,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let entityName = args[2] as? String,
                  let morphData = args[3] as? [Double],
                  let numMorphWeights = args[4] as? Int32 else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for setMorphTargetWeights", details: nil))
                return
            }
            
            set_morph_target_weights(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, entityName, morphData.map { Float($0) }, Int32(numMorphWeights))

            result(true)
            
        case "setMorphAnimation":
            guard let args = call.arguments as? [Any], args.count == 8,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let entityName = args[2] as? String,
                  let morphData = args[3] as? [Double],
                  let morphIndices = args[4] as? [Int32],
                  let numMorphTargets = args[5] as? Int32,
                  let numFrames = args[6] as? Int32,
                  let frameLengthInMs = args[7] as? Double else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Incorrect arguments provided for setMorphAnimation", details: nil))
                return
            }
            let frameData = morphData.map { Float($0) }
            let am = unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self)
                    
            let success = set_morph_animation(
                        am, 
                        asset, 
                        entityName, 
                        frameData, 
                        morphIndices,
                        Int32(numMorphTargets), 
                        Int32(numFrames),
                        Float(frameLengthInMs))
            result(success)
        case "setBoneAnimation":
            guard let args = call.arguments as? [Any], args.count == 9,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let frameData = args[2] as? [Float],
                  let numFrames = args[3] as? Int,
                  let numBones = args[4] as? Int,
                  let boneNames = args[5] as? [String],
                  let meshName = args[6] as? [String],
                  let numMeshTargets = args[7] as? Int,
                  let frameLengthInMs = args[8] as? Float else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for set_bone_animation", details: nil))
                return
            }
            
            //                  // Convert boneNames and meshName to C-style strings array.
            //                  var cBoneNames: [UnsafePointer<CChar>?] = boneNames.map { $0.cString(using: .utf8) }
            //                  var cMeshName: [UnsafePointer<CChar>?] = meshName.map { $0.cString(using: .utf8) }
            //
            //                  set_bone_animation(assetManager, asset, UnsafeMutablePointer(&frameData), numFrames, numBones, &cBoneNames, &cMeshName, numMeshTargets, frameLengthInMs)
            
            //                  // Clean up after conversion
            //                  for cStr in cBoneNames { free(UnsafeMutablePointer(mutating: cStr)) }
            //                  for cStr in cMeshName { free(UnsafeMutablePointer(mutating: cStr)) }
            
            result(true)
            
        case "playAnimation":
            guard let args = call.arguments as? [Any], args.count == 7,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let index = args[2] as? Int,
                  let loop = args[3] as? Bool,
                  let reverse = args[4] as? Bool,
                  let replaceActive = args[5] as? Bool,
                  let crossfade = args[6] as? Double else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for play_animation", details: nil))
                return
            }
            play_animation(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, Int32(index), loop, reverse, replaceActive, Float(crossfade))
            result(true)
        case "getAnimationDuration":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let animationIndex = args[2] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for getAnimationDuration", details: nil))
                return
            }
            
            let dur = get_animation_duration(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, Int32(animationIndex))
            result(dur)
            
        case "setAnimationFrame":
            guard let args = call.arguments as? [Any], args.count == 4,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let animationIndex = args[2] as? Int,
                  let animationFrame = args[3] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for set_animation_frame", details: nil))
                return
            }
            
            set_animation_frame(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, Int32(animationIndex), Int32(animationFrame))
            result(true)
            
        case "stopAnimation":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let index = args[2] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for stop_animation", details: nil))
                return
            }
            stop_animation(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, Int32(index))
            result(true)
        case "getAnimationCount":
            guard let args = call.arguments as? [Any], args.count == 2,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_animation_count", details: nil))
                return
            }
            
            let count = get_animation_count(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset)
            result(count)
        case "getAnimationNames":
            guard let args = call.arguments as? [Any], args.count == 2,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_animation_name", details: nil))
                return
            }
            var names:[String] = [];
            var count = get_animation_count(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset)
            var buffer = [CChar](repeating: 0, count: 256)  // Assuming max name length of 256 for simplicity
            for i in 0...count - 1 {
                get_animation_name(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, &buffer, Int32(i))
                let name = String(cString: buffer)
                names.append(name)
            }
            result(names)
        case "getAnimationName":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let index = args[2] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_animation_name", details: nil))
                return
            }
            
            var buffer = [CChar](repeating: 0, count: 256)  // Assuming max name length of 256 for simplicity
            get_animation_name(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, &buffer, Int32(index))
            let name = String(cString: buffer)
            result(name)
            
        case "getMorphTargetName":
            guard let args = call.arguments as? [Any], args.count == 4,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String,
                  let index = args[3] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_morph_target_name", details: nil))
                return
            }
            
            var buffer = [CChar](repeating: 0, count: 256)  // Assuming max name length of 256 for simplicity
            get_morph_target_name(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName, &buffer, Int32(index))
            let targetName = String(cString: buffer)
            result(targetName)
        case "getMorphTargetNames":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_morph_target_name", details: nil))
                return
            }
            let count = get_morph_target_name_count(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName)
            var names:[String] = []
            if count > 0 {
                for i in 0...count - 1 {
                    var buffer = [CChar](repeating: 0, count: 256)  // Assuming max name length of 256 for simplicity
                    get_morph_target_name(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName, &buffer, Int32(i))
                    names.append(String(cString:buffer))
                }
            }
            result(names)
        case "getMorphTargetNameCount":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for get_morph_target_name_count", details: nil))
                return
            }
            
            let count = get_morph_target_name_count(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName)
            result(count)
            
        case "removeAsset":
            remove_asset(viewer, call.arguments as! EntityId)
            result(true)
        case "clearAssets":
            clear_assets(viewer)
            result(true)
        case "setCamera":
            guard let args = call.arguments as? [Any], args.count == 2,
                  let asset = args[0] as? EntityId,
                  let nodeName = args[1] as? String? else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected asset and nodeName for set_camera", details: nil))
                return
            }
            let success = set_camera(viewer, asset, nodeName)
            result(success)

        case "setCameraPosition":
            let args = call.arguments as! [Any]
            set_camera_position(viewer, Float(args[0] as! Double), Float(args[1] as! Double), Float(args[2] as! Double))
            result(true)
            
        case "setCameraRotation":
            let args = call.arguments as! [Any]
            set_camera_rotation(viewer, Float(args[0] as! Double), Float(args[1] as! Double), Float(args[2] as! Double), Float(args[3] as! Double))
            result(true)
        case "setCameraModelMatrix":
            guard let matrix = call.arguments as? [Float], matrix.count == 16 else {  // Assuming a 4x4 matrix
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for set_camera_model_matrix", details: nil))
                return
            }
            set_camera_model_matrix(viewer, matrix)
            result(true)
        case "setCameraFocalLength":
            set_camera_focal_length(viewer, call.arguments as! Float)
            result(true)
        case "setCameraFocusDistance":
            set_camera_focus_distance(viewer, call.arguments as! Float)
            result(true)
        case "setMaterialColor":
            guard let args = call.arguments as? [Any], args.count == 5,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String, 
                  let materialIndex = args[3] as? Int32, 
                  let color = args[4] as? [Double] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for setMaterialColor", details: nil))
                return
            }
            set_material_color(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName, materialIndex, Float(color[0]), Float(color[1]), Float(color[2]), Float(color[3]))
            result(true)
            
        case "hideMesh":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for hide_mesh", details: nil))
                return
            }
            
            let status = hide_mesh(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName)
            result(status)
            
        case "revealMesh":
            guard let args = call.arguments as? [Any], args.count == 3,
                  let assetManager = args[0] as? Int64,
                  let asset = args[1] as? EntityId,
                  let meshName = args[2] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for reveal_mesh", details: nil))
                return
            }
            
            let status = reveal_mesh(unsafeBitCast(assetManager, to:UnsafeMutableRawPointer.self), asset, meshName)
            result(status)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

