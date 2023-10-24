#ifndef FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <chrono>
#include <memory>
#include <mutex>

#include <Windows.h>
#include <wrl.h>

#include "GL/GL.h"
#include "GL/GLu.h"

#ifdef USE_ANGLE
#include "flutter_angle_texture.h"
#include "backend/platforms/PlatformEGL.h"
#else
#include "opengl_texture_buffer.h"
#endif 

#include "PolyvoxFilamentApi.h"

namespace polyvox_filament {

class PolyvoxFilamentPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PolyvoxFilamentPlugin(flutter::TextureRegistrar *textureRegistrar,
                        flutter::PluginRegistrarWindows *registrar,
                        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>& channel);
  virtual ~PolyvoxFilamentPlugin();

  // Disallow copy and assign.
  PolyvoxFilamentPlugin(const PolyvoxFilamentPlugin &) = delete;
  PolyvoxFilamentPlugin &operator=(const PolyvoxFilamentPlugin &) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows *_pluginRegistrar;
  flutter::TextureRegistrar *_textureRegistrar;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> _channel;
  std::map<uint32_t, ResourceBuffer> _resources;
  std::shared_ptr<std::mutex> _renderMutex;
 
  void CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DestroyTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RenderCallback();

  ResourceBuffer loadResource(const char *path);
  void freeResource(ResourceBuffer rbuf);

  private:
    #ifdef USE_ANGLE
    bool CreateSharedEGLContext();
    bool MakeD3DTexture(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    EGLContext _context = NULL;
    EGLConfig _eglConfig = NULL;
    EGLDisplay _eglDisplay = NULL;
    std::unique_ptr<FlutterAngleTexture> _active = nullptr;
    std::unique_ptr<FlutterAngleTexture> _inactive = nullptr;
    ID3D11Device* _D3D11Device = nullptr;
    ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
    filament::backend::Platform* _platform = nullptr;
    #else 
    std::unique_ptr<OpenGLTextureBuffer> _active = nullptr;
    std::unique_ptr<OpenGLTextureBuffer> _inactive = nullptr;
    // shared OpenGLContext
    HGLRC _context = NULL;
    bool CreateSharedWGLContext();
    bool MakeOpenGLTexture(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    #endif
};

} // namespace polyvox_filament

#endif // FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
