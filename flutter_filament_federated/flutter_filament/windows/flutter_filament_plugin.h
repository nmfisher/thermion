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

#include "ResourceBuffer.hpp"

#if USE_ANGLE
#include "egl_context.h"
#else
#include "wgl_context.h"
#endif

namespace flutter_filament {

class FlutterFilamentPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterFilamentPlugin(flutter::TextureRegistrar *textureRegistrar,
                        flutter::PluginRegistrarWindows *registrar,
                        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>& channel);
  virtual ~FlutterFilamentPlugin();

  // Disallow copy and assign.
  FlutterFilamentPlugin(const FlutterFilamentPlugin &) = delete;
  FlutterFilamentPlugin &operator=(const FlutterFilamentPlugin &) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows *_pluginRegistrar;
  flutter::TextureRegistrar *_textureRegistrar;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> _channel;
  std::map<uint32_t, ResourceBuffer> _resources;
 
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
    std::unique_ptr<FlutterEGLContext> _context = nullptr;
    #else 
    std::unique_ptr<WGLContext> _context = nullptr;
    #endif
};

} // namespace flutter_filament

#endif // FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_
