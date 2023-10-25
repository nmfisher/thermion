#ifndef _WGL_CONTEXT_H
#define _WGL_CONTEXT_H

#include <Windows.h>
#include "opengl_texture_buffer.h"
#include "flutter_render_context.h"
#if WGL_USE_BACKING_WINDOW
#include "backing_window.h"
#endif
namespace polyvox_filament {

    class WGLContext : public FlutterRenderContext {
    public:
        WGLContext(flutter::PluginRegistrarWindows* pluginRegistrar, flutter::TextureRegistrar* textureRegistrar);
        void* GetSharedContext();    
        void CreateRenderingSurface(
            uint32_t width, uint32_t height,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result, uint32_t left, uint32_t top);
        void ResizeRenderingSurface(
            uint32_t width, uint32_t height, uint32_t left, uint32_t top
        );
    private:

        flutter::PluginRegistrarWindows* _pluginRegistrar = nullptr;
        flutter::TextureRegistrar* _textureRegistrar = nullptr;
        HGLRC _context = NULL;
        #if WGL_USE_BACKING_WINDOW
        std::unique_ptr<BackingWindow> _backingWindow = nullptr;
        #endif
    };

}
#endif 