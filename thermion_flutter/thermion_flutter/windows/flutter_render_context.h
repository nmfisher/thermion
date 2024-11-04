#ifndef _FLUTTER_RENDER_CONTEXT_H
#define _FLUTTER_RENDER_CONTEXT_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include "flutter_texture_buffer.h"

namespace thermion_flutter {

    class FlutterRenderContext {
    public:

        void CreateRenderingSurface(uint32_t width, uint32_t height, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result, uint32_t left, uint32_t top);

        void DestroyRenderingSurface(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        
        int64_t GetFlutterTextureId() {
            if(!_active) {
                return -1;
            }
            return _active->flutterTextureId;
        }

        void *GetSharedContext();
       
    protected:
        FlutterRenderContext( flutter::PluginRegistrarWindows* pluginRegistrar, flutter::TextureRegistrar* textureRegistrar) : _pluginRegistrar(pluginRegistrar), _textureRegistrar(textureRegistrar) {};

        flutter::PluginRegistrarWindows* _pluginRegistrar;
        flutter::TextureRegistrar* _textureRegistrar;
        std::unique_ptr<FlutterTextureBuffer> _active = nullptr;
        std::unique_ptr<FlutterTextureBuffer> _inactive = nullptr;
    };
}

#endif