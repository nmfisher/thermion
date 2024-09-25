package dev.thermion.android 

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
fun make_resource_loader_wrapper_android(loadResourceFromOwner: LoadFilamentResourceFromOwner, freeResource: FreeFilamentResourceFromOwner, owner:Pointer?) : Pointer;

}

