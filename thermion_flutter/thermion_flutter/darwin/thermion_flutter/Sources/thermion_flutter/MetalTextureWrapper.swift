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

  // One long-lived CVMetalTextureCache per process, keyed off the system default
  // device. CVMetalTextureCache is designed to be a long-lived, per-device
  // object; creating one per MetalTextureWrapper (and dropping it on destroy)
  // leaks ~one IOSurface per CVMetalTextureCacheCreateTextureFromImage, because
  // releasing the cache object does not synchronously free the IOSurfaces it has
  // cached. Reusing a single cache and flushing it on teardown (with
  // MaximumTextureAge: 0) returns those surfaces. Verified in the standalone
  // reproducer; see docs/DARWIN_IOSURFACE_LEAK_ROOT_CAUSE.md.
  //
  // Thread safety: the lock below only guards the static `sharedCache` pointer
  // swap (create-once + flush). CVMetalTextureCacheCreateTextureFromImage is
  // NOT documented as safe for concurrent use on a single cache, so all
  // MetalTextureWrapper allocation and flushCache() calls must be serialized on
  // one thread. Thermion already satisfies this: textures are allocated and
  // torn down on the serialized texture-mutation path. If that ever changes,
  // serialize access to this cache externally.
  private static let sharedCacheLock = NSLock()
  private static var sharedCache: CVMetalTextureCache?
  private static var sharedCacheDevice: MTLDevice?

  private static func sharedMetalCache(for device: MTLDevice) -> CVMetalTextureCache? {
    sharedCacheLock.lock(); defer { sharedCacheLock.unlock() }
    if let existing = sharedCache, sharedCacheDevice === device {
      return existing
    }
    var c: CVMetalTextureCache?
    let attrs: [CFString: Any] = [
      kCVMetalTextureCacheMaximumTextureAgeKey: 0 as NSNumber
    ]
    let r = CVMetalTextureCacheCreate(
      kCFAllocatorDefault, attrs as CFDictionary, device, nil, &c)
    if r == kCVReturnSuccess {
      sharedCache = c
      sharedCacheDevice = device
    }
    return c
  }

  /// Flushes the shared cache so aged buffer->texture mappings (and their
  /// IOSurfaces) are evicted. Safe to call while other live wrappers exist:
  /// the flush only reaps the cache's internal bookkeeping, not the
  /// CVMetalTexture objects those wrappers still hold.
  private static func flushSharedMetalCache() {
    sharedCacheLock.lock(); defer { sharedCacheLock.unlock() }
    if let c = sharedCache { CVMetalTextureCacheFlush(c, 0) }
  }

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

    // Use the process-wide shared cache instead of creating (and leaking) one
    // per wrapper. See the sharedMetalCache doc comment above.
    guard let cvMetalTextureCache = MetalTextureWrapper.sharedMetalCache(for: metalDevice) else {
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
      cvMetalTextureCache,
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
    // passRetained (+1): this +1 is the ownership stake Filament takes on
    // the imported texture address. Filament's MetalRenderTarget balances
    // it with an objc_release in its destructor. passUnretained would leave
    // only the wrapper's ARC ref keeping the texture alive, so once the
    // wrapper is deallocated (after the descriptor is released) Filament's
    // dtor releases a freed texture → EXC_BAD_ACCESS (the UAF this fixes).
    // The matching release on the RT-swap path below balances THIS retain.
    let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
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
            // The address published above is about to be overwritten.
            // Balance the passRetained(+1) taken on the ORIGINAL
            // CV-cache texture, or it leaks unreleasably — nothing
            // else holds that opaque pointer once it's replaced.
            if metalTextureAddress != -1,
              let orphaned = UnsafeRawPointer(bitPattern: metalTextureAddress)
            {
              Unmanaged<AnyObject>.fromOpaque(orphaned).release()
            }
            // Replace the original texture with the render target version
            metalTexture = rtTexture
            let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
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

  @objc public func flushCache() {
    // Flush the process-wide shared cache so aged buffer->texture mappings
    // (and their IOSurfaces) are reaped.
    MetalTextureWrapper.flushSharedMetalCache()
  }

}
