import Foundation
import GLKit

@objc public class MetalTextureWrapper : NSObject {

    @objc public let pixelBuffer: CVPixelBuffer?
    @objc public let cvMetalTextureCache:CVMetalTextureCache?
    @objc public let metalDevice:MTLDevice?
    @objc public let cvMetalTexture:CVMetalTexture?
    @objc public let metalTexture:MTLTexture?
    @objc public let metalTextureAddress:Int
    @objc public let width:Int64
    @objc public let height:Int64

    init(pixelBuffer: CVPixelBuffer?, cvMetalTextureCache: CVMetalTextureCache?, metalDevice: MTLDevice?, cvMetalTexture: CVMetalTexture?, metalTexture: MTLTexture?, metalTextureAddress: Int, width: Int64, height: Int64) {
        self.pixelBuffer = pixelBuffer
        self.cvMetalTextureCache = cvMetalTextureCache
        self.metalDevice = metalDevice
        self.cvMetalTexture = cvMetalTexture
        self.metalTexture = metalTexture
        self.metalTextureAddress = metalTextureAddress
        self.width = width
        self.height = height
    }

    @objc public static func allocate(width:Int64, height:Int64, isDepth:Bool, isStencil:Bool) -> MetalTextureWrapper {
        let metalDevice = MTLCreateSystemDefaultDevice()!

        if isDepth {
            print("Creating depth texture")
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
            let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
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

        print("Creating color texture")

        let pixelBufferAttrs = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ABGR ),
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue!
        ] as [CFString : Any] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                           kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess) {
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
            kCVMetalTextureCacheMaximumTextureAgeKey: 0 as NSNumber,  // Keep textures as long as possible
        ]

        let cacheCreationResult = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            cacheAttrs as CFDictionary,
            metalDevice,
            nil,
            &cvMetalTextureCache)
        if(cacheCreationResult != kCVReturnSuccess) {
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
        if(cvret != kCVReturnSuccess) {
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
        let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
        var metalTextureAddress = Int(bitPattern:metalTexturePtr)

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

                    if let rtTexture = metalDevice.makeTexture(descriptor: rtDescriptor, iosurface: iosurfaceRef, plane: 0) {
                        print("Successfully created render target texture from IOSurface")
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

    @objc public func destroyTexture()  {
       if let cache = self.cvMetalTextureCache {
           CVMetalTextureCacheFlush(cache, 0)
       }
    }

}
