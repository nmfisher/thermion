package app.polyvox.filament
import android.content.res.AssetManager 

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.graphics.PixelFormat

import io.flutter.FlutterInjector

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
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
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

import java.util.Collections;

import com.google.android.filament.android.DisplayHelper

import android.hardware.display.DisplayManager
       
import com.google.android.filament.android.*
import com.google.android.filament.*
import com.google.android.filament.SwapChain
import com.google.android.filament.utils.*

import android.view.Choreographer
import android.view.SurfaceHolder


class FilamentView(
    private val viewId: Int,
    private val context: Context,
    private val activity: Activity,
    private val binaryMessenger: BinaryMessenger,
    private val creationParams : Map<String?, Any?>?
)  : DefaultLifecycleObserver, 
MethodChannel.MethodCallHandler, 
PlatformView  {

    companion object {
        const val TAG = "FilamentView"
    }

    private val _view = SurfaceView(context)

    override fun getView(): View {
        return _view
    }

    private val _methodChannel: MethodChannel

    private lateinit var _lib : FilamentInterop

    private var _viewer : Pointer? = null

    private lateinit var choreographer: Choreographer
    private lateinit var displayHelper : DisplayHelper
    private val frameScheduler = FrameCallback()

    private lateinit var uiHelper : UiHelper

    private lateinit var assetManager : AssetManager

    init {
        MethodChannel(binaryMessenger, PolyvoxFilamentPlugin.VIEW_TYPE + '_' + viewId).also {
            _methodChannel = it
            it.setMethodCallHandler(this)
        }
        _lib = Native.loadLibrary("filament_interop", FilamentInterop::class.java, Collections.singletonMap(Library.OPTION_ALLOW_OBJECTS, true))
        
        
        choreographer = Choreographer.getInstance()
                
        _view.setZOrderOnTop(false)
        _view.holder.setFormat(PixelFormat.OPAQUE)

        _view.holder.addCallback (object : SurfaceHolder.Callback {
            override fun surfaceChanged(holder:SurfaceHolder, format:Int, width:Int, height:Int) {
              _lib.update_viewport_and_camera_projection(_viewer!!, width, height, 1.0f);
            }
        
            override fun surfaceCreated(holder:SurfaceHolder) {            
              _lib.destroy_swap_chain(_viewer!!)
              _lib.create_swap_chain(_viewer!!, _view.holder.surface, JNIEnv.CURRENT)
            }
            override fun surfaceDestroyed(holder:SurfaceHolder) {
              _lib.destroy_swap_chain(_viewer!!)
            }
        })
        assetManager = context.assets
        _viewer = _lib.filament_viewer_new(
                        _view.holder.surface as Object,
                        "unused",
                        "unused",
                        JNIEnv.CURRENT,
                        assetManager)

        choreographer.postFrameCallback(frameScheduler)

        val mDisplayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        activity.window.setFormat(PixelFormat.RGBA_8888)

        uiHelper = UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK)
        uiHelper.renderCallback = SurfaceCallback()
        uiHelper.attachTo(_view)
    }
    
    override fun onFlutterViewAttached(flutterView:View) {

    }

    override fun dispose() {
      _methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadSkybox" -> {
                val args = call.arguments as ArrayList<Any?>
                val loader = FlutterInjector.instance().flutterLoader()
                _lib.load_skybox(_viewer!!, loader.getLookupKeyForAsset(args[0] as String), loader.getLookupKeyForAsset(args[1] as String))                
                result.success("OK");
            }
            "loadGlb" -> {
                if (_viewer == null)
                    return;
                val loader = FlutterInjector.instance().flutterLoader()
                _lib.load_glb(
                    _viewer!!,
                    loader.getLookupKeyForAsset(call.arguments as String)
                )
                result.success("OK");
            }
            "loadGltf" -> {
                if (_viewer == null)
                    return;
                val args = call.arguments as ArrayList<Any?>
                val loader = FlutterInjector.instance().flutterLoader()
                _lib.load_gltf(
                    _viewer!!,
                    loader.getLookupKeyForAsset(args[0] as String),
                    loader.getLookupKeyForAsset(args[1] as String)
                )
                result.success("OK");
            }
            "setCamera" -> {
              if (_viewer == null)
                    return;
                val success = _lib.set_camera(
                    _viewer!!,
                    call.arguments as String
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
              val arrPtr = PointerByReference();
              val countPtr = IntByReference();
              _lib.get_target_names(_viewer!!, call.arguments as String, arrPtr, countPtr)

              val names = arrPtr.value.getStringArray(0, countPtr.value);

              Log.v(TAG, "Got target names $names")

              val namesAsList = names.toCollection(ArrayList())

              _lib.free_pointer(arrPtr, countPtr.getValue())

              Log.v(TAG, "Free complete")

              result.success(namesAsList)
            } 
            "applyWeights" -> {
              if(_viewer == null)
              return;
              val weights = call.arguments as ArrayList<Float>;
    
              _lib.apply_weights(_viewer!!, weights.toFloatArray(), weights.size)
              result.success("OK");
            }
            "animateWeights" -> {
              if(_viewer == null)
                return;
              val args = call.arguments as ArrayList<Any?>
              val frames = args[0] as ArrayList<Float>;
              val numWeights = args[1] as Int
              val frameRate = args[2] as Double
    
              _lib.animate_weights(_viewer!!, frames.toFloatArray(), numWeights, (frames.size / numWeights).toInt(), frameRate.toFloat())
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
            "releaseSourceAssets" -> {
              _lib.release_source_assets(_viewer!!)
              result.success("OK");
            }
        }
    }

    inner class SurfaceCallback : UiHelper.RendererCallback {
        override fun onNativeWindowChanged(surface: Surface) {
            _lib.destroy_swap_chain(_viewer!!)
            _lib.create_swap_chain(_viewer!!, surface, JNIEnv.CURRENT)
        }

        override fun onDetachedFromSurface() {
            _lib.destroy_swap_chain(_viewer!!)
        }

        override fun onResized(width: Int, height: Int) {
            _lib.update_viewport_and_camera_projection(_viewer!!, width, height, 1.0f)
        }
    }


    inner class FrameCallback : Choreographer.FrameCallback {
        private val startTime = System.nanoTime()
        override fun doFrame(frameTimeNanos: Long) {
            choreographer.postFrameCallback(this)

            // modelViewer.animator?.apply {
            //     if (animationCount > 0) {
            //         val elapsedTimeSeconds = (frameTimeNanos - startTime).toDouble() / 1_000_000_000
            //         applyAnimation(0, elapsedTimeSeconds.toFloat())
            //     }
            //     updateBoneMatrices()
            // }
            _lib.render(_viewer!!)
        }
    }
}
