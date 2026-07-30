import Foundation
import GLKit

// Stub for ObjC header generation only.
// The real implementation is in SwiftThermionFlutterPluginObjCAPI.swift
// which gets compiled by Xcode with Flutter/Dart dependencies.
//
// This file is used by `make swift-bindings` to generate the ObjC header
// without needing to link against Flutter or Dart frameworks.

@objc public class MetalTextureWrapper: NSObject {
    @objc public var pixelBuffer: CVPixelBuffer? { return nil }
    @objc public var cvMetalTextureCache: CVMetalTextureCache? { return nil }
    @objc public var metalDevice: MTLDevice? { return nil }
    @objc public var cvMetalTexture: CVMetalTexture? { return nil }
    @objc public var metalTexture: MTLTexture? { return nil }
    @objc public var metalTextureAddress: Int { return -1 }
    @objc public var width: Int64 { return 0 }
    @objc public var height: Int64 { return 0 }

    @objc public static func allocate(width: Int64, height: Int64, isDepth: Bool, isStencil: Bool) -> MetalTextureWrapper {
        return MetalTextureWrapper()
    }

    @objc public func supportsRenderTarget() -> Bool { return false }
    @objc public func retainMetalTextureForImport() -> Int { return -1 }
    @objc public func releaseMetalTextureAfterFailedImport(_ address: Int) {}
    @objc public func flushCache() {}
}

@objc public class FlutterMetalTextureWrapper: NSObject {
    @objc public init(texture: MetalTextureWrapper) {}
}

// Typed Dart-facing view of Flutter's FlutterTextureRegistry. Declared here as
// an @objc interface (not a protocol) because ffigen's protocol bindings are
// implement-only and can't be invoked; an interface gives msgSend-based,
// callable bindings. Dart obtains the real registry from
// SwiftThermionFlutterPluginObjCAPI.textureRegistry() (returned as NSObject)
// and casts it to ThermionTextureRegistry, then invokes the selectors below.
// objc dispatch is by selector, so this works against the real
// FlutterTextureRegistry-conforming object. Selectors MUST match Flutter's
// FlutterTextureRegistry exactly.
@objc public class ThermionTextureRegistry: NSObject {
    @objc public func registerTexture(_ texture: NSObject) -> Int64 { return 0 }
    @objc public func textureFrameAvailable(_ textureId: Int64) {}
    @objc public func unregisterTexture(_ textureId: Int64) {}
}

@objc public class SwiftThermionFlutterPluginObjCAPI: NSObject {
    // Returns the registry as a generic NSObject so this Flutter-free stub does
    // not reference the FlutterTextureRegistry protocol. The real implementation
    // returns a typed FlutterTextureRegistry; the Dart side casts it to
    // ThermionTextureRegistry (declared above) to invoke its methods.
    @objc public static func textureRegistry() -> NSObject { fatalError("stub") }
    @objc public static func startFrameScheduler(callbackAddress: Int64, targetFps: Int) {}
    @objc public static func stopFrameScheduler() {}
    @objc public static func initializeDartApi(_ dataAddress: Int64) {}
    @objc public static func startFrameSchedulerWithPort(_ port: Int64, targetFps: Int) {}
}
