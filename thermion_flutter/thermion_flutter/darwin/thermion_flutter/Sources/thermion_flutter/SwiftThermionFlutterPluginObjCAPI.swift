
import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

@objc public class SwiftThermionFlutterPluginObjCAPI : NSObject {

    // Vends the FlutterTextureRegistry captured in SwiftThermionFlutterPlugin.register(with:).
    // The Dart side holds this reference and calls registerTexture:/
    // textureFrameAvailable:/unregisterTexture: on it directly, owning the full
    // texture lifecycle.
    private static var _textureRegistry: ThermionTextureRegistry?

    @objc public static func textureRegistry() -> ThermionTextureRegistry {
        if let existing = _textureRegistry { return existing }
        let wrapper = ThermionTextureRegistry(
            registry: SwiftThermionFlutterPlugin.instance!.registry)
        _textureRegistry = wrapper
        return wrapper
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
