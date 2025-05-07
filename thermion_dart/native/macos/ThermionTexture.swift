import Foundation
import GLKit

@objc public class ThermionTextureSwift : NSObject {

    public var pixelBuffer: CVPixelBuffer?
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ABGR ),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ] as [CFString : Any] as CFDictionary

    @objc public var cvMetalTextureCache:CVMetalTextureCache?
    @objc public var metalDevice:MTLDevice?

    @objc public var cvMetalTexture:CVMetalTexture?
    @objc public var metalTexture:MTLTexture?
    @objc public var metalTextureAddress:Int = -1

    @objc override public init() {
        
    }

    @objc public init(width:Int64, height:Int64, isDepth:Bool) {
        if(self.metalDevice == nil) {
            self.metalDevice = MTLCreateSystemDefaultDevice()!
        }

        if isDepth {
            print("Creating depth texture")
            // Create a proper depth texture without IOSurface backing
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float,
                width: Int(width),
                height: Int(height),
                mipmapped: false)
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            textureDescriptor.storageMode = .private  // Best performance for GPU-only access
            
            metalTexture = metalDevice?.makeTexture(descriptor: textureDescriptor)
            let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
            metalTextureAddress = Int(bitPattern: metalTexturePtr)
            return
        }

        print("Creating color texture")


        // let pixelFormat: MTLPixelFormat = isDepth ? .depth32Float : .bgra8Unorm
        // let cvPixelFormat = isDepth ? kCVPixelFormatType_DepthFloat32 : kCVPixelFormatType_32BGRA
    
        if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                           kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess) {
            print("Error allocating pixel buffer")
            metalTextureAddress = -1;
            return
        }
    
        if self.cvMetalTextureCache == nil {
            let cacheCreationResult = CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                self.metalDevice!,
                nil,
                &self.cvMetalTextureCache)
            if(cacheCreationResult != kCVReturnSuccess) {
                print("Error creating Metal texture cache")
                metalTextureAddress = -1
                return
            }
        }
        let cvret = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    self.cvMetalTextureCache!,
                    pixelBuffer!, nil,
                    MTLPixelFormat.bgra8Unorm,
                    Int(width), Int(height),
                    0,
                    &cvMetalTexture)
        if(cvret != kCVReturnSuccess) { 
            print("Error creating texture from image")
            metalTextureAddress = -1
            return
        }
        metalTexture = CVMetalTextureGetTexture(cvMetalTexture!)
        let metalTexturePtr = Unmanaged.passRetained(metalTexture!).toOpaque()
        metalTextureAddress = Int(bitPattern:metalTexturePtr)
    }

    @objc public func destroyTexture()  {
       CVMetalTextureCacheFlush(self.cvMetalTextureCache!, 0)
       self.metalTexture = nil
       self.cvMetalTexture = nil
       self.pixelBuffer = nil
       self.metalDevice = nil
       self.cvMetalTextureCache = nil
    }
    @objc public func fillWithPNGImage(imageURL: URL) -> Bool {
    // Make sure we have a pixel buffer to work with
    guard let pixelBuffer = self.pixelBuffer else {
        print("Error: No pixel buffer available")
        return false
    }
    
    // Try to load the image from the provided URL
    guard let nsImage = NSImage(contentsOf: imageURL) else {
        print("Error: Could not load image from \(imageURL.path)")
        return false
    }
    
    // Make sure we have a CGImage to work with
    guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Error: Could not get CGImage from NSImage")
        return false
    }
    
    // Get pixel buffer dimensions
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    // Lock the pixel buffer for writing
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    // Get the base address of the pixel buffer
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        print("Error: Could not get base address of pixel buffer")
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return false
    }
    
    // Create a graphics context in the pixel buffer
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let context = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    )
    
    // Draw the image into the context (which is backed by our pixel buffer)
    if let context = context {
        // Flip the coordinate system to match Metal's coordinate system
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        // Draw the image to fill the entire texture
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.draw(cgImage, in: rect)
    } else {
        print("Error: Could not create CGContext from pixel buffer")
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return false
    }
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return true
}

    @objc public func fillColor() { 
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
               let bufferWidth = Int(CVPixelBufferGetWidth(pixelBuffer!))
               let bufferHeight = Int(CVPixelBufferGetHeight(pixelBuffer!))
               let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)

               guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!) else {
                       return
               }

               for row in 0..<bufferHeight {
                   var pixel = baseAddress + row * bytesPerRow
                   for _ in 0..<bufferWidth {
                       let blue = pixel
                       blue.storeBytes(of: 255, as: UInt8.self)

                       let red = pixel + 1
                       red.storeBytes(of: 0, as: UInt8.self)

                       let green = pixel + 2
                       green.storeBytes(of: 0, as: UInt8.self)
                    
                       let alpha = pixel + 3
                       alpha.storeBytes(of: 255, as: UInt8.self)
                       
                       pixel += 4;
                   }
               }

               CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    }
    
