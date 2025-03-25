#include "c_api/TScene.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/RenderTarget.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE TRenderTarget *RenderTarget_create(
            TEngine *tEngine,
            uint32_t width,
            uint32_t height,
            TTexture *tColor,
            TTexture *tDepth)
        {
            if(!tColor || !tDepth) {
                ERROR("Color & depth attachments must be provided");
                return nullptr;
            }
            TRACE("Creating render target %dx%d", width, height);
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto color = reinterpret_cast<filament::Texture *>(tColor);
            auto depth = reinterpret_cast<filament::Texture *>(tDepth);
            
            auto rt = filament::RenderTarget::Builder()
                        .texture(RenderTarget::AttachmentPoint::COLOR, color)
                        .texture(RenderTarget::AttachmentPoint::DEPTH, depth)
                        .build(*engine);
            return reinterpret_cast<TRenderTarget *>(rt);
        }

        EMSCRIPTEN_KEEPALIVE void RenderTarget_destroy(
            TEngine *tEngine,
            TRenderTarget *tRenderTarget
        ) {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            engine->destroy(renderTarget);
        }
        


#ifdef __cplusplus
    }
}
#endif
