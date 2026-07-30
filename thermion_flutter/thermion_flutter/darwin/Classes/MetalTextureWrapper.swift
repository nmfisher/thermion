import Foundation
import GLKit

// On Darwin platforms, allocating a single Texture compatible with both
// Flutter and Filament (including a texture used as a render target attachment)
// requires all of the following:
// - MTLTexture
// - CVMetalTexture
// - CVPixelBuffer
// - CVMetalTextureCache
//
// These four classes are related as follows:
//    IOSurface   ← the actual GPU memory
//       ▲
//       │  backed by
//       │
//   CVPixelBuffer        (CoreVideo buffer owning the IOSurface)
//       │
//       │  CVMetalTextureCacheCreateTextureFromImage(cache, pixelBuffer)
//       ▼
//   CVMetalTexture       (CV handle: "this buffer is Metal texture X"; retains the CVPixelBuffer)
//       │
//       │  CVMetalTextureGetTexture(cvMetalTexture)
//       ▼
//   MTLTexture           (Metal GPU texture; shares the IOSurface, no copy)
//   CVMetalTextureCache  ← sits beside this, per-device, producing CVMetalTextures
//
// CVPixelBuffer is a CoreVideo image buffer holding the pixel data (here BGRA‑32).
// When created with kCVPixelBufferIOSurfacePropertiesKey + kCVPixelBufferMetalCompatibilityKey,
// its backing store is an IOSurface — a kernel-shared, GPU-compatible allocation.
//
// CVMetalTextureCache is a bridge/factory object that knows how to map a CVPixelBuffer onto a Metal texture
// for a given device. Caches buffer→texture mappings internally so re-wrapping the same buffer is cheap.
//
// CVMetalTexture — the binding handle.
// A lightweight CoreVideo handle that represents the relationship "this CVPixelBuffer is exposed as a Metal texture of format X."
// Links the MTLTexture to CoreVideo. Critically, it retains the source CVPixelBuffer,
// so the buffer (and its IOSurface) stays alive for the lifetime of the CVMetalTexture.

// MTLTexture is the actual Metal-facing GPU texture. This can be passed to Filament for use as a render target/depth attachment/etc.
// Not created directly here — you get it out of the CVMetalTexture via CVMetalTextureGetTexture(cvMetalTexture)
// (Get rule → borrowed, +0). Shares the IOSurface backing with the CVPixelBuffer; no copy. ARC (NSObject) refcounting.
//
// [MetalTextureWrapper] is simply a convenience wrapper for allocating these four handles, and grouping into
// a single instance of an object that can be passed back/forth across the Dart boundary.
//
// IMPORTANT: although [MetalTextureWrapper] is packaged with thermion_flutter, it is actually Flutter-agnostic and can be
// consumed in the Dart-only package. We sometimes use this class running tests in [thermion_dart].

@objc public class MetalTextureWrapper: NSObject {
  private static let lifetimeLock = NSLock()
  private static var liveInstances: Int64 = 0
  private static var createdInstances: Int64 = 0

  @objc public let pixelBuffer: CVPixelBuffer?
  @objc public let cvMetalTextureCache: CVMetalTextureCache?
  @objc public let metalDevice: MTLDevice?
  @objc public let cvMetalTexture: CVMetalTexture?
  @objc public let metalTexture: MTLTexture?
  @objc public let metalTextureAddress: Int
  @objc public let width: Int64
  @objc public let height: Int64

  init(
    pixelBuffer: CVPixelBuffer?, cvMetalTextureCache: CVMetalTextureCache?,
    metalDevice: MTLDevice?,
    cvMetalTexture: CVMetalTexture?, metalTexture: MTLTexture?, metalTextureAddress: Int,
    width: Int64, height: Int64
  ) {
    self.pixelBuffer = pixelBuffer
    self.cvMetalTextureCache = cvMetalTextureCache
    self.metalDevice = metalDevice
    self.cvMetalTexture = cvMetalTexture
    self.metalTexture = metalTexture
    self.metalTextureAddress = metalTextureAddress
    self.width = width
    self.height = height
    MetalTextureWrapper.lifetimeLock.lock()
    MetalTextureWrapper.liveInstances += 1
    MetalTextureWrapper.createdInstances += 1
    MetalTextureWrapper.lifetimeLock.unlock()
  }

