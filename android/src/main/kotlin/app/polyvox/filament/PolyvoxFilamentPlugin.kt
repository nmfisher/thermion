package app.polyvox.filament

import androidx.annotation.NonNull

import androidx.lifecycle.Lifecycle

import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.loader.FlutterApplicationInfo
import io.flutter.embedding.engine.loader.ApplicationInfoLoader

import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference

import android.content.res.AssetManager 

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager

import io.flutter.FlutterInjector

import android.os.CountDownTimer
import android.os.Handler

import android.opengl.GLU
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import android.hardware.Camera
import android.opengl.GLSurfaceView
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.Surface
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver

import io.flutter.plugin.platform.PlatformView
import java.io.IOException

import android.util.Log

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.Memory
import com.sun.jna.ptr.PointerByReference
import com.sun.jna.ptr.IntByReference
import com.sun.jna.Structure
import com.sun.jna.NativeLibrary
import com.sun.jna.StringArray
import com.sun.jna.JNIEnv

import android.R.attr.path
import android.graphics.*

import java.util.Collections;

import android.hardware.display.DisplayManager
       
import com.google.android.filament.android.*
import com.google.android.filament.*

import android.view.Choreographer
import android.view.Surface.CHANGE_FRAME_RATE_ALWAYS
import android.view.Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
import android.view.SurfaceHolder

import java.util.Timer
import java.util.concurrent.Executor
import java.util.concurrent.Executors


