#ifndef _FLUTTER_RENDER_CONTEXT_H
#define _FLUTTER_RENDER_CONTEXT_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include "flutter_texture_buffer.h"

namespace polyvox_filament {

    class FlutterRenderContext {
    public:
        void CreateRenderingSurface(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result, uint32_t left, uint32_t top );

        void DestroyTexture(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            if (!_active) {
                result->Success("Texture has already been detroyed, ignoring");
                return;
            }

            auto sh = std::make_shared<
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
                    std::move(result));

            _textureRegistrar->UnregisterTexture(
                _active->flutterTextureId, [=, sharedResult = std::move(sh)]() {
                    this->_inactive = std::move(this->_active);
                    auto unique = std::move(*(sharedResult.get()));
                    unique->Success(flutter::EncodableValue(true));
                    std::cout << "Unregistered/destroyed texture." << std::endl;
                });
        }
        int64_t GetFlutterTextureId() {
            return _active->flutterTextureId;
        }
        void* sharedContext = nullptr;
        
    protected:
        flutter::PluginRegistrarWindows* _pluginRegistrar;
        flutter::TextureRegistrar* _textureRegistrar;
        std::unique_ptr<FlutterTextureBuffer> _active = nullptr;
        std::unique_ptr<FlutterTextureBuffer> _inactive = nullptr;
    };
}

#endif