  deinit {
    MetalTextureWrapper.lifetimeLock.lock()
    MetalTextureWrapper.liveInstances -= 1
    MetalTextureWrapper.lifetimeLock.unlock()
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

  @objc public static func allocate(width: Int64, height: Int64, isDepth: Bool, isStencil: Bool)
    -> MetalTextureWrapper
  {
    let metalDevice = MTLCreateSystemDefaultDevice()!

    if isDepth {
      // Create a proper depth texture without IOSurface backing
      #if os(iOS)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
          pixelFormat: isStencil ? .depth32Float_stencil8 : .depth32Float_stencil8,
          width: Int(width),
          height: Int(height),
          mipmapped: false)
      #else
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
          pixelFormat: isStencil ? .depth24Unorm_stencil8 : .depth32Float_stencil8,
          width: Int(width),
          height: Int(height),
          mipmapped: false)
      #endif

      textureDescriptor.usage = [.renderTarget, .shaderRead]
      textureDescriptor.storageMode = .private  // Best performance for GPU-only access

      let metalTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
      let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
      let metalTextureAddress = Int(bitPattern: metalTexturePtr)

      return MetalTextureWrapper(
        pixelBuffer: nil,
        cvMetalTextureCache: nil,
        metalDevice: metalDevice,
        cvMetalTexture: nil,
        metalTexture: metalTexture,
        metalTextureAddress: metalTextureAddress,
        width: width,
        height: height
      )
    }

    let pixelBufferAttrs =
      [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue!,
      ] as [CFString: Any] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    if CVPixelBufferCreate(
      kCFAllocatorDefault, Int(width), Int(height),
      kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess
    {
      print("Error allocating pixel buffer")
      return MetalTextureWrapper(
        pixelBuffer: nil,
        cvMetalTextureCache: nil,
        metalDevice: metalDevice,
        cvMetalTexture: nil,
        metalTexture: nil,
        metalTextureAddress: -1,
        width: width,
        height: height
      )
    }

    var cvMetalTextureCache: CVMetalTextureCache?
    // Create texture cache attributes to enable render target usage
    let cacheAttrs: [CFString: Any] = [
      kCVMetalTextureCacheMaximumTextureAgeKey: 0 as NSNumber  // Keep textures as long as possible
    ]

    let cacheCreationResult = CVMetalTextureCacheCreate(
      kCFAllocatorDefault,
      cacheAttrs as CFDictionary,
      metalDevice,
      nil,
      &cvMetalTextureCache)
    if cacheCreationResult != kCVReturnSuccess {
      print("Error creating Metal texture cache")
      return MetalTextureWrapper(
        pixelBuffer: pixelBuffer,
        cvMetalTextureCache: nil,
        metalDevice: metalDevice,
        cvMetalTexture: nil,
        metalTexture: nil,
        metalTextureAddress: -1,
        width: width,
        height: height
      )
    }

    // Try to create texture with usage attributes
    let textureAttrs: [CFString: Any] = [:]
    var cvMetalTexture: CVMetalTexture?

    let cvret = CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      cvMetalTextureCache!,
      pixelBuffer!,
      textureAttrs as CFDictionary,
      MTLPixelFormat.bgra8Unorm,
      Int(width), Int(height),
      0,
      &cvMetalTexture)
    if cvret != kCVReturnSuccess {
      print("Error creating texture from image")
      return MetalTextureWrapper(
        pixelBuffer: pixelBuffer,
        cvMetalTextureCache: cvMetalTextureCache,
        metalDevice: metalDevice,
        cvMetalTexture: nil,
        metalTexture: nil,
        metalTextureAddress: -1,
        width: width,
        height: height
      )
    }
    var metalTexture = CVMetalTextureGetTexture(cvMetalTexture!)
    // Publish a borrowed address for identity and Flutter interop. Call
    // retainMetalTextureForImport() for every Filament import; Filament takes
    // ownership of that +1 and releases it when its Texture is destroyed.
    let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
    var metalTextureAddress = Int(bitPattern: metalTexturePtr)

