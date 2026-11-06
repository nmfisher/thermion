#include "rendering/EngineApiLock.hpp"
 

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
            TTexture *tColor,
            TTexture *tDepth)
        {
            THERMION_ENGINE_API_GUARD;
            if(!tColor || !tDepth) {
                ERROR("Color & depth attachments must be provided");
                return nullptr;
            }

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
            THERMION_ENGINE_API_GUARD;
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            engine->destroy(renderTarget);
        }
        


#ifdef __cplusplus
    }
}
#endif
