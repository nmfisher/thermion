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

interface LoadResourceFromOwner : Callback {
    fun loadResourceFromOwner(resourceName: String?, owner: Pointer?): ResourceBuffer
}

interface FreeResourceFromOwner : Callback {
    fun freeResourceFromOwner(rb: ResourceBuffer, owner: Pointer?)
}
interface FilamentInterop : Library {

fun create_filament_viewer(context:Pointer, loader:Pointer) : Pointer;
fun create_swap_chain(viewer: Pointer, window:Pointer?, width:Int, height:Int);
fun get_native_window_from_surface(surface:Object, env:JNIEnv) : Pointer;
fun delete_filament_viewer(viewer: Pointer)
fun get_asset_manager(viewer: Pointer?): Pointer?
fun create_render_target(viewer: Pointer, texture_id: Int, width: Int, height: Int)
fun clear_background_image(viewer: Pointer)
fun set_background_image(viewer: Pointer, path: String, fill_height: Boolean)
fun set_background_image_position(viewer: Pointer, x: Float, y: Float, clamp: Boolean)
fun set_background_color(viewer: Pointer, r: Float, g: Float, b: Float, a: Float)
fun set_tone_mapping(viewer: Pointer, tone_mapping: Int)
fun set_bloom(viewer: Pointer, strength: Float)
fun load_skybox(viewer: Pointer, skybox_path: String)
fun load_ibl(viewer: Pointer, ibl_path: String, intensity: Float)
fun remove_skybox(viewer: Pointer)
fun remove_ibl(viewer: Pointer)
fun add_light(viewer: Pointer, type: Byte, colour: Float, intensity: Float, pos_x: Float, pos_y: Float, pos_z: Float, dir_x: Float, dir_y: Float, dir_z: Float, shadows: Boolean): EntityId
fun remove_light(viewer: Pointer, entity_id: EntityId)
fun clear_lights(viewer: Pointer)
fun load_glb(asset_manager: Pointer, asset_path: String, unlit: Boolean): EntityId
fun load_gltf(asset_manager: Pointer, asset_path: String, relative_path: String): EntityId
fun set_camera(viewer: Pointer, asset: EntityId, node_name: String): Boolean
fun render(viewer: Pointer, frame_time_in_nanos: Long)

fun destroy_swap_chain(viewer: Pointer)
fun set_frame_interval(viewer: Pointer, interval: Float)
fun update_viewport_and_camera_projection(viewer: Pointer, width: UInt, height: UInt, scale_factor: Float)
fun scroll_begin(viewer: Pointer)
fun scroll_update(viewer: Pointer, x: Float, y: Float, z: Float)
fun scroll_end(viewer: Pointer)
fun grab_begin(viewer: Pointer, x: Float, y: Float, pan: Boolean)
fun grab_update(viewer: Pointer, x: Float, y: Float)
fun grab_end(viewer: Pointer)
fun apply_weights(asset_manager: Pointer, asset: EntityId, entity_name: String, weights: FloatArray, count: Int)
fun set_morph_target_weights(asset_manager: Pointer, asset: EntityId, entity_name: String, morph_data: FloatArray, num_weights: Int)
fun set_morph_animation(asset_manager: Pointer, asset: EntityId, entity_name: String, morph_data: FloatArray, morph_indices: IntArray, num_morph_targets: Int, num_frames: Int, frame_length_in_ms: Int): Boolean
fun set_bone_animation(asset_manager: Pointer, asset: EntityId, frame_data: FloatArray, num_frames: Int, num_bones: Int, bone_names: Array<String>, mesh_name: Array<String>, num_mesh_targets: Int, frame_length_in_ms: Int)
fun play_animation(asset_manager: Pointer, asset: EntityId, index: Int, loop: Boolean, reverse: Boolean, replace_active: Boolean, crossfade: Float)
fun set_animation_frame(asset_manager: Pointer, asset: EntityId, animation_index: Int, animation_frame: Int)
fun stop_animation(asset_manager: Pointer, asset: EntityId, index: Int)
fun get_animation_count(asset_manager: Pointer, asset: EntityId): Int
fun get_animation_name(asset_manager: Pointer, asset: EntityId, out_ptr: String, index: Int)
fun get_animation_duration(asset_manager: Pointer, asset: EntityId, index: Int): Float
fun get_morph_target_name(asset_manager: Pointer, asset: EntityId, mesh_name: String, out_ptr: String, index: Int)
fun get_morph_target_name_count(asset_manager: Pointer, asset: EntityId, mesh_name: String): Int
fun remove_asset(viewer: Pointer, asset: EntityId)
fun clear_assets(viewer: Pointer)
fun load_texture(asset_manager: Pointer, asset: EntityId, asset_path: String, renderable_index: Int)
fun set_texture(asset_manager: Pointer, asset: EntityId)
fun set_material_color(asset_manager: Pointer, asset: EntityId, mesh_name: String, material_index: Int, r: Float, g: Float, b: Float, a: Float): Boolean
fun transform_to_unit_cube(asset_manager: Pointer, asset: EntityId)
fun set_position(asset_manager: Pointer, asset: EntityId, x: Float, y: Float, z: Float)
fun set_rotation(asset_manager: Pointer, asset: EntityId, rads: Float, x: Float, y: Float, z: Float)
fun set_scale(asset_manager: Pointer, asset: EntityId, scale: Float)
fun set_camera_exposure(viewer: Pointer, aperture: Float, shutter_speed: Float, sensitivity: Float)
fun set_camera_position(viewer: Pointer, x: Float, y: Float, z: Float)
fun set_camera_rotation(viewer: Pointer, rads: Float, x: Float, y: Float, z: Float)
fun set_camera_model_matrix(viewer: Pointer, matrix: FloatArray)
fun set_camera_focal_length(viewer: Pointer, focal_length: Float)
fun set_camera_focus_distance(viewer: Pointer, focus_distance: Float)
fun hide_mesh(asset_manager: Pointer, asset: EntityId, mesh_name: String): Int
fun reveal_mesh(asset_manager: Pointer, asset: EntityId, mesh_name: String): Int
fun ios_dummy()
fun make_resource_loader(loadResourceFromOwner: LoadResourceFromOwner, freeResource: FreeResourceFromOwner, owner:Pointer?) : Pointer;
}