    // Debug: Log texture usage capabilities
    if let texture = metalTexture {
      print("Color texture created with usage: \(texture.usage)")
      print("Is render target supported: \(texture.usage.contains(.renderTarget))")
      print("Is shader read supported: \(texture.usage.contains(.shaderRead))")
      print("Is shader write supported: \(texture.usage.contains(.shaderWrite))")
      print("Texture pixel format: \(texture.pixelFormat)")
      print("Texture storage mode: \(texture.storageMode)")

      // If render target is not supported, try to create a render target texture from IOSurface
      if !texture.usage.contains(.renderTarget) {
        print("Render target not supported, attempting IOSurface-based approach...")
        if let iosurface = CVPixelBufferGetIOSurface(pixelBuffer!) {
          print("Got IOSurface, creating render target texture from it...")
          let iosurfaceRef = iosurface.takeUnretainedValue()

          let rtDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(width),
            height: Int(height),
            mipmapped: false)
          rtDescriptor.usage = [.renderTarget, .shaderRead]
          rtDescriptor.storageMode = .private

          if let rtTexture = metalDevice.makeTexture(
            descriptor: rtDescriptor, iosurface: iosurfaceRef, plane: 0)
          {
            print("Successfully created render target texture from IOSurface")
            // Replace the original texture with the render target version
            metalTexture = rtTexture
            let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
            metalTextureAddress = Int(bitPattern: metalTexturePtr)

            print("Render target texture usage: \(metalTexture!.usage)")
            print("Is render target now supported: \(metalTexture!.usage.contains(.renderTarget))")
          } else {
            print("Failed to create render target texture from IOSurface")
          }
        } else {
          print("Failed to get IOSurface from pixel buffer")
        }
      }
    }

    return MetalTextureWrapper(
      pixelBuffer: pixelBuffer,
      cvMetalTextureCache: cvMetalTextureCache,
      metalDevice: metalDevice,
      cvMetalTexture: cvMetalTexture,
      metalTexture: metalTexture,
      metalTextureAddress: metalTextureAddress,
      width: width,
      height: height
    )
  }

  @objc public func supportsRenderTarget() -> Bool {
    guard let texture = metalTexture else { return false }
    return texture.usage.contains(.renderTarget)
  }

  /// Creates the +1 ownership transfer required by
  /// `filament::Texture::Builder.import`.
  @objc public func retainMetalTextureForImport() -> Int {
    guard let texture = metalTexture else { return -1 }
    return Int(
      bitPattern: Unmanaged.passRetained(texture).toOpaque()
    )
  }

  /// Returns an import retain when Filament failed before accepting ownership.
  @objc public func releaseMetalTextureAfterFailedImport(_ address: Int) {
    guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
    Unmanaged<AnyObject>.fromOpaque(pointer).release()
  }

  @objc public func flushCache() {
    if let cache = self.cvMetalTextureCache {
      CVMetalTextureCacheFlush(cache, 0)
    }
  }

}

/// Test-only process diagnostic used by darwin_texture_leak_test.dart.
@_cdecl("thermion_flutter_live_metal_texture_wrapper_count")
public func thermionFlutterLiveMetalTextureWrapperCount() -> Int64 {
  return MetalTextureWrapper.liveInstanceCount()
}

/// Test-only process diagnostic used by darwin_texture_leak_test.dart.
@_cdecl("thermion_flutter_created_metal_texture_wrapper_count")
public func thermionFlutterCreatedMetalTextureWrapperCount() -> Int64 {
  return MetalTextureWrapper.createdInstanceCount()
}

/// Writes an opaque grayscale frame into a wrapper's CVPixelBuffer so the
/// Flutter-only integration probe can visibly verify that the compositor is
/// sampling each frame it marks available.
@_cdecl("thermion_flutter_fill_metal_texture_pixel_buffer")
public func thermionFlutterFillMetalTexturePixelBuffer(
  _ wrapperAddress: Int64,
  _ luminance: UInt8
) -> Bool {
  guard
    let pointer = UnsafeRawPointer(bitPattern: Int(wrapperAddress))
  else {
    return false
  }
  let wrapper = Unmanaged<MetalTextureWrapper>
    .fromOpaque(pointer)
    .takeUnretainedValue()
  guard let pixelBuffer = wrapper.pixelBuffer else {
    return false
  }

  guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
    return false
  }
  defer {
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
  }
  guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
    return false
  }

  let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
  let width = CVPixelBufferGetWidth(pixelBuffer)
  let height = CVPixelBufferGetHeight(pixelBuffer)
  for y in 0..<height {
    let row = baseAddress
      .advanced(by: y * bytesPerRow)
      .assumingMemoryBound(to: UInt8.self)
    for x in 0..<width {
      let offset = x * 4
      row[offset] = luminance
      row[offset + 1] = luminance
      row[offset + 2] = luminance
      row[offset + 3] = 255
    }
  }
  return true
}