@objc public func getTextureBytes() -> NSData? {
    guard let texture = self.metalTexture else {
        print("Metal texture is not available")
        return nil
    }

    let width = texture.width
    let height = texture.height
    
    // Check what type of texture we're dealing with
    let isDepthTexture = texture.pixelFormat == .depth32Float || 
                         texture.pixelFormat == .depth16Unorm
    print("Using texture pixel format : \(texture.pixelFormat) isDepthTexture \(isDepthTexture) (depth32Float \(MTLPixelFormat.depth32Float))  (depth16Unorm \(MTLPixelFormat.depth16Unorm))")    
    // Determine bytes per pixel based on format
    let bytesPerPixel = isDepthTexture ? 
        (texture.pixelFormat == .depth32Float ? 4 : 2) : 4
    let bytesPerRow = width * bytesPerPixel
    let byteCount = bytesPerRow * height
    
    // Create a staging buffer that is CPU-accessible
    guard let stagingBuffer = self.metalDevice?.makeBuffer(
        length: byteCount, 
        options: .storageModeShared) else {
        print("Failed to create staging buffer")
        return nil
    }
    
    // Create command buffer and encoder for copying
    guard let cmdQueue = self.metalDevice?.makeCommandQueue(),
          let cmdBuffer = cmdQueue.makeCommandBuffer(),
          let blitEncoder = cmdBuffer.makeBlitCommandEncoder() else {
        print("Failed to create command objects")
        return nil
    }
    
    // Copy from texture to buffer
    blitEncoder.copy(
        from: texture,
        sourceSlice: 0,
        sourceLevel: 0,
        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
        sourceSize: MTLSize(width: width, height: height, depth: 1),
        to: stagingBuffer,
        destinationOffset: 0,
        destinationBytesPerRow: bytesPerRow,
        destinationBytesPerImage: byteCount
    )
    
    blitEncoder.endEncoding()
    cmdBuffer.commit()
    cmdBuffer.waitUntilCompleted()
    
    // Now the data is in the staging buffer, accessible to CPU
    if isDepthTexture {
        // For depth textures, just return the raw data
        return NSData(bytes: stagingBuffer.contents(), length: byteCount)
    } else {
        // For color textures, do the BGRA to RGBA swizzling
        let bytes = stagingBuffer.contents().bindMemory(to: UInt8.self, capacity: byteCount)
        let data = NSMutableData(bytes: bytes, length: byteCount)
        
        let mutableBytes = data.mutableBytes.bindMemory(to: UInt8.self, capacity: byteCount)
        for i in stride(from: 0, to: byteCount, by: 4) {
            let blue = mutableBytes[i]
            let red = mutableBytes[i+2]
            mutableBytes[i] = red
            mutableBytes[i+2] = blue
        }
        
        return data
    }
}

}
