#pragma once

#include <memory>
#include <Windows.h>

#include "egl_texture.h"

namespace thermion::windows::egl {

class FlutterEGLContext {
public:
  FlutterEGLContext();
  void* GetSharedContext();    
  void RenderCallback();
  void CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);

private:
  void* _context = nullptr;
  EGLConfig _eglConfig = NULL;
  EGLDisplay _eglDisplay = NULL;
  ID3D11Device* _D3D11Device = nullptr;
  ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
  std::unique_ptr<EGLTexture> _active;
};

}
