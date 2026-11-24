#include "ThermionFeatures.h"

#include "c_api/ThermionFeatures.h"

// The single probe Dart reads at initialization to back
// FilamentApp.supports(ThermionFeature). Keep in sync with the bit layout in
// c_api/ThermionFeatures.h and with the `features` keys resolved by
// hook/build.dart (lib/src/hooks/resolve_pubspec_features.dart). Runtime
// materials is a value macro like the others (ThermionFeatures.h defaults it
// to 0).
extern "C" EMSCRIPTEN_KEEPALIVE uint32_t Thermion_getEnabledFeatures() {
    uint32_t features = 0;
#if THERMION_ENABLE_GLTF
    features |= 1u << 0;
#endif
#if THERMION_ENABLE_KTX
    features |= 1u << 1;
#endif
#if THERMION_ENABLE_IMAGE_DECODING
    features |= 1u << 2;
#endif
#if THERMION_ENABLE_RUNTIME_MATERIALS
    features |= 1u << 3;
#endif
    return features;
}
