package app.polyvox.filament


import HotReloadPathHelper
import android.app.Activity
import android.content.res.AssetManager
import android.graphics.*
import android.os.Build
import android.util.Log
import android.view.Choreographer
import android.view.Surface
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.lifecycle.Lifecycle
import com.sun.jna.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.view.TextureRegistry.SurfaceTextureEntry
import java.io.File
import java.util.*
import java.util.concurrent.Executors


typealias EntityId = Int

/** PolyvoxFilamentPlugin */
class PolyvoxFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LoadFilamentResourceFromOwner, FreeFilamentResourceFromOwner, RenderCallback {

  companion object {
      const val CHANNEL_NAME = "app.polyvox.filament/event"
      const val TAG = "FilamentPlugin"
  }

  private lateinit var channel : MethodChannel

  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop
  
  private var _surfaceTexture: SurfaceTexture? = null
  private var _surfaceTextureEntry: SurfaceTextureEntry? = null
  private var _surface: Surface? = null
      
  private lateinit var activity:Activity

  private val executor = Executors.newFixedThreadPool(1);

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
     _lib = Native.loadLibrary("polyvox_filament_android", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
    activity.window.setFormat(PixelFormat.RGBA_8888)
  }

  val _resources:MutableMap<Int,Memory> = mutableMapOf();
  var _lastId = 1

  override fun loadResourceFromOwner(path: String?, owner: Pointer?): ResourceBuffer {
      Log.i("polyvox_filament", "Loading resource from path $path")
      var data:ByteArray? = null
      if(path!!.startsWith("file://")) {
          data = File(path!!.substring(6)).readBytes()
      } else {
          val loader = FlutterInjector.instance().flutterLoader()
          val key = loader.getLookupKeyForAsset(path)
          val hotReloadPath = HotReloadPathHelper.getAssetPath(key, activity.getPackageName())
          if (hotReloadPath != null) {
              data = File(hotReloadPath).readBytes()
          } else {
              val assetManager: AssetManager = activity.assets
              try {
                  data = assetManager.open(key).readBytes()
              } catch (e:Exception) {
                  Log.e("polyvox_filament", "Failed to open asset at ${path}", null)
              }
          }
      }
      val rb = ResourceBuffer();
      try {
          if (data != null) {
              val dataPtr = Memory(data.size.toLong())
              dataPtr.write(0, data, 0, data.size)
              rb.data = dataPtr
              rb.size = data.size
              rb.id = _lastId
              _resources[rb.id] = dataPtr;
              _lastId++
          } else {
              rb.id = 0
              rb.size = 0
              rb.data = Pointer(0)
          }
      } catch(e:Exception) {
          Log.e("polyvox_filament", "Error setting resource buffer : $e", null);
      }
      rb.write();
      return rb;

  }


  override fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?) {
    _resources.remove(rb.id)
  }

  override fun renderCallback(owner:Pointer?) {

  }


  @RequiresApi(Build.VERSION_CODES.M)
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.e("polyvox_filament", call.method, null)
    when (call.method) {
      "getSharedContext" -> { 
        val nativeWindow = _lib.get_native_window_from_surface(_surface!! as Object, JNIEnv.CURRENT)
        result.success(Pointer.nativeValue(nativeWindow))
      }
        "createTexture" -> {
          if(_surfaceTextureEntry != null) {
            result.error("TEXTURE_EXISTS", "Texture already exist. Make sure you call destroyTexture first", null)
            return
          }
          val args = call.arguments as List<*>
          val width = args[0] as Double
          val height = args[1] as Double
          if(width <1 || height < 1) {
              result.error("DIMENSION_MISMATCH","Both dimensions must be greater than zero", null);
              return;
          }
          Log.i("polyvox_filament", "Creating texture of size ${width}x${height}");
          
          _surfaceTextureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
          _surfaceTexture = _surfaceTextureEntry!!.surfaceTexture();
          _surfaceTexture!!.setDefaultBufferSize(width.toInt(), height.toInt())

          _surface = Surface(_surfaceTexture)

          val nativeWindow = _lib.get_native_window_from_surface(_surface!! as Object, JNIEnv.CURRENT)

          val resultList = listOf(_surfaceTextureEntry!!.id(), Pointer.nativeValue(nativeWindow), null )
          val resourceLoader = _lib.make_resource_loader(this, this, Pointer(0))
          result.success(resultList)
        }
        "getResourceLoaderWrapper" -> { 
          val resourceLoader = _lib.make_resource_loader(this, this, Pointer(0))
          result.success(Pointer.nativeValue(resourceLoader))
        }
        "getRenderCallback" -> {
          val renderCallbackFnPointer = _lib.make_render_callback_fn_pointer(this)
          result.success(listOf(Pointer.nativeValue(renderCallbackFnPointer), 0))
        }
        "destroyTexture" -> {
          _surface!!.release();
          _surfaceTextureEntry!!.release();
          _surface = null
          _surfaceTextureEntry = null
        }
        "resize" -> {
            val args = call.arguments as List<Any>
            val width = args[0] as Int
            val height = args[1] as Int
            val scale = args[2] as Double
            _surfaceTexture!!.setDefaultBufferSize(width, height)
            Log.i(TAG, "Resized to ${args[0]}x${args[1]}")
            result.success(_surfaceTexture)
        } 
        else -> {
          result.notImplemented()
        }
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
