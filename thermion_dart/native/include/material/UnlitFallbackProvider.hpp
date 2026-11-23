#pragma once

#include "ThermionFeatures.h"

#if !THERMION_ENABLE_GLTF

#include <filament/Engine.h>
#include <filament/Material.h>

namespace thermion
{

    // Minimal stand-in for gltfio::MaterialProvider in builds without gltfio.
    //
    // GltfAssetLoader_create's stub allocates it with the engine pointer it
    // already receives, and GltfAssetLoader_getMaterialProvider returns the
    // same pointer, so Dart's existing provider handle is non-null in every
    // build. MaterialProvider_createMaterialInstance's stub then builds the
    // precompiled UNLIT_FALLBACK package from that engine on first use and
    // caches the Material, letting createUnlitMaterialInstance work through
    // the same context-free C entry point (no Engine parameter) in a slim
    // build (docs/feature-optout-proposal.md §10.1, deviation 3).
    struct UnlitFallbackProvider
    {
        filament::Engine *engine;
        filament::Material *unlitMaterial;
    };

} // namespace thermion

#endif // !THERMION_ENABLE_GLTF
