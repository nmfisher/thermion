package app.polyvox.filament

import androidx.annotation.NonNull

import androidx.lifecycle.Lifecycle

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference


/** PolyvoxFilamentPlugin */
class PolyvoxFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  companion object {
      const val VIEW_TYPE = "app.polyvox.filament/filament_view"
  }

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  /// Keep a referene to the plugin binding so we can defer construction of a FilamentViewFactory
  /// until Activity is attached.
  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app.polyvox.filament")
    channel.setMethodCallHandler(this)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    flutterPluginBinding
                .platformViewRegistry
                .registerViewFactory(VIEW_TYPE, FilamentViewFactory(binding.activity, flutterPluginBinding.binaryMessenger))
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {

    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromActivity() {
  lifecycle = null
  }
}
