#pragma once

#include <d3d.h>
#include <d3d11.h>
#include <memory>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <flutter_texture_registrar.h>

namespace thermion::tflutter::windows {

    class FlutterD3DTexture {
        public:
            FlutterD3DTexture(HANDLE d3dTexture2DHandle, uint32_t width, uint32_t height);
            ~FlutterD3DTexture();
            ::flutter::TextureVariant* GetFlutterTexture();
            HANDLE GetD3DTextureHandle();
            int64_t GetFlutterTextureId();
            void SetFlutterTextureId(int64_t textureId);
        private:
            uint32_t _width;
            uint32_t _height;
            std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> _textureDescriptor = nullptr;
            std::unique_ptr<::flutter::TextureVariant> _texture;
            int64_t _flutterTextureId = -1;    
            HANDLE _d3dTexture2DHandle;
    };
}

