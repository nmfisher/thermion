#pragma once

#include <functional>
#include <mutex>

#include <d3d.h>
#include <d3d11.h>

#include "EGL/egl.h"
#include "EGL/eglext.h"
#include "EGL/eglplatform.h"
#include "GLES2/gl2.h"
#include "GLES2/gl2ext.h"
#include <GLES3/gl31.h>

#include <Windows.h>
#include <wrl.h>

typedef uint32_t GLuint;

namespace thermion::windows::egl {

class EGLTexture {
  public:
    EGLTexture(
        uint32_t width,
        uint32_t height,
        ID3D11Device* D3D11Device,
        ID3D11DeviceContext* D3D11DeviceContext,
        EGLConfig eglConfig,
        EGLDisplay eglDisplay,
        EGLContext eglContext,
        std::function<void(size_t, size_t)> onResizeRequested
    );    
    ~EGLTexture();

    void RenderCallback();
   
    GLuint glTextureId = 0;
      
  private:
    bool _error = false;
    uint32_t _width = 0;
    uint32_t _height = 0;
    bool logged = false;
    std::function<void(size_t, size_t)> _onResizeRequested;

    // Device
    ID3D11Device* _D3D11Device = nullptr;
    ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
    // Texture objects/shared handles
    Microsoft::WRL::ComPtr<ID3D11Texture2D> _d3dTexture2D;
    HANDLE _d3dTexture2DHandle = nullptr;

    EGLDisplay _eglDisplay = EGL_NO_DISPLAY;
    EGLContext _eglContext = EGL_NO_CONTEXT;
    EGLConfig _eglConfig = EGL_NO_CONFIG_KHR;
    EGLSurface _eglSurface = EGL_NO_SURFACE;
    
    // std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> _textureDescriptor = nullptr;

};

}
