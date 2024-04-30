#ifndef _EGL_CONTEXT_H
#define _EGL_CONTEXT_H

#include <Windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include "flutter_angle_texture.h"
#include "backend/platforms/PlatformEGL.h"
#include "flutter_render_context.h"

namespace flutter_filament {

class FlutterEGLContext : public FlutterRenderContext {
public:
  FlutterEGLContext(flutter::PluginRegistrarWindows* pluginRegistrar, flutter::TextureRegistrar* textureRegistrar);
  void* GetSharedContext();    
  void RenderCallback();
  void* GetPlatform();
  void CreateRenderingSurface(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result, uint32_t left, uint32_t top );

private:
  void* _context = nullptr;
  EGLConfig _eglConfig = NULL;
  EGLDisplay _eglDisplay = NULL;
  ID3D11Device* _D3D11Device = nullptr;
  ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
  filament::backend::Platform* _platform = nullptr;
};

}

#endif