#if os(iOS)
import QuartzCore
#elseif os(macOS)
import CoreVideo
#endif
import Foundation

@objc public class ThermionFrameScheduler: NSObject {
    private typealias FrameCallback = @convention(c) (UInt64) -> Void

    private var callback: FrameCallback?

    #if os(iOS)
    private var displayLink: CADisplayLink?
    #elseif os(macOS)
    private var displayLink: CVDisplayLink?
    #endif

    private static var instance: ThermionFrameScheduler?

    @objc public static func start(callbackAddress: Int64, targetFps: Int) {
        stop()
        let scheduler = ThermionFrameScheduler()
        scheduler.callback = unsafeBitCast(callbackAddress, to: FrameCallback.self)
        instance = scheduler
        scheduler.startDisplayLink()
    }

    @objc public static func stop() {
        instance?.stopDisplayLink()
        instance = nil
    }

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
            scheduler.callback?(inOutputTime.pointee.hostTime)
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
    }

    #if os(iOS)
    @objc private func onDisplayLink(_ link: CADisplayLink) {
        guard let callback = callback else { return }
        let nanos = UInt64(link.timestamp * 1e9)
        callback(nanos)
    }
    #endif
}
