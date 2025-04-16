package dev.thermion.android


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


class LoadFilamentResourceFromOwnerImpl(plugin:ThermionFlutterPlugin) : LoadFilamentResourceFromOwner {
  var plugin = plugin
  override fun loadResourceFromOwner(path: String?, owner: Pointer?): ResourceBuffer {
    return plugin.loadResourceFromOwner(path, owner)
  }
} 

class FreeFilamentResourceFromOwnerImpl(plugin:ThermionFlutterPlugin) : FreeFilamentResourceFromOwner {
  var plugin = plugin
  override fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?) {
    plugin.freeResourceFromOwner(rb, owner)
  }
} 

class RenderCallbackImpl(plugin:ThermionFlutterPlugin) : RenderCallback {
  var plugin = plugin
  override fun renderCallback(owner:Pointer?) {
    plugin.renderCallback();

    if(!plugin._surface!!.isValid) {
      Log.e("thermion_flutter", "Error: surface is no longer valid")
    }
  }
}

/** ThermionFlutterPlugin */
class ThermionFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LoadFilamentResourceFromOwner, FreeFilamentResourceFromOwner {

  companion object {
      const val CHANNEL_NAME = "dev.thermion.flutter/event"
      const val TAG = "FilamentPlugin"
  }

  private lateinit var channel : MethodChannel

  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop

  private data class TextureEntry(
      val surfaceTextureEntry: SurfaceTextureEntry,
      val surfaceTexture: SurfaceTexture,
      val surface: Surface
  )
  
  var _surfaceTexture: SurfaceTexture? = null
  private var _surfaceTextureEntry: SurfaceTextureEntry? = null
  var _surface: Surface? = null
  private val textures: MutableMap<Long, TextureEntry> = mutableMapOf()

      
  private lateinit var activity:Activity

  private var loadResourceWrapper:LoadFilamentResourceFromOwnerImpl = LoadFilamentResourceFromOwnerImpl(this)
  private var freeResourceWrapper:FreeFilamentResourceFromOwnerImpl = FreeFilamentResourceFromOwnerImpl(this)

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    _lib = Native.loadLibrary("thermion_flutter_android", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
    activity.window.setFormat(PixelFormat.RGBA_8888)
  }

  val _resources:MutableMap<ResourceBuffer,Memory> = mutableMapOf();
  var _lastId = 1
  
  override fun loadResourceFromOwner(path: String?, owner: Pointer?): ResourceBuffer {
      Log.i("thermion_flutter", "Loading resource from path $path")
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
              Log.i("thermion_flutter", "Loading resource from main asset bundle at ${assetPath}")

              val assetManager: AssetManager = activity.assets
              try {
                  data = assetManager.open(key).readBytes()
                  Log.i("thermion_flutter", "Loaded ${data.size} bytes")
              } catch (e:Exception) {
                  Log.e("thermion_flutter", "Failed to open asset at ${assetPath}", null)
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
          Log.e("thermion_flutter", "Error setting resource buffer : $e", null);
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
    when (call.method) {
        "createTexture" -> {
                val args = call.arguments as List<*>
                val width = args[0] as Int
                val height = args[1] as Int
                if (width < 1 || height < 1) {
                    result.error("DIMENSION_MISMATCH", "Both dimensions must be greater than zero (you provided $width x $height)", null)
                    return
                }
                Log.i("thermion_flutter", "Creating SurfaceTexture ${width}x${height}")
                
                val surfaceTextureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
                val surfaceTexture = surfaceTextureEntry.surfaceTexture()
                surfaceTexture.setDefaultBufferSize(width, height)

                val surface = Surface(surfaceTexture)

                if (!surface.isValid) {
                    result.error("SURFACE_INVALID", "Failed to create valid surface", null)
                } else {
                    val flutterTextureId = surfaceTextureEntry.id()   
                    textures[flutterTextureId] = TextureEntry(surfaceTextureEntry, surfaceTexture, surface)
                    val nativeWindow = _lib.get_native_window_from_surface(surface as Object, JNIEnv.CURRENT)
                    result.success(listOf(flutterTextureId, flutterTextureId, Pointer.nativeValue(nativeWindow)))
                }
            }
            "destroyTexture" -> {
                val textureId = (call.arguments as Int).toLong()
                val textureEntry = textures[textureId]
                if (textureEntry != null) {
                    textureEntry.surface.release()
                    textureEntry.surfaceTextureEntry.release()
                    textures.remove(textureId)
                    result.success(true)
                } else {
                    result.error("TEXTURE_NOT_FOUND", "Texture with id $textureId not found", null)
                }
            }
            "markTextureFrameAvailable" -> {
                val textureId = (call.arguments as Int).toLong()
                val textureEntry = textures[textureId]
                if (textureEntry != null) {
                    result.success(null)
                } else {
                    result.error("TEXTURE_NOT_FOUND", "Texture with id $textureId not found", null)
                }
            }
        "getDriverPlatform" -> { 
          result.success(null)
        }
        "getSharedContext" -> { 
          result.success(null)
        }
        "getRenderCallback" -> {
          val renderCallbackFnPointer = _lib.make_render_callback_fn_pointer(RenderCallbackImpl(this))
          result.success(listOf(Pointer.nativeValue(renderCallbackFnPointer), 0))
        }
        else -> {
          result.notImplemented()
        }
    }
}

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
      channel.setMethodCallHandler(null)
        // Release all textures
        for ((_, textureEntry) in textures) {
            textureEntry.surface.release()
            textureEntry.surfaceTextureEntry.release()
        }
        textures.clear()
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
