import Foundation
import GLKit

@objc public class DartFilamentTexture : NSObject {

    public var pixelBuffer: CVPixelBuffer?
    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ABGR ),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ] as [CFString : Any] as CFDictionary

    @objc public var cvMetalTextureCache:CVMetalTextureCache?
    @objc public var cvMetalTexture:CVMetalTexture?
    @objc public var metalTexture:MTLTexture?
    @objc public var metalDevice:MTLDevice?
    @objc public var metalTextureAddress:Int = -1

    @objc override public init() {
        
    }

    @objc public init(width:Int64, height:Int64) { 
        
        self.metalDevice = MTLCreateSystemDefaultDevice()!

        // create pixel buffer
        if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                               kCVPixelFormatType_32BGRA, pixelBufferAttrs, &pixelBuffer) != kCVReturnSuccess) {
            print("Error allocating pixel buffer")
            metalTextureAddress = -1;
            return
        }
           
        var cvret = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            metalDevice!,
            nil,
            &cvMetalTextureCache);
        if(cvret != 0) { 
            print("Error creating Metal texture cache")
            metalTextureAddress = -1
            return
        }
        cvret = CVMetalTextureCacheCreateTextureFromImage(
                        kCFAllocatorDefault,
                        cvMetalTextureCache!,
                        pixelBuffer!, nil,
                        MTLPixelFormat.bgra8Unorm,
                        Int(width), Int(height),
                        0,
                        &cvMetalTexture)
        if(cvret != 0) { 
            print("Error creating texture from image")
            metalTextureAddress = -1
            return
        }
        metalTexture = CVMetalTextureGetTexture(cvMetalTexture!)
        let metalTexturePtr = Unmanaged.passUnretained(metalTexture!).toOpaque()
        metalTextureAddress = Int(bitPattern:metalTexturePtr)
        
        print("Created metal texture @ \(metalTextureAddress)")
        
        // CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        //        let bufferWidth = Int(CVPixelBufferGetWidth(pixelBuffer!))
        //        let bufferHeight = Int(CVPixelBufferGetHeight(pixelBuffer!))
        //        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)

        //        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!) else {
        //                return
        //        }

        //        for row in 0..<bufferHeight {
        //            var pixel = baseAddress + row * bytesPerRow
        //            for col in 0..<bufferWidth {
        //                let blue = pixel
        //                blue.storeBytes(of: 255, as: UInt8.self)

        //                let red = pixel + 1
        //                red.storeBytes(of: 0, as: UInt8.self)

        //                let green = pixel + 2
        //                green.storeBytes(of: 0, as: UInt8.self)
                    
        //                let alpha = pixel + 3
        //                alpha.storeBytes(of: 255, as: UInt8.self)
                       
        //                pixel += 4;
        //            }
        //        }

        //        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

    }

    @objc public func destroyTexture()  {
        metalTexture = nil
    }


}
