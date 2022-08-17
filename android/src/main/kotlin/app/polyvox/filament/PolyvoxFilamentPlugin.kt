package app.polyvox.filament

import androidx.annotation.NonNull

import androidx.lifecycle.Lifecycle

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference

import android.content.res.AssetManager 

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager

import io.flutter.FlutterInjector

import 	android.os.CountDownTimer

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


/** PolyvoxFilamentPlugin */
class PolyvoxFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  inner class FrameCallback : Choreographer.FrameCallback {
    private val startTime = System.nanoTime()
    override fun doFrame(frameTimeNanos: Long) {
        choreographer.postFrameCallback(this)
      if(!surface.isValid()) {
        Log.v(TAG, "INVALID")
      }
      _lib.render(_viewer!!)
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

  /// Keep a referene to the plugin binding so we can use the TextureRegistry when initialize is called from the platform channel.
  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop

  private var _viewer : Pointer? = null

  private lateinit var choreographer: Choreographer

  private val frameCallback = FrameCallback()
    
  private lateinit var assetManager : AssetManager

  private lateinit var surface: Surface
  private lateinit var surfaceTexture: SurfaceTexture
  
  private lateinit var activity:Activity

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    
    _lib = Native.loadLibrary("filament_interop", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
    activity = binding.activity
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        val args = call.arguments as ArrayList<Int>
        val width = args[0]
        val height = args[1]
        
        val entry = flutterPluginBinding.textureRegistry.createSurfaceTexture();

        choreographer = Choreographer.getInstance()

        surfaceTexture = entry.surfaceTexture()

        surfaceTexture.setDefaultBufferSize(width, height)

        surface = Surface(surfaceTexture) 

        _viewer = _lib.filament_viewer_new(
                    surface as Object,
                    JNIEnv.CURRENT,
                    (activity as Context).assets)

        choreographer.postFrameCallback(frameCallback)

        activity.window.setFormat(PixelFormat.RGBA_8888)

        _lib.update_viewport_and_camera_projection(_viewer!!, width, height, 1.0f);

        result.success(entry.id().toInt())
      }
      "resize" -> {
        val args = call.arguments as ArrayList<Int>
        val width = args[0]
        val height = args[1]

        surfaceTexture.setDefaultBufferSize(width, height)
        _lib.update_viewport_and_camera_projection(_viewer!!, width, height, 1.0f);
        result.success(null)
      }
      "reloadAssets" -> {
          // context = context.createPackageContext(context.getPackageName(), 0)
          // val assetManager = context.getAssets()
          // val flutterJNI = 	FlutterJNI.Factory.provideFlutterJNI()
          // flutterJNI.updateJavaAssetManager(assetManager, flutterApplicationInfo.flutterAssetsDir)
        }
        "setBackgroundImage" -> {
            val args = call.arguments as String
            val loader = FlutterInjector.instance().flutterLoader()
            _lib.set_background_image(_viewer!!, loader.getLookupKeyForAsset(args))                
            _lib.render(_viewer!!)
            result.success("OK");
        }
        "loadSkybox" -> {
            val args = call.arguments as String
            val loader = FlutterInjector.instance().flutterLoader()
            _lib.load_skybox(_viewer!!, loader.getLookupKeyForAsset(args))                
            result.success("OK");
        }
        "loadIbl" -> {
            val args = call.arguments as String
            val loader = FlutterInjector.instance().flutterLoader()

            _lib.load_ibl(_viewer!!, loader.getLookupKeyForAsset(args))
            result.success("OK");
        }
        "removeIbl" -> {
          _lib.remove_ibl(_viewer!!)                
          result.success(true);
        }
        "removeSkybox" -> {
          _lib.remove_skybox(_viewer!!)                
          result.success(true);
        }
        "loadGlb" -> {
            if (_viewer == null)
                return;
            val loader = FlutterInjector.instance().flutterLoader()
            val key = loader.getLookupKeyForAsset(call.arguments as String)
            val key2 = loader.getLookupKeyForAsset(call.arguments as String, (activity as Context).packageName)
            val path = loader.findAppBundlePath()

            val assetPtr = _lib.load_glb(
                _viewer!!,
                key
            )
            result.success(Pointer.nativeValue(assetPtr));
        }
        "loadGltf" -> {
            if (_viewer == null)
                return;
            val args = call.arguments as ArrayList<Any?>
            val loader = FlutterInjector.instance().flutterLoader()
            val assetPtr = _lib.load_gltf(
                _viewer!!,
                loader.getLookupKeyForAsset(args[0] as String),
                loader.getLookupKeyForAsset(args[1] as String)
            )
            result.success(Pointer.nativeValue(assetPtr));
        }
        "transformToUnitCube" -> {
          val assetPtr = Pointer(call.arguments as Long);
          _lib.transform_to_unit_cube(assetPtr)
          result.success("OK");
        }
        "setPosition" -> {
          val args = call.arguments as ArrayList<*>
          val assetPtr = Pointer(args[0] as Long)
          _lib.set_position(assetPtr, (args[1] as Double).toFloat(), (args[2] as Double).toFloat(), (args[3] as Double).toFloat())
          result.success("OK");
        }
        "setRotation" -> {
          val args = call.arguments as ArrayList<*>
          val assetPtr = Pointer(args[0] as Long)
          _lib.set_rotation(assetPtr, (args[1] as Double).toFloat(), (args[2] as Double).toFloat(), (args[3] as Double).toFloat(), (args[4] as Double).toFloat())
          result.success("OK");
        }
        "setTexture" -> {
          val args = call.arguments as ArrayList<*>
          val loader = FlutterInjector.instance().flutterLoader()
          val assetPtr = Pointer(args[0] as Long);
          _lib.set_texture(assetPtr, loader.getLookupKeyForAsset(args[1] as String), args[2] as Int)
          result.success("OK");
        }
        "setCamera" -> {
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
        "zoom" -> {
          if(_viewer == null)
            return;
          _lib.scroll(_viewer!!, 0.0f, 0.0f, (call.arguments as Double).toFloat())
          result.success("OK");
        }
        "getTargetNames" -> {
          if(_viewer == null)
            return;
          
          val countPtr = IntByReference();
          val args = call.arguments as ArrayList<*>
          val namesPtr = _lib.get_target_names(Pointer(args[0] as Long), args[1] as String, countPtr)

          val names = namesPtr.getStringArray(0, countPtr.value);

          for(i in 0..countPtr.value-1) {
            Log.v(TAG, "Got target names ${names[i]} ${names[i].length}")
          }
          
          val namesAsList = names.toCollection(ArrayList())

          _lib.free_pointer(namesPtr, countPtr.getValue())

          result.success(namesAsList)
        } 
        "getAnimationNames" -> {
          val assetPtr = Pointer(call.arguments as Long)
          val countPtr = IntByReference();
          val arrPtr = _lib.get_animation_names(assetPtr, countPtr)

          val names = arrPtr.getStringArray(0, countPtr.value);

          for(i in 0..countPtr.value-1) {
            val name = names[i];
            Log.v(TAG, "Got animation names ${name} ${name.length}")
          }
          
          _lib.free_pointer(arrPtr, 1)

          result.success(names.toCollection(ArrayList()))
        } 
        "applyWeights" -> {
          val args = call.arguments as ArrayList<*>
          val assetPtr = Pointer(args[0] as Long)
          val weights = args[1] as ArrayList<Float>;

          _lib.apply_weights(assetPtr, weights.toFloatArray(), weights.size)
          result.success("OK");
        }
        "animateWeights" -> {
          val args = call.arguments as ArrayList<Any?>
          val assetPtr = Pointer(args[0] as Long)
          val frames = args[1] as ArrayList<Float>;
          val numWeights = args[2] as Int
          val numFrames = args[3] as Int
          val frameLenInMs = args[4] as Double

          _lib.animate_weights(assetPtr, frames.toFloatArray(), numWeights, numFrames, frameLenInMs.toFloat())
          result.success("OK");
        }
        "panStart" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_begin(_viewer!!, args[0] as Int, args[1] as Int, true)
          result.success("OK");
        }
        "panUpdate" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_update(_viewer!!, args[0] as Int, args[1] as Int)
          result.success("OK");
        }
        "panEnd" -> {
          _lib.grab_end(_viewer!!)
          result.success("OK");
        }
        "rotateStart" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_begin(_viewer!!, args[0] as Int, args[1] as Int, false)
          result.success("OK");
        }
        "rotateUpdate" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_update(_viewer!!, args[0] as Int, args[1] as Int)
          result.success("OK");
        }
        "rotateEnd" -> {
          _lib.grab_end(_viewer!!)
          result.success("OK");
        }
        "grabStart" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_begin(_viewer!!, args[0] as Int, args[1] as Int, true)
          result.success("OK");
        }
        "grabUpdate" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.grab_update(_viewer!!, args[0] as Int, args[1] as Int)
          result.success("OK");
        }
        "grabEnd" -> {
          _lib.grab_end(_viewer!!)
          result.success("OK");
        }
        "removeAsset" -> {
          _lib.remove_asset(_viewer!!, Pointer(call.arguments as Long))
          result.success("OK");
        } 
        "clearAssets" -> {
          _lib.clear_assets(_viewer!!)
          result.success("OK");
        } 
        "playAnimation" -> {
          val args = call.arguments as ArrayList<Any?>
          _lib.play_animation(Pointer(args[0] as Long), args[1] as Int, args[2] as Boolean)
          result.success("OK")
        }
        else -> {
          result.notImplemented()
        }
    }
}

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    //_lib.destroy_swap_chain(_viewer!!)
  }

  
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
    //_lib.create_swap_chain(_viewer!!, surface, JNIEnv.CURRENT)

  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromActivity() {
    lifecycle = null
  }
}
