package app.polyvox.filament 

import com.sun.jna.ptr.PointerByReference
import com.sun.jna.ptr.IntByReference

import android.view.Surface

import android.content.res.AssetManager
import com.sun.jna.*

open class ResourceBuffer: Structure(), Structure.ByValue {
    @JvmField var data: Pointer = Pointer(0);
    @JvmField var size: Int = 0;
    @JvmField var id: Int = 0;
    override fun getFieldOrder(): List<String> {
        return listOf("data", "size", "id")
    }
}

interface LoadFilamentResourceFromOwner : Callback {
    fun loadResourceFromOwner(resourceName: String?, owner: Pointer?): ResourceBuffer
}

interface FreeFilamentResourceFromOwner : Callback {
    fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?)
}

interface RenderCallback : Callback { 
    fun renderCallback(owner:Pointer?)
}

interface FilamentInterop : Library {

fun get_native_window_from_surface(surface:Object, env:JNIEnv) : Pointer?;
fun make_render_callback_fn_pointer(renderCallback:RenderCallback) : Pointer
fun make_resource_loader(loadResourceFromOwner: LoadFilamentResourceFromOwner, freeResource: FreeFilamentResourceFromOwner, owner:Pointer?) : Pointer;
fun create_filament_viewer_ffi(context:Pointer, platform:Pointer, loader:Pointer, rc:Pointer, rco:Pointer) : Pointer;
fun create_swap_chain_ffi(vieer:Pointer?, surface:Pointer?, width:Int, height:Int)
fun set_background_color_ffi(viewer: Pointer?, r: Float, g: Float, b: Float, a: Float)
fun update_viewport_and_camera_projection_ffi(viewer: Pointer?, width: Int, height: Int, scale_factor: Float)
fun render_ffi(viewer: Pointer?)
fun create_filament_viewer(context:Pointer?, platform:Pointer?, loader:Pointer?) : Pointer;
fun create_swap_chain(vieer:Pointer?, surface:Pointer?, width:Int, height:Int)
fun set_background_color(viewer: Pointer?, r: Float, g: Float, b: Float, a: Float)
fun update_viewport_and_camera_projection(viewer: Pointer?, width: Int, height: Int, scale_factor: Float)
fun render(viewer: Pointer?, u:Long, a:Pointer?, b:Pointer?, c:Pointer?)
}

