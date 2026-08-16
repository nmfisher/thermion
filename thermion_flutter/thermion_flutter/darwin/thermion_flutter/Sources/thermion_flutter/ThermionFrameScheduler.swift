#if os(iOS)
import QuartzCore
#elseif os(macOS)
import CoreVideo
#endif
import Foundation
// Under Swift Package Manager the Dart Native API C symbols live in their own
// module (SPM can't mix C and Swift in one target). Under CocoaPods everything
// is one module and the symbols come from the umbrella header, so this import
// does not exist and is skipped.
#if canImport(thermion_flutter_dart_api)
import thermion_flutter_dart_api
#endif

@objc public class ThermionFrameScheduler: NSObject {
    private typealias FrameCallback = @convention(c) (UInt64) -> Void

    private var callback: FrameCallback?

    // Port-based mode (debug/hot restart safe)
    private var dartPort: Int64 = 0
    private var usePortMode: Bool = false

    #if os(iOS)
    private var displayLink: CADisplayLink?
    #elseif os(macOS)
    private var displayLink: CVDisplayLink?
    #endif

    private static var instance: ThermionFrameScheduler?
    private static var dartApiInitialized: Bool = false

    // MARK: - Direct Callback Mode (Release)

    @objc public static func start(callbackAddress: Int64, targetFps: Int) {
        stop()
        let scheduler = ThermionFrameScheduler()
        scheduler.callback = unsafeBitCast(callbackAddress, to: FrameCallback.self)
        scheduler.usePortMode = false
        instance = scheduler
        scheduler.startDisplayLink()
    }

    // MARK: - Port Mode (Debug/Hot Restart Safe)

    @objc public static func initializeDartApi(_ dataAddress: Int64) {
        if !dartApiInitialized {
            let data = UnsafeMutableRawPointer(bitPattern: Int(dataAddress))
            if let data = data {
                // Call Dart_InitializeApiDL - returns 0 on success
                dartApiInitialized = (Dart_InitializeApiDL(data) == 0)
            }
        }
    }

    @objc public static func startWithPort(_ port: Int64, targetFps: Int) {
        stop()
        let scheduler = ThermionFrameScheduler()
        scheduler.dartPort = port
        scheduler.usePortMode = true
        scheduler.callback = nil
        instance = scheduler
        scheduler.startDisplayLink()
    }

    // MARK: - Stop

    @objc public static func stop() {
        // Null callback pointer FIRST to prevent race conditions
        instance?.callback = nil
        instance?.dartPort = 0
        instance?.stopDisplayLink()
        instance = nil
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        #if os(iOS)
        let link = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #elseif os(macOS)
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, inOutputTime, _, _, context) -> CVReturn in
            guard let context = context else { return kCVReturnError }
            let scheduler = Unmanaged<ThermionFrameScheduler>.fromOpaque(context).takeUnretainedValue()
            scheduler.invokeFrame(nanos: inOutputTime.pointee.hostTime)
            return kCVReturnSuccess
        }, selfPtr)
        CVDisplayLinkStart(link)
        displayLink = link
        #endif
    }

    private func stopDisplayLink() {
        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #elseif os(macOS)
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
        #endif
        callback = nil
        dartPort = 0
    }

    // MARK: - Frame Invocation

    private func invokeFrame(nanos: UInt64) {
        if usePortMode {
            // Port mode: safe for hot restart - silently drops if isolate is dead
            if dartPort != 0 {
                // Create Dart_CObject with Int64 value
                var msg = Dart_CObject()
                msg.type = Dart_CObject_kInt64
                msg.value.as_int64 = Int64(nanos)

                // Post to Dart port - returns false if port is invalid, doesn't crash
                _ = Dart_PostCObject_DL(dartPort, &msg)
            }
        } else {
            // Direct callback mode: maximum performance
            callback?(nanos)
        }
    }

    #if os(iOS)
    @objc private func onDisplayLink(_ link: CADisplayLink) {
        let nanos = UInt64(link.timestamp * 1e9)
        invokeFrame(nanos: nanos)
    }
    #endif
}
