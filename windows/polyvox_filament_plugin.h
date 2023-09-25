#ifndef FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <chrono>
#include <memory>


#include "GL/GL.h"
#include "GL/GLu.h"

#include "PolyvoxFilamentApi.h"

namespace polyvox_filament {

class PolyvoxFilamentPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PolyvoxFilamentPlugin(flutter::TextureRegistrar *textureRegistrar,
                        flutter::PluginRegistrarWindows *registrar);
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

  std::unique_ptr<flutter::TextureVariant> _texture = nullptr;
  std::unique_ptr<FlutterDesktopPixelBuffer> _pixelBuffer = nullptr;
  std::unique_ptr<uint8_t> _pixelData = nullptr;
  std::chrono::milliseconds _frameInterval;
  bool _rendering = false;
  int64_t _flutterTextureId;
  GLuint _glTextureId = 0;
  HGLRC _context = NULL;

  void *_viewer = nullptr;

  std::map<uint32_t, ResourceBuffer> _resources;

  void CreateFilamentViewer(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Render(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetRendering(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetBackgroundImage(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetBackgroundColor(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void UpdateViewportAndCameraProjection(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GetAssetManager(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void LoadSkybox(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void LoadIbl(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void RemoveSkybox(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void RemoveIbl(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void AddLight(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void LoadGlb(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void RotateStart(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RotateEnd(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RotateUpdate(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void PanStart(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void PanUpdate(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void PanEnd(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetPosition(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetRotation(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GetAnimationNames(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void RemoveAsset(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void TransformToUnitCube(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GrabBegin(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GrabEnd(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GrabUpdate(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void ScrollBegin(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void ScrollEnd(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void ScrollUpdate(const flutter::MethodCall<flutter::EncodableValue> &methodCall,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  ResourceBuffer loadResource(const char *path);
  void freeResource(ResourceBuffer rbuf);
};

} // namespace polyvox_filament

#endif // FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
