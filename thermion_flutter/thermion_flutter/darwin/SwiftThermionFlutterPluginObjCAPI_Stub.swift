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
    @objc public func destroyTexture() {}
}

@objc public class SwiftThermionFlutterPluginObjCAPI: NSObject {
    @objc public static func registerTexture(texture: MetalTextureWrapper) -> Int64 { return -1 }
    @objc public static func unregisterFlutterTexture(flutterTextureId: Int64) {}
    @objc public static func markTextureFrameAvailable(flutterTextureId: Int64) {}
    @objc public static func startFrameScheduler(callbackAddress: Int64, targetFps: Int) {}
    @objc public static func stopFrameScheduler() {}
    @objc public static func initializeDartApi(_ dataAddress: Int64) {}
    @objc public static func startFrameSchedulerWithPort(_ port: Int64, targetFps: Int) {}
}
