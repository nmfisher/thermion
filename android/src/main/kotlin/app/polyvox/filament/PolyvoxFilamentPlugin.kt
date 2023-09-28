package app.polyvox.filament


import HotReloadPathHelper
import android.app.Activity
import android.content.res.AssetManager
import android.graphics.*
import android.opengl.*
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
class PolyvoxFilamentPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LoadResourceFromOwner, FreeResourceFromOwner {

  private val lock = Object()

  inner class FrameCallback : Choreographer.FrameCallback {
    private val startTime = System.nanoTime()
    override fun doFrame(frameTimeNanos: Long) {
      choreographer.postFrameCallback(this)
      if(_viewer != null && _rendering) {
        _lib.render(_viewer!!, frameTimeNanos)
      }
    }
  }

  companion object {
      const val CHANNEL_NAME = "app.polyvox.filament/event"
      const val TAG = "FilamentPlugin"
  }

  private lateinit var channel : MethodChannel

  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding

  private var lifecycle: Lifecycle? = null

  private lateinit var _lib : FilamentInterop

  private var _viewer : Pointer? = null
  private var _rendering : Boolean = false
  private var _glContext: EGLContext? = null
  private var mEglDisplay: EGLDisplay? = null
  private var _glTextureId = 0

  private var _surfaceTexture: SurfaceTexture? = null
  private var _surfaceTextureEntry: SurfaceTextureEntry? = null
  private var _surface: Surface? = null

  private lateinit var choreographer: Choreographer

  private val frameCallback = FrameCallback()
    
