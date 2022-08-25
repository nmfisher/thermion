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

    fun filament_viewer_new_android(
            layer:Object,
            env:JNIEnv,
            am:AssetManager
    ) : Pointer;

    fun filament_viewer_delete(
            viewer:Pointer,
    ) : Pointer;

    fun load_skybox(viewer:Pointer, skyboxPath:String) : Pointer;

    fun load_ibl(viewer:Pointer, skyboxPath:String) : Pointer;

    fun load_glb(viewer:Pointer, uri:String) : Pointer;

    fun load_gltf(viewer:Pointer, uri:String, relativeResourcePath:String) : Pointer;
    
    fun set_camera(viewer:Pointer, asset:Pointer, nodeName:String) : Boolean;

    fun render(viewer:Pointer);

    fun create_swap_chain(viewer:Pointer, surface:Surface, env:JNIEnv);

    fun destroy_swap_chain(viewer:Pointer);

    fun update_viewport_and_camera_projection(viewer:Pointer, width:Int, height:Int, scaleFactor:Float);

    fun scroll(viewer:Pointer, x:Float, y:Float, z:Float);

    fun grab_begin(viewer:Pointer, x:Int, y:Int, pan:Boolean)

    fun grab_update(viewer:Pointer, x:Int, y:Int)

    fun grab_end(viewer:Pointer)

    fun apply_weights(asset:Pointer, weights:FloatArray, size:Int);

    fun animate_weights(asset:Pointer, frames:FloatArray, numWeights:Int, numFrames:Int,  frameRate:Float);

    fun get_target_name_count(asset:Pointer, meshName:String) : Int;
    fun get_target_name(asset:Pointer, meshName:String, outPtr:Pointer, index:Int);

    fun get_animation_count(asset:Pointer) : Int;
    fun get_animation_name(asset:Pointer, outPtr:Pointer, index:Int);

    fun play_animation(asset:Pointer, index:Int, loop:Boolean);

    fun free_pointer(ptr:Pointer, size:Int);

    fun remove_asset(viewer:Pointer, asset:Pointer);

    fun clear_assets(viewer:Pointer);

    fun remove_skybox(viewer:Pointer);

    fun remove_ibl(viewer:Pointer);

    fun set_background_image(viewer:Pointer, path:String);
    
    fun load_texture(asset:Pointer, path:String, renderableIndex:Int);
    fun set_texture(asset:Pointer);

    fun transform_to_unit_cube(asset:Pointer);

    fun set_position(asset:Pointer, x:Float, y:Float, z:Float);
    fun set_rotation(asset:Pointer, rads:Float, x:Float, y:Float, z:Float);

    fun set_camera_position(asset:Pointer, x:Float, y:Float, z:Float);
    fun set_camera_rotation(asset:Pointer, rads:Float, x:Float, y:Float, z:Float);
    fun set_camera_focal_length(asset:Pointer, focalLength:Float);
    fun set_camera_focus_distance(asset:Pointer, focusDistance:Float);
}

