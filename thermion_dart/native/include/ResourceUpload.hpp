#pragma once
#include <vector>
#include "c_api/TGltfResourceLoader.h"

namespace thermion {
// Filament releases the owned bytes through its descriptor callback.
void GltfResourceLoader_addResourceDataOwned(TGltfResourceLoader*, const char* uri,
    std::vector<uint8_t>&& data);
}
