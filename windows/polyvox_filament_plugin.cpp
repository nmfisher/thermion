#include "include/polyvox_filament/polyvox_filament_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

namespace {

class PolyvoxFilamentPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PolyvoxFilamentPlugin();

  virtual ~PolyvoxFilamentPlugin();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void PolyvoxFilamentPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "polyvox_filament",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PolyvoxFilamentPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PolyvoxFilamentPlugin::PolyvoxFilamentPlugin() {}

PolyvoxFilamentPlugin::~PolyvoxFilamentPlugin() {}

static FlMethodResponse* _set_bloom(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  set_bloom(self->viewer, fl_value_get_float(args));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));      
}

void PolyvoxFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
 if(strcmp(method, "createFilamentViewer") == 0) {
    response = _create_filament_viewer(self, method_call);
  } else if(strcmp(method, "createTexture") == 0) {
    response = _create_texture(self, method_call);    
  } else if(strcmp(method, "updateViewportAndCameraProjection")==0){ 
    response = _update_viewport_and_camera_projection(self, method_call);
  } 
  // else if(strcmp(method, "getAssetManager") ==0){ 
  //   response = _get_asset_manager(self, method_call);
  // } else if(strcmp(method, "setToneMapping") == 0) {
  //   response = _set_tone_mapping(self, method_call);
  // } else if(strcmp(method, "setBloom") == 0) {
  //   response = _set_bloom(self, method_call);
  // } else if(strcmp(method, "resize") == 0) {
  //   response = _resize(self, method_call);
  // } else if(strcmp(method, "getContext") == 0) {
  //   g_autoptr(FlValue) result =   
  //        fl_value_new_int(reinterpret_cast<int64_t>(glXGetCurrentContext()));   
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "getGlTextureId") == 0) {
  //   g_autoptr(FlValue) result =   
  //        fl_value_new_int(reinterpret_cast<unsigned int>(((FilamentTextureGL*)self->texture)->texture_id));   
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "getResourceLoader") == 0) {
  //   ResourceLoaderWrapper* resourceLoader = new ResourceLoaderWrapper(loadResource, freeResource);
  //   g_autoptr(FlValue) result =   
  //        fl_value_new_int(reinterpret_cast<int64_t>(resourceLoader));   
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "setRendering") == 0) {
  //   self->rendering =  fl_value_get_bool(fl_method_call_get_args(method_call));
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));
  // } else if(strcmp(method, "loadSkybox") == 0) {
  //   response = _loadSkybox(self, method_call);
  // } else if(strcmp(method, "loadIbl") == 0) {
  //   response = _loadIbl(self, method_call);
  // } else if(strcmp(method, "removeIbl") ==0) { 
  //   response = _remove_ibl(self, method_call);
  // } else if(strcmp(method, "removeSkybox") == 0) {
  //   response = _removeSkybox(self, method_call);    
  // } else if(strcmp(method, "render") == 0) {
  //   render(self->viewer, 0);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "setBackgroundColor") == 0) {
  //   response = _set_background_color(self, method_call);
  // } else if(strcmp(method, "setBackgroundImage") == 0) {
  //   response = _set_background_image(self, method_call);
  // } else if(strcmp(method, "addLight") == 0) {
  //   response = _add_light(self, method_call);  
  // } else if(strcmp(method, "loadGlb") == 0) {
  //   response = _load_glb(self, method_call);
  // } else if(strcmp(method, "getAnimationNames") == 0) {
  //   response = _get_animation_names(self, method_call);
  // } else if(strcmp(method, "clearAssets") == 0) {
  //   clear_assets(self->viewer);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "removeAsset") == 0) {
  //   response = _remove_asset(self, method_call);
  // } else if(strcmp(method, "transformToUnitCube") == 0) {
  //   response = _transform_to_unit_cube(self, method_call);
  // } else if(strcmp(method, "clearLights") == 0) {
  //   clear_lights(self->viewer);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "panStart") == 0) {
  //   response = _pan_start(self, method_call);
  // } else if(strcmp(method, "panEnd") == 0) {
  //   response = _pan_end(self, method_call);
  // } else if(strcmp(method, "panUpdate") == 0) {
  //   response = _pan_update(self, method_call);
  // } else if(strcmp(method, "rotateStart") == 0) {
  //   response = _rotate_start(self, method_call);
  // } else if(strcmp(method, "rotateEnd") == 0) {
  //   response = _rotate_end(self, method_call);
  // } else if(strcmp(method, "rotateUpdate") == 0) {
  //   response = _rotate_update(self, method_call);
  // } else if(strcmp(method, "setRotation") == 0) {
  //   response = _set_rotation(self, method_call);
  // } else if(strcmp(method, "setCamera") == 0) {
  //   response = _set_camera(self, method_call);
  // } else if(strcmp(method, "setCameraModelMatrix") == 0) {
  //   response = _set_camera_model_matrix(self, method_call);
  // } else if(strcmp(method, "setCameraExposure") == 0) {
  //   response = _set_camera_exposure(self, method_call);
  // } else if(strcmp(method, "setCameraPosition") == 0) {
  //   response = _set_camera_position(self, method_call);
  // } else if(strcmp(method, "setCameraRotation") == 0) {
  //   response = _set_camera_rotation(self, method_call);
  // } else if(strcmp(method, "setFrameInterval") == 0) {
  //   response = _set_frame_interval(self, method_call);
  // } else if(strcmp(method, "scrollBegin") == 0) {
  //   response = _scroll_begin(self, method_call);
  // } else if(strcmp(method, "scrollEnd") == 0) {
  //   response = _scroll_end(self, method_call);
  // } else if(strcmp(method, "scrollUpdate") == 0) {
  //   response = _scroll_update(self, method_call);
  // } else if(strcmp(method, "grabBegin") == 0) {
  //   response = _grab_begin(self, method_call);
  // } else if(strcmp(method, "grabEnd") == 0) {
  //   response = _grab_end(self, method_call);
  // } else if(strcmp(method, "grabUpdate") == 0) {
  //   response = _grab_update(self, method_call);
  // } else if(strcmp(method, "playAnimation") == 0) {
  //   response = _play_animation(self, method_call);
  // } else if(strcmp(method, "stopAnimation") == 0) {
  //   response = _stop_animation(self, method_call);
  // } else if(strcmp(method, "setMorphTargetWeights") == 0) {
  //   response = _set_morph_target_weights(self, method_call);
  // } else if(strcmp(method, "setMorphAnimation") == 0) {
  //   response = _set_morph_animation(self, method_call);
  // } else if(strcmp(method, "getMorphTargetNames") == 0) {
  //   response = _get_morph_target_names(self, method_call);
  // } else if(strcmp(method, "setPosition") == 0) {
  //   response = _set_position(self, method_call);
  // } else if(strcmp(method, "setBoneTransform") == 0) {
  //   response = _set_bone_transform(self, method_call);
  // } else {
  //   response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  // }

  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

void PolyvoxFilamentPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  PolyvoxFilamentPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
