#include "polyvox_filament_plugin.h"

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

#include <GLFW/glfw3.h>
#include "GL/GL.h"
#include "GL/GLu.h"

#include "PolyvoxFilamentApi.h"

namespace polyvox_filament {

// static
void PolyvoxFilamentPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "app.polyvox.filament/event",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PolyvoxFilamentPlugin>(
    registrar->texture_registrar(),
    registrar
  );

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PolyvoxFilamentPlugin::PolyvoxFilamentPlugin(
  flutter::TextureRegistrar* textureRegistrar,
  flutter::PluginRegistrarWindows *pluginRegistrar) : _textureRegistrar(textureRegistrar), _pluginRegistrar(pluginRegistrar) {

}

PolyvoxFilamentPlugin::~PolyvoxFilamentPlugin() {}


static ResourceBuffer _loadResource(const char* name) {
  auto rb = ResourceBuffer(nullptr, 0, 0);
  return rb;
}

static void _freeResource(ResourceBuffer rbuf) {
  
}

void PolyvoxFilamentPlugin::CreateFilamentViewer(
  const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    auto window = glfwGetCurrentContext();
    const ResourceLoaderWrapper* const resourceLoader = new ResourceLoaderWrapper(_loadResource, _freeResource);
    _viewer = (void*) create_filament_viewer(window, resourceLoader);
    create_swap_chain(_viewer, window, 1024, 768);
    // result->Success(flutter::EncodableValue((long)_viewer));
    result->Success(flutter::EncodableValue(0));
}

void PolyvoxFilamentPlugin::Render(
  const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    render(_viewer, 0);
    _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);
    result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::CreateTexture(
  const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    
  // HWND m_hWnd = _pluginRegistrar->GetView()->GetNativeWindow();
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    
  glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

  GLFWwindow* window = glfwCreateWindow(1024, 768, "", nullptr, nullptr);
  if (!window) {
      std::cout << "Failed to create GLFW window" << std::endl;
      glfwTerminate();
      return;
  }

  glfwMakeContextCurrent(window);

  glClearColor(0.1f, 0.2f, 0.3f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  auto data = new uint8_t[1024*768*4];
  glReadPixels(0,0, 1024, 768, GL_RGBA, GL_UNSIGNED_BYTE, data); 
  _pixelData.reset(data);

  GLuint glTextureId = 0;

  auto textureData = new uint8_t[1024*768*4];
  for(int y = 0; y < 768; y++) {
    for(int x=0; x < 1024; x++) {
      textureData[y*768 + (x*4)] = 0;
      textureData[y*768 + (x*4+1)] = 255;
      textureData[y*768 + (x*4+2)] = 0;
      textureData[y*768 + (x*4+3)] = 255;
    }
  }

  glGenTextures(1, &glTextureId);

  glBindTexture(GL_TEXTURE_2D, glTextureId);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1024, 768, 0, GL_RGBA,
                  GL_UNSIGNED_BYTE, textureData);
  
  _pixelBuffer = std::make_unique<FlutterDesktopPixelBuffer>();
  _pixelBuffer->buffer = _pixelData.get();

  _pixelBuffer->width = 1024;
  _pixelBuffer->height = 768;

  _texture = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
      [=](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
        std::cout << "Copying pixel buffer for " << width << "x" << height << std::endl;
        uint8_t* data = _pixelData.get();
        glReadPixels(0,0, (GLsizei)width, (GLsizei)height, GL_RGBA, GL_UNSIGNED_BYTE, data); 
        return _pixelBuffer.get();
      }));
      
  std::cout << "Registering texture" << std::endl;

  _flutterTextureId = _textureRegistrar->RegisterTexture(_texture.get());
  _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);
  std::cout << "Registered " << _flutterTextureId << std::endl;

  result->Success(flutter::EncodableValue(_flutterTextureId));
}

void PolyvoxFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    std::cout << methodCall.method_name() << std::endl;

   if(methodCall.method_name() == "createFilamentViewer") {
    CreateFilamentViewer(methodCall, std::move(result));
  } else if(methodCall.method_name() ==  "createTexture") {
    CreateTexture(methodCall, std::move(result));    
  } //else if(strcmp(method, "updateViewportAndCameraProjection")==0){ 
  //   response = _update_viewport_and_camera_projection(methodCall);
  // } 
  // else if(strcmp(method, "getAssetManager") ==0){ 
  //   response = _get_asset_manager(self, methodCall);
  // } else if(strcmp(method, "setToneMapping") == 0) {
  //   response = _set_tone_mapping(self, methodCall);
  // } else if(strcmp(method, "setBloom") == 0) {
  //   response = _set_bloom(self, methodCall);
  // } else if(strcmp(method, "resize") == 0) {
  //   response = _resize(self, methodCall);
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
  //   self->rendering =  fl_value_get_bool(fl_methodCall_get_args(methodCall));
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

  // fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace


