#ifndef FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <chrono>
#include <memory>
#include <mutex>

#include <Windows.h>
#include <wrl.h>

#ifdef USE_ANGLE
#include <d3d.h>
#include <d3d11.h>
#endif

#include "GL/GL.h"
#include "GL/GLu.h"

#ifdef USE_ANGLE
#include "EGL/egl.h"
#include "EGL/eglext.h"
#include "EGL/eglplatform.h"
#include "GLES2/gl2.h"
#include "GLES2/gl2ext.h"
#include "PlatformAngle.h"
#endif 

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

  std::map<uint32_t, ResourceBuffer> _resources;

  std::unique_ptr<flutter::TextureVariant> _texture = nullptr;

  std::unique_ptr<FlutterDesktopPixelBuffer> _pixelBuffer = nullptr;
  std::unique_ptr<uint8_t> _pixelData = nullptr;

  std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> _textureDescriptor = nullptr;

  int64_t _flutterTextureId;

  #ifdef USE_ANGLE
  // Device
  ID3D11Device* _D3D11Device = nullptr;
  ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
  // Texture objects/shared handles
  Microsoft::WRL::ComPtr<ID3D11Texture2D> _externalD3DTexture2D;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> _internalD3DTexture2D;
  HANDLE _externalD3DTextureHandle = nullptr;
  HANDLE _internalD3DTextureHandle = nullptr;
  filament::backend::PlatformANGLE* _platform = nullptr;

  bool MakeD3DTexture(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  #else
  // OpenGL
  HGLRC _context = NULL;
  GLuint _glTextureId = 0;
  std::mutex _renderMutex;

  bool MakeOpenGLTexture(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  #endif

  void CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void RenderCallback();

  ResourceBuffer loadResource(const char *path);
  void freeResource(ResourceBuffer rbuf);
};

} // namespace polyvox_filament

#endif // FLUTTER_PLUGIN_POLYVOX_FILAMENT_PLUGIN_H_
