#pragma once

#include <memory>
#include <mutex>

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

            // The registrar that registered this texture. Texture records are
            // process-global while registrars are per-engine, and Flutter texture
            // IDs are pointer-derived and therefore recyclable — so an ID alone
            // does not identify a texture. Lookups must match owner AND ID.
            ::flutter::TextureRegistrar* GetOwner();
            void SetOwner(::flutter::TextureRegistrar* owner);

            // Atomically swap the underlying D3D shared handle.
            // Flutter's GpuSurfaceTexture callback returns the descriptor
            // pointer each frame; after this call it will see the new handle.
            void SwapDescriptor(HANDLE newHandle, uint32_t width, uint32_t height);
        private:
            uint32_t _width;
            uint32_t _height;
            std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> _textureDescriptor = nullptr;
            std::unique_ptr<::flutter::TextureVariant> _texture;
            int64_t _flutterTextureId = -1;
            ::flutter::TextureRegistrar* _owner = nullptr;
            HANDLE _d3dTexture2DHandle;
            std::mutex _descriptorMutex;
    };
}

