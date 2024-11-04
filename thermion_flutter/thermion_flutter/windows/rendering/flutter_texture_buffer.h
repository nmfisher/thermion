#ifndef _FLUTTER_TEXTURE_BUFFER_H
#define _FLUTTER_TEXTURE_BUFFER_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

namespace thermion_flutter {

    class FlutterTextureBuffer {
        public:
            flutter::TextureVariant GetTexture() {
                return texture->get();
            }
            void RegisterFlutterTextureId(int64_t flutterTextureId);
            int64_t GetFlutterTextureId();
        private:
            int64_t flutterTextureId = -1;
            std::unique_ptr<flutter::TextureVariant> texture;

    };
}

#endif