#pragma once

#ifndef _FLUTTER_ANGLE_TEXTURE_H 
#define _FLUTTER_ANGLE_TEXTURE_H

#include <mutex>

#include <flutter/texture_registrar.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

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

#include "flutter_texture_buffer.h"

typedef uint32_t GLuint;

namespace thermion_filament {

class FlutterAngleTexture : public FlutterTextureBuffer {
  public:
    FlutterAngleTexture(
        flutter::PluginRegistrarWindows* pluginRegistrar,
        flutter::TextureRegistrar* textureRegistrar,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
        uint32_t width,
        uint32_t height,
        ID3D11Device* D3D11Device,
        ID3D11DeviceContext* D3D11DeviceContext,
        EGLConfig eglConfig,
        EGLDisplay eglDisplay,
        EGLContext eglContext,
        std::function<void(size_t, size_t)> onResizeRequested
    );    
    ~FlutterAngleTexture();

    void RenderCallback();
    
    GLuint glTextureId = 0;
    std::unique_ptr<flutter::TextureVariant> texture;
      
  private:
    flutter::PluginRegistrarWindows* _pluginRegistrar;
    flutter::TextureRegistrar* _textureRegistrar;
    uint32_t _width = 0;
    uint32_t _height = 0;
    bool logged = false;
    std::function<void(size_t, size_t)> _onResizeRequested;

    // Device
    ID3D11Device* _D3D11Device = nullptr;
    ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
    // Texture objects/shared handles
    Microsoft::WRL::ComPtr<ID3D11Texture2D> _externalD3DTexture2D;
    Microsoft::WRL::ComPtr<ID3D11Texture2D> _internalD3DTexture2D;
    HANDLE _externalD3DTextureHandle = nullptr;
    HANDLE _internalD3DTextureHandle = nullptr;

    EGLDisplay _eglDisplay = EGL_NO_DISPLAY;
    EGLContext _eglContext = EGL_NO_CONTEXT;
    EGLConfig _eglConfig = EGL_NO_CONFIG_KHR;
    EGLSurface _eglSurface = EGL_NO_SURFACE;
    
    std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> _textureDescriptor = nullptr;

};

}
#endif // _FLUTTER_ANGLE_TEXTURE 