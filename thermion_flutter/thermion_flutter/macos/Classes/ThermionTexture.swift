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

    @objc public init(width:Int64, height:Int64) {
        if(self.metalDevice == nil) {
            self.metalDevice = MTLCreateSystemDefaultDevice()!
        }

        // create pixel buffer
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
                   for col in 0..<bufferWidth {
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
    let bytesPerPixel = 4 // RGBA
    let bytesPerRow = width * bytesPerPixel
    let byteCount = bytesPerRow * height

    var bytes = [UInt8](repeating: 0, count: byteCount)
    let region = MTLRegionMake2D(0, 0, width, height)
    texture.getBytes(&bytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

    // Swizzle bytes from BGRA to RGBA
    for i in stride(from: 0, to: byteCount, by: 4) {
        let blue = bytes[i]
        let green = bytes[i + 1]
        let red = bytes[i + 2]
        let alpha = bytes[i + 3]

        bytes[i] = red
        bytes[i + 1] = green
        bytes[i + 2] = blue
        bytes[i + 3] = alpha
    }

    // Convert Swift Data to Objective-C NSData 
    let nsData = Data(bytes: &bytes, count: byteCount) as NSData 
    return nsData
}


}
