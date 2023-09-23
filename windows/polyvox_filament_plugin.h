#ifndef FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "PolyvoxFilamentApi.h"

namespace polyvox_filament {

class PolyvoxFilamentPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PolyvoxFilamentPlugin(
    flutter::TextureRegistrar* textureRegistrar,
    flutter::PluginRegistrarWindows *registrar
  );
  virtual ~PolyvoxFilamentPlugin();

  // Disallow copy and assign.
  PolyvoxFilamentPlugin(const PolyvoxFilamentPlugin&) = delete;
  PolyvoxFilamentPlugin& operator=(const PolyvoxFilamentPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* _pluginRegistrar;
  flutter::TextureRegistrar* _textureRegistrar;

  std::unique_ptr<flutter::TextureVariant> _texture = nullptr;
  std::unique_ptr<FlutterDesktopPixelBuffer> _pixelBuffer = nullptr;
  std::unique_ptr<uint8_t> _pixelData = nullptr;
  int64_t _flutterTextureId;
  int _glTextureId;

  void* _viewer = nullptr;

  void CreateFilamentViewer(
  const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CreateTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  
  void Render(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall, 
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace polyvox_filament

#endif  // FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
