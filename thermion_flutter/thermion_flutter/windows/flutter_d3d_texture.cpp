#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <flutter_texture_registrar.h>

#include "flutter_d3d_texture.h"

namespace thermion::tflutter::windows
{

  FlutterD3DTexture::FlutterD3DTexture(HANDLE d3dTexture2DHandle, uint32_t width, uint32_t height) : _width(width), _height(height)
  {
    _textureDescriptor = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
    _textureDescriptor->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    _textureDescriptor->handle = d3dTexture2DHandle;
    _textureDescriptor->width = _textureDescriptor->visible_width = width;
    _textureDescriptor->height = _textureDescriptor->visible_height = height;
    _textureDescriptor->release_context = nullptr;
    _textureDescriptor->release_callback = [](void *release_context) {

    };
    _textureDescriptor->format = kFlutterDesktopPixelFormatBGRA8888;

    _texture =
        std::make_unique<::flutter::TextureVariant>(::flutter::GpuSurfaceTexture::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
            [&](size_t width, size_t height)
            {
              // if(width != this->_width || height != this->_height) {
              //   std::cout << "SI"
              //   return (FlutterDesktopGpuSurfaceDescriptor*)nullptr;
              // }
              return _textureDescriptor.get();
            }));
  }

  FlutterD3DTexture::~FlutterD3DTexture() {

  }
  
  ::flutter::TextureVariant* FlutterD3DTexture::GetFlutterTexture() {
      return _texture.get();
  }

  HANDLE FlutterD3DTexture::GetD3DTextureHandle() { 
    return _textureDescriptor->handle;
  }

  void FlutterD3DTexture::SetFlutterTextureId(int64_t textureId) {
    _flutterTextureId = textureId;
  }

  int64_t FlutterD3DTexture::GetFlutterTextureId()
  {
    return _flutterTextureId;
  }

}
