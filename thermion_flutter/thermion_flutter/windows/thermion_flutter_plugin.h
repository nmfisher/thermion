#ifndef FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <chrono>
#include <memory>
#include <mutex>

#include <Windows.h>
#include <wrl.h>

#include "GL/GL.h"
#include "GL/GLu.h"

#include "ResourceBuffer.h"

#if THERMION_EGL
#include "egl_context.h"
#else
#include "wgl_context.h"
#endif

namespace thermion_flutter {

class ThermionFlutterPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ThermionFlutterPlugin(flutter::TextureRegistrar *textureRegistrar,
                        flutter::PluginRegistrarWindows *registrar,
                        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>& channel);
  virtual ~ThermionFlutterPlugin();

  // Disallow copy and assign.
  ThermionFlutterPlugin(const ThermionFlutterPlugin &) = delete;
  ThermionFlutterPlugin &operator=(const ThermionFlutterPlugin &) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows *_pluginRegistrar;
  flutter::TextureRegistrar *_textureRegistrar;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> _channel;
  std::map<int32_t, ResourceBuffer> _resources;
 
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
    #ifdef THERMION_EGL
    std::unique_ptr<FlutterEGLContext> _context = nullptr;
    #else 
    std::unique_ptr<WGLContext> _context = nullptr;
    #endif
};

} // namespace thermion_flutter

#endif // FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_
