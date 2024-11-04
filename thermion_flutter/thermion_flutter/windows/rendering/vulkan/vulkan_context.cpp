#include <functional>
#include <iostream>
#include <vector>

#include "egl_context.h"

namespace thermion::windows::vulkan {

ThermionEGLContext::ThermionEGLContext() {
    
 

  // *******************
  // *                 *
  // *                 *
  // * EGL starts here *
  // *                 *
  // *                 *
  // *                 *
  // *******************
  EGLBoolean bindAPI = eglBindAPI(EGL_OPENGL_ES_API);
  if (!bindAPI) {
    std::cout << "eglBindAPI EGL_OPENGL_ES_API failed" << std::endl;
    return;
  }

  _eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (_eglDisplay == EGL_NO_DISPLAY) {
      std::cout << "eglBindAPI EGL_OPENGL_ES_API failed" << std::endl;
      return;
  }
 

  EGLint major, minor;
  EGLBoolean initialized = false;

  EGLDeviceEXT eglDevice;
  EGLint numDevices;

  if (auto *getPlatformDisplay =
          reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
              eglGetProcAddress("eglGetPlatformDisplayEXT"))) {

    EGLint kD3D11DisplayAttributes[] = {
        EGL_PLATFORM_ANGLE_TYPE_ANGLE,
        EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
        EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
        EGL_TRUE,
        EGL_NONE,
    };
    _eglDisplay = getPlatformDisplay(
        EGL_PLATFORM_ANGLE_ANGLE, EGL_DEFAULT_DISPLAY, kD3D11DisplayAttributes);
    initialized = eglInitialize(_eglDisplay, &major, &minor);
  }

  std::cout << "Got major " << major << " and minor " << minor << std::endl;

  if (!initialized) {
    std::cout << "eglInitialize failed" << std::endl;
    return;
  }

  // glext::importGLESExtensionsEntryPoints();

  EGLint configsCount;

  EGLint configAttribs[] = {EGL_RED_SIZE,     8, EGL_GREEN_SIZE, 8,
                            EGL_BLUE_SIZE,    8, EGL_DEPTH_SIZE, 24,
                            EGL_STENCIL_SIZE, 8, EGL_ALPHA_SIZE, 8,
                            EGL_NONE};

  EGLint contextAttribs[] = {
      EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE,
      EGL_NONE, // reserved for EGL_CONTEXT_OPENGL_NO_ERROR_KHR below
      EGL_NONE};

  // find an opaque config
  if (!eglChooseConfig(_eglDisplay, configAttribs, &_eglConfig, 1,
                       &configsCount)) {
    std::cout << "Failed to find EGL config" << std::endl;
    return;
  }

  auto ctx = eglCreateContext(_eglDisplay, _eglConfig, EGL_NO_CONTEXT,contextAttribs);
  _context = (void*)ctx;

  if (_context == EGL_NO_CONTEXT) {
    return;
  }
}

EGLTexture* ThermionEGLContext::CreateRenderingSurface(
    uint32_t width, uint32_t height,
    uint32_t left, uint32_t top
    ) {
  
  // glext::importGLESExtensionsEntryPoints();

  if(left != 0 || top != 0) {
    std::cout << "ERROR Rendering with EGL uses a Texture render target/Flutter widget and does not need a window offset." << std::endl;
    return nullptr;
  }

  //if (_active && _active.get()) {
  //  // result->Error("ERROR",
  //  //               "Texture already exists. You must call destroyTexture before "
  //  //               "attempting to create a new one.");
  //  return nullptr;
  //}

  _active = std::make_unique<EGLTexture>(
      width, height,
      _D3D11Device, _D3D11DeviceContext, _eglConfig, _eglDisplay, _context,
      [=](size_t width, size_t height) {
        std::cout << "RESIZE" << std::endl;
        std::vector<int64_t> list;
        list.push_back((int64_t)width);
        list.push_back((int64_t)height);
          // auto val = std::make_unique<flutter::EncodableValue>(list);
          // this->_channel->InvokeMethod("resize", std::move(val), nullptr);
      });

      return _active.get();
}

void* ThermionEGLContext::GetSharedContext() { 
  return (void*)_context;
}

void ThermionEGLContext::ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {

}

void ThermionEGLContext::DestroyRenderingSurface() {

}

EGLTexture *ThermionEGLContext::GetActiveTexture() { 
  return _active.get();
}


}

