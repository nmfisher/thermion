import Flutter
import UIKit

public class SwiftPolyvoxFilamentPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.polyvox.filament", binaryMessenger: registrar.messenger())
    let instance = SwiftPolyvoxFilamentPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }
}
