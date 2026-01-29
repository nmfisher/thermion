
import Foundation

@objc public class SwiftThermionFlutterPluginObjCAPI : NSObject {

    @objc public static func registerTexture(texture: MetalTextureWrapper) -> Int64 {
        if texture.metalTextureAddress == -1 {
            return -1
        }
        let flutterTextureId = SwiftThermionFlutterPlugin.instance!.registerTexture(texture:texture);
        return flutterTextureId
    }

    @objc public static func unregisterFlutterTexture(flutterTextureId: Int64) {
        SwiftThermionFlutterPlugin.instance!.unregisterTexture(flutterTextureId:flutterTextureId);

    }

    @objc public static func markTextureFrameAvailable(flutterTextureId: Int64) {
        SwiftThermionFlutterPlugin.instance!.markTextureFrameAvailable(flutterTextureId:flutterTextureId);
    }

    // MARK: - Frame Scheduler (Direct Callback Mode - Release)

    @objc public static func startFrameScheduler(callbackAddress: Int64, targetFps: Int) {
        ThermionFrameScheduler.start(callbackAddress: callbackAddress, targetFps: targetFps)
    }

    @objc public static func stopFrameScheduler() {
        ThermionFrameScheduler.stop()
    }

    // MARK: - Frame Scheduler (Port Mode - Debug/Hot Restart Safe)

    @objc public static func initializeDartApi(_ dataAddress: Int64) {
        ThermionFrameScheduler.initializeDartApi(dataAddress)
    }

    @objc public static func startFrameSchedulerWithPort(_ port: Int64, targetFps: Int) {
        ThermionFrameScheduler.startWithPort(port, targetFps: targetFps)
    }
}

