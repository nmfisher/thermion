package app.polyvox.filament 

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.ptr.PointerByReference
import com.sun.jna.ptr.IntByReference
import com.sun.jna.Structure
import com.sun.jna.NativeLibrary
import com.sun.jna.StringArray
import com.sun.jna.JNIEnv

import android.view.Surface

import android.content.res.AssetManager 

import java.nio.ByteBuffer

interface FilamentInterop : Library {

    fun filament_viewer_new(
            layer:Object,
            env:JNIEnv,
            am:AssetManager
    ) : Pointer;

    fun load_skybox(viewer:Pointer, skyboxPath:String, iblPath:String) : Pointer;

    fun load_glb(viewer:Pointer, uri:String) : Pointer;

    fun load_gltf(viewer:Pointer, uri:String, relativeResourcePath:String) : Pointer;
    
    fun set_camera(viewer:Pointer, nodeName:String) : Boolean;

    fun render(viewer:Pointer);

    fun create_swap_chain(viewer:Pointer, surface:Surface, env:JNIEnv);

    fun destroy_swap_chain(viewer:Pointer);

    fun update_viewport_and_camera_projection(viewer:Pointer, width:Int, height:Int, scaleFactor:Float);

    fun scroll(viewer:Pointer, x:Float, y:Float, z:Float);

    fun grab_begin(viewer:Pointer, x:Int, y:Int, pan:Boolean)

    fun grab_update(viewer:Pointer, x:Int, y:Int)

    fun grab_end(viewer:Pointer)

    fun apply_weights(viewer:Pointer, weights:FloatArray, size:Int);

    fun animate_weights(viewer:Pointer, frames:FloatArray, numWeights:Int, numFrames:Int,  frameRate:Float);

    fun get_target_names(viewer:Pointer, meshName:String, outLen:IntByReference) : Pointer;

    fun get_animation_names(viewer:Pointer, outLen:IntByReference) : Pointer;

    fun play_animation(viewer:Pointer, index:Int, loop:Boolean);

    fun free_pointer(ptr:Pointer, size:Int);

    fun release_source_assets(viewer:Pointer);

}
