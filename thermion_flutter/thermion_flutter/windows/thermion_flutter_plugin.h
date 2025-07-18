#pragma once

#define THERMION_WIN32_KHR_BUILD

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <chrono>
#include <memory>
#include <mutex>

#include <Windows.h>
#include <wrl.h>
#include "vulkan_context.h"

namespace thermion::tflutter::windows {

class ThermionFlutterPlugin : public ::flutter::Plugin {
public:
  static void RegisterWithRegistrar(::flutter::PluginRegistrarWindows *registrar);

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
 
  void CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DestroyTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RenderCallback();

  private:
    thermion::windows::vulkan::ThermionVulkanContext *_context = nullptr;
    bool OnTextureUnregistered(int64_t flutterTextureId);

};

} // namespace thermion_flutter


