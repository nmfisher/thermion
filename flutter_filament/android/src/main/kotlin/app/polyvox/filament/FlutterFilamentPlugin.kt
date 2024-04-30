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

class LoadFilamentResourceFromOwnerImpl(plugin:FlutterFilamentPlugin) : LoadFilamentResourceFromOwner {
  var plugin = plugin
  override fun loadResourceFromOwner(path: String?, owner: Pointer?): ResourceBuffer {
    return plugin.loadResourceFromOwner(path, owner)
  }
} 

class FreeFilamentResourceFromOwnerImpl(plugin:FlutterFilamentPlugin) : FreeFilamentResourceFromOwner {
  var plugin = plugin
  override fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?) {
    plugin.freeResourceFromOwner(rb, owner)
  }
} 

class RenderCallbackImpl(plugin:FlutterFilamentPlugin) : RenderCallback {
  var plugin = plugin
  override fun renderCallback(owner:Pointer?) {
    plugin.renderCallback();

    if(!plugin._surface!!.isValid) {
      Log.e("ERR", "ERR", null)
    }
  }
}

/** FlutterFilamentPlugin */
class FlutterFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LoadFilamentResourceFromOwner, FreeFilamentResourceFromOwner {

  companion object {
      const val CHANNEL_NAME = "app.polyvox.filament/event"
      const val TAG = "FilamentPlugin"
  }

  private lateinit var channel : MethodChannel

  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop
  
  var _surfaceTexture: SurfaceTexture? = null
  private var _surfaceTextureEntry: SurfaceTextureEntry? = null
  var _surface: Surface? = null
      
  private lateinit var activity:Activity

  private var loadResourceWrapper:LoadFilamentResourceFromOwnerImpl = LoadFilamentResourceFromOwnerImpl(this)
  private var freeResourceWrapper:FreeFilamentResourceFromOwnerImpl = FreeFilamentResourceFromOwnerImpl(this)

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
     _lib = Native.loadLibrary("flutter_filament_android", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
    activity.window.setFormat(PixelFormat.RGBA_8888)
  }

  val _resources:MutableMap<ResourceBuffer,Memory> = mutableMapOf();
  var _lastId = 1

  override fun loadResourceFromOwner(path: String?, owner: Pointer?): ResourceBuffer {
      Log.i("flutter_filament", "Loading resource from path $path")
      var data:ByteArray? = null
      if(path!!.startsWith("file://")) {
          data = File(path!!.substring(6)).readBytes()
      } else {
          var assetPath = path
          if(assetPath.startsWith("asset://")) {
            assetPath = assetPath!!.substring(8)
          }
          val loader = FlutterInjector.instance().flutterLoader()
          val key = loader.getLookupKeyForAsset(assetPath)
          val hotReloadPath = HotReloadPathHelper.getAssetPath(key, activity.getPackageName())
          if (hotReloadPath != null) {
              data = File(hotReloadPath).readBytes()
          } else {
              Log.i("flutter_filament", "Loading resource from main asset bundle at ${assetPath}")

              val assetManager: AssetManager = activity.assets
              try {
                  data = assetManager.open(key).readBytes()
                  Log.i("flutter_filament", "Loaded ${data.size} bytes")
              } catch (e:Exception) {
                  Log.e("flutter_filament", "Failed to open asset at ${assetPath}", null)
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
              _resources[rb] = dataPtr;
              _lastId++
          } else {
              rb.id = 0
              rb.size = 0
              rb.data = Pointer(0)
          }
      } catch(e:Exception) {
          Log.e("flutter_filament", "Error setting resource buffer : $e", null);
      }
      rb.write();
      return rb;

  }

  override fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?) {
    _resources.remove(rb)
  }

  fun renderCallback() {
    // noop, log or check surface.valid() is you want 
  }


  @RequiresApi(Build.VERSION_CODES.M)
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.e("flutter_filament", call.method, null)
    when (call.method) {
        "createTexture" -> {
          if(_surfaceTextureEntry != null) {
            result.error("TEXTURE_EXISTS", "Texture already exist. Make sure you call destroyTexture first", null)
            return
          }
          val args = call.arguments as List<*>
          val width = args[0] as Double
          val height = args[1] as Double
          if(width <1 || height < 1) {
              result.error("DIMENSION_MISMATCH","Both dimensions must be greater than zero (you provided $width x $height)", null);
              return;
          }
          Log.i("flutter_filament", "Creating Surface Texture of size ${width}x${height}");
          
          _surfaceTextureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
          _surfaceTexture = _surfaceTextureEntry!!.surfaceTexture();
          _surfaceTexture!!.setDefaultBufferSize(width.toInt(), height.toInt())

          _surface = Surface(_surfaceTexture)

          if(!_surface!!.isValid) {
              Log.e("ERR", "ERR", null)
          }

          val nativeWindow = _lib.get_native_window_from_surface(_surface!! as Object, JNIEnv.CURRENT)
        
          val resultList = listOf(_surfaceTextureEntry!!.id(), Pointer.nativeValue(nativeWindow), null, null )
          
          result.success(resultList)
        }
        "getResourceLoaderWrapper" -> { 
          val resourceLoader = _lib.make_resource_loader(loadResourceWrapper, freeResourceWrapper, Pointer(0))
          result.success(Pointer.nativeValue(resourceLoader))
        }
        "getRenderCallback" -> {
          val renderCallbackFnPointer = _lib.make_render_callback_fn_pointer(RenderCallbackImpl(this))
          result.success(listOf(Pointer.nativeValue(renderCallbackFnPointer), 0))
        }
        "destroyTexture" -> {
          _surface!!.release();
          _surfaceTextureEntry!!.release();
          _surface = null
          _surfaceTextureEntry = null
          result.success(true)
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
