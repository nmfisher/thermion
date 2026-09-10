#pragma once
#include <functional>
#include "c_api/TRenderer.h"

namespace thermion {
// Called on the renderer's thread. Completion transfers the native pixel buffer
// to the consumer only after Filament has finished writing it.
void Renderer_readPixelsOwned(TRenderer*, uint32_t width, uint32_t height,
    uint32_t x, uint32_t y, TRenderTarget*, TPixelDataFormat, TPixelDataType,
    size_t length, std::function<void(uint8_t*)> onComplete);
}
