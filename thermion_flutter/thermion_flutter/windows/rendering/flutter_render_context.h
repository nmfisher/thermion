#pragma once

#include "flutter_texture_buffer.h"

namespace thermion_flutter {

    class FlutterRenderContext {
        public:
            void CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
            void DestroyRenderingSurface();
            void *GetSharedContext();
            FlutterTextureBuffer GetActiveTexture() {
                return _active->get();
            }
        
        protected:
            FlutterRenderContext();
            std::unique_ptr<FlutterTextureBuffer> _active = nullptr;
            std::unique_ptr<FlutterTextureBuffer> _inactive = nullptr;
    };
}

#endif