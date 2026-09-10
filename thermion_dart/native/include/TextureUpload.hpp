#pragma once
#include <vector>
#include "c_api/TTexture.h"

namespace thermion {
// Filament releases the owned bytes through its descriptor callback.
bool Texture_setImageOwned(TEngine*, TTexture*, uint32_t level,
    std::vector<uint8_t>&& data, uint32_t x, uint32_t y, uint32_t z,
    uint32_t width, uint32_t height, uint32_t depth, uint32_t format, uint32_t type);
}
