import Foundation
import GLKit
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

// To register a native Metal texture with the Flutter compositor/texture registry, we need a wrapper
// that implements the [FlutterTexture] protocol.
//
// This is no longer managed by the native platform channel; all texture lifecycle ownership
// (register/unregister/textureFrameAvailable) now lives in [darwin_platform_texture_descriptor.dart].
public class FlutterMetalTextureWrapper : NSObject, FlutterTexture {
    private static let lifetimeLock = NSLock()
    private static var liveInstances: Int64 = 0
    private static var createdInstances: Int64 = 0

    private var texture: MetalTextureWrapper

    @objc public init(texture: MetalTextureWrapper) {
        self.texture = texture
        super.init()
        FlutterMetalTextureWrapper.lifetimeLock.lock()
        FlutterMetalTextureWrapper.liveInstances += 1
        FlutterMetalTextureWrapper.createdInstances += 1
        FlutterMetalTextureWrapper.lifetimeLock.unlock()
    }

    deinit {
        FlutterMetalTextureWrapper.lifetimeLock.lock()
        FlutterMetalTextureWrapper.liveInstances -= 1
        FlutterMetalTextureWrapper.lifetimeLock.unlock()
    }

    fileprivate static func liveInstanceCount() -> Int64 {
        lifetimeLock.lock()
        defer { lifetimeLock.unlock() }
        return liveInstances
    }

    fileprivate static func createdInstanceCount() -> Int64 {
        lifetimeLock.lock()
        defer { lifetimeLock.unlock() }
        return createdInstances
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if self.texture.pixelBuffer == nil {
            return nil
        }
        return Unmanaged.passRetained(self.texture.pixelBuffer!)
    }

    public func onTextureUnregistered(_ texture: FlutterTexture) {
        // Hook for the future #178 bug-2 safe surface release: this fires on
        // the raster thread once Flutter is done with the texture, which is the
        // ordering the Dart side needs before releasing the wrapper.
        print("Texture unregistered")
    }
}

/// Test-only process diagnostic used by darwin_texture_leak_test.dart.
@_cdecl("thermion_flutter_live_metal_texture_adapter_count")
public func thermionFlutterLiveMetalTextureAdapterCount() -> Int64 {
    return FlutterMetalTextureWrapper.liveInstanceCount()
}

/// Test-only process diagnostic used by darwin_texture_leak_test.dart.
@_cdecl("thermion_flutter_created_metal_texture_adapter_count")
public func thermionFlutterCreatedMetalTextureAdapterCount() -> Int64 {
    return FlutterMetalTextureWrapper.createdInstanceCount()
}