  private lateinit var assetManager : AssetManager
  
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
    choreographer = Choreographer.getInstance()
    choreographer.postFrameCallback(frameCallback)
  }

  @RequiresApi(Build.VERSION_CODES.M)
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.e("polyvox_filament", call.method, null)
    when (call.method) {
        "createTexture" -> {
//              if(_glTextureId != 0) {
//                  result.success(_glTextureId)
//                  return
//              }
//              if(_glContext == null) {
//                  _glContext = EGL14.eglGetCurrentContext()
//                  if (_glContext == EGL14.EGL_NO_CONTEXT) {

//                      // if(surfaceTextureEntry != null) {
//                      //   result.error("ERR", "Surface texture already exists. Call destroyTexture before creating a new one", null);
//                      // } else {
//                      //   surface = Surface(surfaceTextureEntry!!.surfaceTexture())

//                      //   if(!surface!!.isValid) {
//                      //       result.error("ERR", "Surface creation failed. ", null);
//                      //   } else {
//                      //       result.success(surfaceTextureEntry!!.id().toInt())
//                      //   }
//  //          }

//                      mEglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
//                      if (mEglDisplay == EGL14.EGL_NO_DISPLAY) {
//                          result.error("Err", "eglGetDisplay failed", null);
//                          return;
//                      }

//                      val version = IntArray(2)

//                      if (!EGL14.eglInitialize(mEglDisplay, version, 0, version, 1)) {
//                          var error = EGL14.eglGetError();
//                          Log.e("DISPLAY_FAILED", "NativeEngine: failed to init display %d");
//                      }

//                      val attribs = intArrayOf(
//                              EGL14.EGL_RENDERABLE_TYPE, EGL15.EGL_OPENGL_ES3_BIT,
//                              EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
//                              EGL14.EGL_BLUE_SIZE, 8,
//                              EGL14.EGL_GREEN_SIZE, 8,
//                              EGL14.EGL_RED_SIZE, 8,
//                              EGL14.EGL_DEPTH_SIZE, 16,
//                              EGL14.EGL_NONE);
//                      var numConfigs = intArrayOf(1)
//                      val configs: Array<android.opengl.EGLConfig?> = arrayOf<EGLConfig?>(null)

//                      if(!EGL14.eglChooseConfig(mEglDisplay, attribs, 0, configs, 0, 1, numConfigs, 0)) {
//                          result.error("NO_GL_CONTEXT", "Failed to get matching EGLConfig", null);
//                          return;
//                      }

//                      _glContext = EGL14.eglCreateContext(mEglDisplay, configs[0]!!, EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE), 0);

//                      if (_glContext === EGL14.EGL_NO_CONTEXT || EGL14.eglMakeCurrent(mEglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, _glContext) == false) {
//                          result.error("NO_GL_CONTEXT", "Failed to get current OpenGL context", null);
//                          return;
//                      };
//                      Log.i("polyvox_filament", "Successfully created OpenGL context");
//                  }
//              }

              val args = call.arguments as List<*>
              val width = 256 //args[0] as Double
              val height = 256// args[1] as Double
              if(width <1 || height < 1) {
                  result.error("DIMENSION_MISMATCH","Both dimensions must be greater than zero", null);
                  return;
              }
              Log.i("polyvox_filament", "Creating texture of size ${width}x${height}");
//              val texture = IntArray(1)
//              GLES32.glGenTextures(1, texture, 0)
//              _glTextureId = texture[0]

//              GLES32.glBindTexture(GLES32.GL_TEXTURE_2D, _glTextureId)
//              GLES32.glTexParameteri(GLES32.GL_TEXTURE_2D, GLES32.GL_TEXTURE_MIN_FILTER, GLES32.GL_LINEAR)
//              GLES32.glTexParameteri(GLES32.GL_TEXTURE_2D, GLES32.GL_TEXTURE_MAG_FILTER, GLES32.GL_LINEAR)
//              GLES32.glTexParameteri(GLES32.GL_TEXTURE_2D, GLES32.GL_TEXTURE_WRAP_S, GLES32.GL_CLAMP_TO_EDGE)
//              GLES32.glTexParameteri(GLES32.GL_TEXTURE_2D, GLES32.GL_TEXTURE_WRAP_T, GLES32.GL_CLAMP_TO_EDGE)
//              GLES32.glTexImage2D(
//                      GLES32.GL_TEXTURE_2D,
//                      0,
//                      GLES32.GL_RGBA,
//                      width.toInt(),
//                      height.toInt(),
//                      0,
//                      GLES32.GL_RGBA,
//                      GLES32.GL_UNSIGNED_BYTE,
//                      null
//               )
//              if(_glTextureId == 0) {
//                  result.error("GL_TEXTURE_CREATE_FAILED", "Failed to create OpenGL texture. Check logcat for details", null);
//                  return;
//              }

//              _surfaceTexture = SurfaceTexture(_glTextureId)

//              _surfaceTexture!!.setOnFrameAvailableListener({
//                  Log.i("TMP","FRAME AVAILABLE");
//              })
//              _surfaceTextureEntry = flutterPluginBinding.textureRegistry.registerSurfaceTexture(_surfaceTexture!!)

            _surfaceTextureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
            _surfaceTexture = _surfaceTextureEntry!!.surfaceTexture();
            _surfaceTexture!!.setDefaultBufferSize(width.toInt(), height.toInt())

            _surface = Surface(_surfaceTexture)
            // val canvas = _surface!!.lockHardwareCanvas()
            // canvas.drawColor(Color.GREEN)
            // _surface!!.unlockCanvasAndPost(canvas)
            result.success(_surfaceTextureEntry!!.id())
        }
        "destroyTexture" -> {
          if (_viewer != null) {
              result.error("INVALID_ARGUMENTS", "Destroy the viewer before destroying the texture", null)
          } else {
              _surface!!.release();
              _surfaceTextureEntry!!.release();
              _surface = null
              _surfaceTextureEntry = null
          }
        }
        "destroyViewer" -> {
            if (_viewer != null) {
                _lib.destroy_swap_chain(_viewer!!)
                _lib.delete_filament_viewer(_viewer!!)
                _viewer = null
            }
            result.success(true)
        }
        "resize" -> {
            if (_viewer == null) {
                result.error("VIEWER_NULL", "Error: cannot resize before a viewer has been created", null)
                return
            }
            val wasRendering = _rendering;
            _rendering = false
            _lib.destroy_swap_chain(_viewer!!)
            val args = call.arguments as List<Any>
            val width = 100 // args[0] as Int
            val height = 100 // args[1] as Int
            val scale = 1.0 // args[2] as Float
            _surfaceTexture!!.setDefaultBufferSize(width, height)
            val nativeWindow = _lib.get_native_window_from_surface(_surface!! as Object, JNIEnv.CURRENT)
            _lib.create_swap_chain(_viewer!!, nativeWindow, width, height)
            _lib.update_viewport_and_camera_projection(_viewer!!, width as UInt, height as UInt, scale.toFloat())
            _rendering = wasRendering;
            Log.i(TAG, "Resized to ${args[0]}x${args[1]}")
            result.success(_surfaceTexture)
        }
        "createFilamentViewer" -> {
            if (_viewer != null) {
              _lib.destroy_swap_chain(_viewer!!)
              _lib.delete_filament_viewer(_viewer!!)
              _viewer = null
            }
            val resourceLoader = _lib.make_resource_loader(this, this, Pointer(0))
            val nativeWindow = _lib.get_native_window_from_surface(_surface!! as Object, JNIEnv.CURRENT)
            _viewer = _lib.create_filament_viewer(nativeWindow, resourceLoader);

              // _viewer = _lib.create_filament_viewer(
              //         _glContext!!.nativeHandle,
              //         resourceLoader)
            val args = call.arguments as List<Any>
            var width = args[0] as Double
            val height = args[1] as Double
            if(width < 1 || height < 1) {
              result.error("DIMENSION_MISMATCH","Both dimensions must be greater than zero", null);
              return;
            }
            _lib.create_swap_chain(_viewer!!, nativeWindow, width.toInt(), height.toInt())
            // _lib.create_render_target(_viewer!!, _glTextureId, width.toInt(),height.toInt());
            result.success(Pointer.nativeValue(_viewer!!))

        }
      "getAssetManager" -> {
          val assetManager = _lib.get_asset_manager(_viewer!!)
          result.success(assetManager!!)
      }
      "clearBackgroundImage" -> {
          _lib.clear_background_image(_viewer!!)
          result.success(true)
      }
      "setBackgroundImage" -> {
          val args = call.arguments as List<*>
          
          val path = args[0] as String
          val fillHeight = args[1] as Boolean
          _lib.set_background_image(_viewer!!, path, fillHeight)
          result.success(true)
      }
      "setBackgroundImagePosition" -> {
          val args = call.arguments as List<*>
          _lib.set_background_image_position(_viewer!!, args[0] as Float, args[1] as Float, args[2] as Boolean)
          result.success(true)
      }
      "setBackgroundColor" -> {
          val args = call.arguments as List<Double>
          _lib.set_background_color(_viewer!!, args[0].toFloat(), args[1].toFloat(), args[2].toFloat(), args[3].toFloat())
          result.success(true)
      }
      "setToneMapping" -> {
          val args = call.arguments as Int
          _lib.set_tone_mapping(_viewer!!, args);  
          result.success(true)
      }
      "setBloom" -> {
          val args = call.arguments as Float
          _lib.set_bloom(_viewer!!, args as Float); 
          result.success(true)
      }
      "loadSkybox" -> {
          _lib.load_skybox(_viewer!!, call.arguments as String)
          result.success(true)
      }
      "loadIbl" -> {
          val args = call.arguments as List<*>
          _lib.load_ibl(_viewer!!, args[0] as String, args[1] as Float)
          result.success(true)
      }
      "removeSkybox" -> {
        _lib.remove_skybox(_viewer!!)
        result.success(true)
      }
      "removeIbl" -> {
          _lib.remove_ibl(_viewer!!)
          result.success(true)
      }
      "addLight" -> {
        val args = call.arguments as? List<*>
        if (args != null && args.size == 10) {
            val type = (args[0] as Int)?.toByte()
            val colour = args[1] as Float
            val intensity = args[2] as Float
            val posX = args[3] as Float
            val posY = args[4] as Float
            val posZ = args[5] as Float
            val dirX = args[6] as Float
            val dirY = args[7] as Float
            val dirZ = args[8] as Float
            val shadows = args[9] as Boolean

            val entityId = _lib.add_light(_viewer!!, type, colour as Float, intensity as Float,posX as Float, posY as Float, posZ as Float, dirX as Float, dirY as Float, dirZ as Float, shadows)
            result.success(entityId)
          }
      }
      "removeLight" -> {
       _lib.remove_light(_viewer!!, call.arguments as Int)
        result.success(true)
    }
    "clearLights" -> {
       _lib.clear_lights(_viewer!!)
        result.success(true)
    }
    "loadGlb" -> {
        val args = call.arguments as List<Any>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected assetManager!!, assetPath, and unlit for load_glb", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val assetPath = args[1] as String
        val unlit = args[2] as Boolean
        val entityId =_lib.load_glb(assetManager!!, assetPath, unlit)
        result.success(entityId)
    }
    "loadGltf" -> {
        val args = call.arguments as List<Any>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected assetManager!!, assetPath, and relativePath for load_gltf", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val assetPath = args[1] as String
        val relativePath = args[2] as String
        val entityId =_lib.load_gltf(assetManager!!, assetPath, relativePath)
        result.success(entityId)
    }
    "transformToUnitCube" -> {
      val args = call.arguments as List<Any>
      val assetManager = Pointer((args[0] as Int).toLong())
      val entityId = args[1] as EntityId
      _lib.transform_to_unit_cube(assetManager, entityId)
      result.success(true)
    }
    "render" -> {
        _lib.render(_viewer!!, 0)
//        _surfaceTexture!!.updateTexImage()
        result.success(true)
    }
    "setRendering" -> {
        _rendering = call.arguments as Boolean
        result.success(true)
    }
    "setFrameInterval" -> {
        if (_viewer != null) {
           _lib.set_frame_interval(_viewer!!, call.arguments as Float)
        }
        result.success(true)
    }
    "updateViewportAndCameraProjection" -> {
        val args = call.arguments as List<Any>
        val width = args[0] as Int
        val height = args[1] as Int
        val scaleFactor = args[2] as Double
      //  _lib.update_viewport_and_camera_projection(_viewer!!, width.toUInt(), height.toUInt(), scaleFactor.toFloat())
        result.success(true)
    }
    "scrollBegin" -> {
     _lib.scroll_begin(_viewer!!)
      result.success(true)
    }
      "scrollUpdate" -> {
          val args = call.arguments as List<Any>
          if (args.size != 3) {
              result.error("INVALID_ARGUMENTS", "Expected viewer, x, y, and z for scroll_update", null)
              return
          }
          val x = args[0] as Float
          val y = args[1] as Float
          val z = args[2] as Float
         _lib.scroll_update(_viewer!!, x.toFloat(), y.toFloat(), z.toFloat())
          result.success(true)
      }
      "scrollEnd" -> {
         _lib.scroll_end(_viewer!!)
          result.success(true)
      }
      "grabBegin" -> {
          val args = call.arguments as List<Any>
          if (args.size != 3) {
              result.error("INVALID_ARGUMENTS", "Expected viewer, x, y, and pan for grab_begin", null)
              return
          }
          val x = args[0] as Float
          val y = args[1] as Float
          val pan = args[2] as Boolean
         _lib.grab_begin(_viewer!!, x.toFloat(), y.toFloat(), pan)
          result.success(true)
      }
      "grabUpdate" -> {
          val args = call.arguments as List<Any>
          if (args.size != 2) {
              result.error("INVALID_ARGUMENTS", "Expected viewer, x, y for grab_update", null)
              return
          }
          val x = args[0] as Float
          val y = args[1] as Float
         _lib.grab_update(_viewer!!, x.toFloat(), y.toFloat())
          result.success(true)
      }
      "grabEnd" -> {
         _lib.grab_end(_viewer!!)
          result.success(true)
      }
      "applyWeights" -> {
        // Use the following code snippet to get the arguments from call.arguments
        // guard let args = call.arguments as? List<*>, args.count == 5,
        //       let assetManager = args[0] as? Int64,
        //       let asset = args[1] as? EntityId,
        //       let entityName = args[2] as? String,
        //       let weights = args[3] as? [Float],
        //       let count = args[4] as? Int else {
        //     result.success(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected correct arguments for apply_weights", details: nil))
        //     return
        // }
        //                 _lib.apply_weights(assetManager!!, asset, entityName, UnsafeMutablePointer(&weights), count)
        result.success(true)
      }
      "setMorphTargetWeights" -> {
        val args = call.arguments as List<Any>
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val entityName = args[2] as String
        val morphData = args[3] as List<Double>
        val numMorphWeights = args[4] as Int

       _lib.set_morph_target_weights(
            assetManager!!,
            asset,
            entityName,
            morphData.map { it.toFloat() }.toFloatArray(),
            numMorphWeights
        )

        result.success(true)
      }
      "setMorphAnimation" -> {
        val args = call.arguments as List<Any>
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val entityName = args[2] as String
        val morphData = args[3] as List<Double>
        val morphIndices = args[4] as List<Int>
        val numMorphTargets = args[5] as Int
        val numFrames = args[6] as Int
        val frameLengthInMs = args[7] as Int

        val frameData = morphData.map { it.toFloat() }

        val success =_lib.set_morph_animation(
            assetManager!!,
            asset,
            entityName,
            frameData.toFloatArray(),
            morphIndices.toIntArray(),
            numMorphTargets,
            numFrames,
            frameLengthInMs
        )
        result.success(success) 
      }
      "setBoneAnimation" -> {
        val args = call.arguments as Array<*>
        if (args.size != 9) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for set_bone_animation", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val frameData = args[2] as FloatArray
        val numFrames = args[3] as Int
        val numBones = args[4] as Int
        val boneNames = args[5] as Array<String>
        val meshNames = args[6] as Array<String>
        val numMeshTargets = args[7] as Int
        val frameLengthInMs = args[8] as Int
       _lib.set_bone_animation(assetManager!!, asset, frameData, numFrames, numBones, boneNames, meshNames, numMeshTargets, frameLengthInMs)
        result.success(true)
      }
      "playAnimation" -> {
        val args = call.arguments as Array<*>
        if (args.size != 7) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for play_animation", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val index = args[2] as Int
        val loop = args[3] as Boolean
        val reverse = args[4] as Boolean
        val replaceActive = args[5] as Boolean
        val crossfade = args[6] as Float
       _lib.play_animation(assetManager!!, asset, index, loop, reverse, replaceActive, crossfade.toFloat())
        result.success(true)
      }
      "getAnimationDuration" -> {
        val args = call.arguments as List<*>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for getAnimationDuration", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val animationIndex = args[2] as Int

        val dur =_lib.get_animation_duration(assetManager!!, asset, animationIndex)
        result.success(dur)
      }
      "setAnimationFrame" -> {
        val args = call.arguments as List<*>
        if (args.size != 4) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for set_animation_frame", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val animationIndex = args[2] as Int
        val animationFrame = args[3] as Int

       _lib.set_animation_frame(assetManager!!, asset, animationIndex, animationFrame)
        result.success(true)
      }
      "stopAnimation" -> {
        val args = call.arguments as List<*>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for stop_animation", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val index = args[2] as Int
       _lib.stop_animation(assetManager!!, asset, index)
        result.success(true)
      }
      "getAnimationCount" -> {
        val args = call.arguments as List<*>
        if (args.size != 2) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for get_animation_count", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val count =_lib.get_animation_count(assetManager!!, asset)
        result.success(count)
      }
      "getAnimationNames" -> {
        val args = call.arguments as List<*>
        if (args.size != 2) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for get_animation_name", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val names = mutableListOf<String>()
        val count =_lib.get_animation_count(assetManager!!, asset)
        val buffer = ""  // Assuming max name length of 256 for simplicity
        for (i in 0 until count) {
           _lib.get_animation_name(assetManager!!, asset, buffer, i)
            names.add(buffer)
        }
        result.success(names)
      }
      "getAnimationName" -> {
        val args = call.arguments as List<*>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for get_animation_name", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val index = args[2] as Int
        val buffer = ""  // Assuming max name length of 256 for simplicity
       _lib.get_animation_name(assetManager!!, asset, buffer, index)
        val name = buffer
        result.success(name)
      }
      "getMorphTargetName" -> {
        val args = call.arguments as? List<*>
        if (args == null || args.size != 4) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for get_morph_target_name", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as? EntityId ?: return
        val meshName = args[2] as? String ?: return
        val index = args[3] as? Int ?: return
        
        val buffer = ""  // Assuming max name length of 256 for simplicity
       _lib.get_morph_target_name(assetManager!!, asset, meshName, buffer, index)
        val targetName = buffer
        result.success(targetName)
      }
      "getMorphTargetNames" -> {
        val args = call.arguments as? List<*>
        if (args == null || args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for get_morph_target_names", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())

        val asset = args[1] as? EntityId ?: return
        val meshName = args[2] as? String ?: return
        
        val count =_lib.get_morph_target_name_count(assetManager!!, asset, meshName)
        val names = ArrayList<String>()
        if (count > 0) {
            for (i in 0 until count) {
                val buffer = ""  // Assuming max name length of 256 for simplicity
               _lib.get_morph_target_name(assetManager!!, asset, meshName, buffer, i)
                names.add(buffer)
            }
        }
        result.success(names)
      }
      "getMorphTargetNameCount" -> {
        val args = call.arguments as List<*>
        if (args.size != 3) {
            result.error("INVALID_ARGUMENTS", "Expected correct arguments for getMorphTargetNameCount", null)
            return
        }
        val assetManager = Pointer((args[0] as Int).toLong())
        val asset = args[1] as Int
        val meshName = args[2] as String
        val count =_lib.get_morph_target_name_count(assetManager!!, asset, meshName)
        result.success(count)
      }
      "removeAsset" -> {
       _lib.remove_asset(_viewer!!, call.arguments as Int)
        result.success(true)
      }
      "clearAssets" -> {
       _lib.clear_assets(_viewer!!)
        result.success(true)
      }
      "setCamera" -> {
        val args = call.arguments as List<*>
        if (args.size != 2) {
            result.error("INVALID_ARGUMENTS", "Expected asset and nodeName for setCamera", null)
            return
        }
        val asset = args[0] as Int
        val nodeName = args[1] as String
        val success =_lib.set_camera(_viewer!!, asset, nodeName)
        result.success(success)
      }
      "setCameraPosition" -> {
        val args = call.arguments as List<*>
       _lib.set_camera_position(_viewer!!, (args[0] as Float).toFloat(), (args[1] as Float).toFloat(), (args[2] as Float).toFloat())
        result.success(true)
      }
      "setCameraRotation" -> {
        val args = call.arguments as List<*>
       _lib.set_camera_rotation(_viewer!!, args[0] as Float, args[1] as Float, args[2] as Float, args[3] as Float)
        result.success(true)
      }
      "setCameraModelMatrix" -> {
        val matrix = call.arguments as List<Float>
       _lib.set_camera_model_matrix(_viewer!!, matrix.toFloatArray())
        result.success(true)
      }
      "setCameraFocalLength" -> {
       _lib.set_camera_focal_length(_viewer!!, call.arguments as Float)
        result.success(true)
      }
      "setCameraFocusDistance" -> {
       _lib.set_camera_focus_distance(_viewer!!, call.arguments as Float)
        result.success(true)
      }
      "setMaterialColor" -> {
        val args = call.arguments as List<*>
       _lib.set_material_color(args[0] as Int, args[1] as Int, args[2] as String, args[3] as Int, args[4] as Float, args[5] as Float, args[6] as Float, args[7] as Float)
        result.success(true)
      }
      "hideMesh" -> {
        val args = call.arguments as List<*>
        val status =_lib.hide_mesh(args[0] as Int, args[1] as Int, args[2] as String)
        result.success(status)
      }
      "revealMesh" -> {
        val args = call.arguments as List<*>
        val status =_lib.reveal_mesh(args[0] as Int, args[1] as Int, args[2] as String)
        result.success(status)
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

    val _resources:MutableMap<Int,Memory> = mutableMapOf();
    var _lastId = 1
    var _ptr:Pointer = Pointer(0)

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


}