/** PolyvoxFilamentPlugin */
class PolyvoxFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  private val lock = Object()

  inner class FrameCallback : Choreographer.FrameCallback {
    private val startTime = System.nanoTime()
    override fun doFrame(frameTimeNanos: Long) {
      choreographer.postFrameCallback(this)

      executor.execute { 
        if(_viewer == null) {
          
        } else if(!surface.isValid()) {
          Log.v(TAG, "INVALID")
        } else {
          _lib.render(_viewer!!, frameTimeNanos)
        }
      }
    }
  }

  companion object {
      const val CHANNEL_NAME = "app.polyvox.filament/event"
      const val TAG = "FilamentPlugin"
  }

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  /// Keep a reference to the plugin binding so we can use the TextureRegistry when initialize is called from the platform channel.
  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop

  private var _viewer : Pointer? = null

  private lateinit var choreographer: Choreographer

  private val frameCallback = FrameCallback()
    
  private lateinit var assetManager : AssetManager

  private lateinit var surface: Surface
  private var surfaceTexture: SurfaceTexture? = null
  
  private lateinit var activity:Activity

  private val executor = Executors.newFixedThreadPool(1);

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    
    _lib = Native.loadLibrary("filament_interop", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
    activity.window.setFormat(PixelFormat.RGBA_8888)
    choreographer = Choreographer.getInstance()
    choreographer.postFrameCallback(frameCallback)
  }

  fun getAssetPath(path:String) : String {
    val loader = FlutterInjector.instance().flutterLoader()
    val key = loader.getLookupKeyForAsset(path)
    val hotReloadPath = HotReloadPathHelper.getAssetPath(key, activity.getPackageName())
    if(hotReloadPath != null) {
      return "file://" + hotReloadPath;
    }
    return key
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        print("Initializing")

        val entry = flutterPluginBinding.textureRegistry.createSurfaceTexture();
        executor.execute { 

          if(_viewer != null) {
            print("Deleting existing viewer")
            _lib.filament_viewer_delete(_viewer!!);
            print("Deleted viewer")
            _viewer = null;
          }
          if(surfaceTexture != null) {
            print("Releasing existing texture")
            surfaceTexture!!.release()
            surfaceTexture = null;
          }
          val args = call.arguments as ArrayList<Int>
          val width = args[0]
          val height = args[1]
  
          surfaceTexture = entry.surfaceTexture()
  
          surfaceTexture!!.setDefaultBufferSize(width, height)
  
          surface = Surface(surfaceTexture!!) 
  
          _viewer = _lib.filament_viewer_new_android(
                      surface as Object,
                      JNIEnv.CURRENT,
                      (activity as Context).assets)
          _lib.update_viewport_and_camera_projection(_viewer!!, width, height, 1.0f);
  
          result.success(entry.id().toInt())

        }
      }
      "resize" -> {
        executor.execute { 
          val args = call.arguments as ArrayList<Int>
          val width = args[0]
          val height = args[1]
          val scale = if(args.size > 2) (args[2] as Double).toFloat() else 1.0f
          surfaceTexture!!.setDefaultBufferSize(width, height)
          _lib.update_viewport_and_camera_projection(_viewer!!, width, height, scale);
          result.success(null)
        }
      }
      "setFrameInterval" -> {
        executor.execute { 
          _lib.set_frame_interval(_viewer!!, (call.arguments as Double).toFloat());
          result.success(null)
        }
      }
        "setBackgroundImage" -> {
          executor.execute { 
            _lib.set_background_image(_viewer!!, getAssetPath(call.arguments as String))                
            result.success("OK");
          }
        }
        "loadSkybox" -> {
          executor.execute { 
            _lib.load_skybox(_viewer!!, getAssetPath(call.arguments as String))
            result.success("OK");
          }
        }
        "loadIbl" -> {
          executor.execute { 
            _lib.load_ibl(_viewer!!, getAssetPath(call.arguments as String))
            result.success("OK");
          }
        }
        "removeIbl" -> {
          executor.execute { 
            _lib.remove_ibl(_viewer!!)                
            result.success(true);
          }
        }
        "removeSkybox" -> {
          executor.execute { 
            _lib.remove_skybox(_viewer!!)                
            result.success(true);
          }
        }
        "loadGlb" -> {
          executor.execute { 
            val assetPtr = _lib.load_glb(
                _viewer!!,
                getAssetPath(call.arguments as String)
            )
            result.success(Pointer.nativeValue(assetPtr));
          }
        }
        "loadGltf" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            val assetPtr = _lib.load_gltf(
                _viewer!!,
                getAssetPath(args[0] as String),
                getAssetPath(args[1] as String)
            )
            result.success(Pointer.nativeValue(assetPtr));
          }
        }
        "transformToUnitCube" -> {
          executor.execute { 
            val assetPtr = Pointer(call.arguments as Long);
            _lib.transform_to_unit_cube(assetPtr)
            result.success("OK");
          }
        }
        "setPosition" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long)
            _lib.set_position(assetPtr, (args[1] as Double).toFloat(), (args[2] as Double).toFloat(), (args[3] as Double).toFloat())
            result.success("OK");
          }
        }
        "setScale" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long)
            _lib.set_scale(assetPtr, (args[1] as Double).toFloat())
            result.success("OK");
          }
        }
        "setRotation" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long)
            _lib.set_rotation(assetPtr, (args[1] as Double).toFloat(), (args[2] as Double).toFloat(), (args[3] as Double).toFloat(), (args[4] as Double).toFloat())
            result.success("OK");
          }
        }
        "setCameraPosition" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            _lib.set_camera_position(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), (args[2] as Double).toFloat())
            result.success("OK");
          }
        }
        "setCameraRotation" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            _lib.set_camera_rotation(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), (args[2] as Double).toFloat(), (args[3] as Double).toFloat())
            result.success("OK");
          }
        }
        "setCameraFocalLength" -> {
          executor.execute { 
            _lib.set_camera_focal_length(_viewer!!, (call.arguments as Double).toFloat())
            result.success("OK");
          }
        }
        "setCameraFocusDistance" -> {
          executor.execute { 
            _lib.set_camera_focus_distance(_viewer!!, (call.arguments as Double).toFloat())
            result.success("OK");
          }
        }
        "setTexture" -> {
          executor.execute {
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long);
            _lib.load_texture(assetPtr, getAssetPath(args[1] as String), args[2] as Int)
            print("Texture loaded")
            result.success("OK");
          }
          
        }
        "setCamera" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val success = _lib.set_camera(
                _viewer!!,
                Pointer(args[0] as Long),
                args[1] as String,
            )
            if(success) {
              result.success("OK");
            } else {
              result.error("failed","failed", "Failed to set camera")
            }
          }
        }
        "zoom" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            _lib.scroll(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), (args[2] as Double).toFloat())
            result.success("OK");
          }
        }
        "getTargetNames" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long)
            val meshName = args[1] as String
            val names = mutableListOf<String>()
            val outPtr = Memory(256)
            for(i in 0.._lib.get_target_name_count(assetPtr, meshName) - 1) {
              _lib.get_target_name(assetPtr, meshName, outPtr, i)
              val name = outPtr.getString(0)
              names.add(name)
            }
            result.success(names)
          }
        } 
        "getAnimationNames" -> {
          executor.execute { 
            val assetPtr = Pointer(call.arguments as Long)
            val names = mutableListOf<String>()
            val outPtr = Memory(256)
            for(i in 0.._lib.get_animation_count(assetPtr) - 1) {
              _lib.get_animation_name(assetPtr, outPtr, i)
              val name = outPtr.getString(0)
              names.add(name)
            }
            result.success(names)
          }
        } 
        "applyWeights" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<*>
            val assetPtr = Pointer(args[0] as Long)
            val weights = args[1] as ArrayList<Float>;

            _lib.apply_weights(assetPtr, weights.toFloatArray(), weights.size)
            result.success("OK");
          }
        }
        "animateWeights" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            val assetPtr = Pointer(args[0] as Long)
            val frames = args[1] as ArrayList<Float>;
            val numWeights = args[2] as Int
            val numFrames = args[3] as Int
            val frameLenInMs = args[4] as Double

            _lib.animate_weights(assetPtr, frames.toFloatArray(), numWeights, numFrames, frameLenInMs.toFloat())
            result.success("OK");
          }
        }
        "panStart" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.grab_begin(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), true)
            result.success("OK");
          }
        }
        "panUpdate" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            val x = (args[0] as Double).toFloat()
            val y = (args[1] as Double).toFloat()
            Log.v(TAG, "panUpdate ${x} ${y}")
            _lib.grab_update(_viewer!!, x, y)
            result.success("OK");
          }
        }
        "panEnd" -> {
          executor.execute { 
            _lib.grab_end(_viewer!!)
            result.success("OK");
          }
        }
        "rotateStart" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.grab_begin(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), false)
            result.success("OK");
          }
        }
        "rotateUpdate" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.grab_update(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat())
            result.success("OK");
          }
        }
        "rotateEnd" -> {
          executor.execute { 
            _lib.grab_end(_viewer!!)
            result.success("OK");
          }
        }
        "grabStart" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.grab_begin(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat(), true)
            result.success("OK");
          }
        }
        "grabUpdate" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.grab_update(_viewer!!, (args[0] as Double).toFloat(), (args[1] as Double).toFloat())
            result.success("OK");
          }
        }
        "grabEnd" -> {
          executor.execute { 
            _lib.grab_end(_viewer!!)
            result.success("OK");
          }
        }
        "removeAsset" -> {
          executor.execute { 
            _lib.remove_asset(_viewer!!, Pointer(call.arguments as Long))
            result.success("OK");
          }
        } 
        "clearAssets" -> {
          executor.execute { 
            _lib.clear_assets(_viewer!!)
            result.success("OK");
          }
        } 
        "playAnimation" -> {
          executor.execute { 
            val args = call.arguments as ArrayList<Any?>
            _lib.play_animation(Pointer(args[0] as Long), args[1] as Int, args[2] as Boolean)
            result.success("OK")
          }
        }
        else -> {
          result.notImplemented()
        }
    }
}

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    _lib.destroy_swap_chain(_viewer!!)
  }

  
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
    _lib.create_swap_chain(_viewer!!, surface, JNIEnv.CURRENT)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromActivity() {
    lifecycle = null
  }
}
