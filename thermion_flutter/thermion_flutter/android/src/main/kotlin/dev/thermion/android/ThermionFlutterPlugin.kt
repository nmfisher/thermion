package dev.thermion.android

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

class NativeWindowHelper {
    companion object {
      external fun getNativeWindowFromSurface(surface: Surface): Long
    }
}

class ThermionFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  companion object {
      const val CHANNEL_NAME = "dev.thermion.flutter/event"
      const val TAG = "FilamentPlugin"
  }

  private lateinit var channel : MethodChannel

  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

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

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    Log.d("thermion_flutter", "Loading library")
    System.loadLibrary("thermion_flutter_android")
    Log.d("thermion_flutter", "Loaded")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
    activity.window.setFormat(PixelFormat.RGBA_8888)
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
                Log.d("thermion_flutter", "Creating SurfaceTexture ${width}x${height}")
                
                val surfaceTextureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
                val surfaceTexture = surfaceTextureEntry.surfaceTexture()
                surfaceTexture.setDefaultBufferSize(width, height)

                val surface = Surface(surfaceTexture)

                if (!surface.isValid) {
                    result.error("SURFACE_INVALID", "Failed to create valid surface", null)
                } else {
                    val flutterTextureId = surfaceTextureEntry.id()   
                    textures[flutterTextureId] = TextureEntry(surfaceTextureEntry, surfaceTexture, surface)
                    //val surface = surfaceView.holder.surface
                    Log.d("thermion_flutter", "Loading library")
                    System.loadLibrary("thermion_flutter_android")
                    val nativeWindowPtr = NativeWindowHelper.getNativeWindowFromSurface(surface)
                    //val nativeWindow = _lib.get_native_window_from_surface(surface as Object, JNIEnv.CURRENT)
                    result.success(listOf(flutterTextureId, flutterTextureId, nativeWindowPtr))
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
