#pragma once

// Compile-time feature switches for the native library
// (docs/feature-optout-proposal.md §5.1).
//
// The build hook (hook/build.dart, `features` user define) passes
// -DTHERMION_ENABLE_<FEATURE>=0 only for DISABLED features. Enabled features
// and default builds pass nothing, so their compile command lines are
// unchanged. Every switch is a value macro so each guarded translation unit
// sees the same value, and a typo in an `#if` fails loudly under -Wundef
// instead of silently disabling a feature. The three opt-out switches default
// to 1; THERMION_ENABLE_RUNTIME_MATERIALS is opt-in and defaults to 0 (below).
//
// What a switch gates when it is 0:
//   THERMION_ENABLE_GLTF           gltfio_core/uberarchive/dracodec/uberzlib:
//                                  glTF loading, glTF animation, the
//                                  ubershader material provider and the
//                                  glTF-only SceneAsset entry points.
//   THERMION_ENABLE_KTX            ktxreader/basis_transcoder: KTX1/KTX2
//                                  textures (Ktx1Bundle, Ktx1Reader,
//                                  Ktx2Reader entry points).
//   THERMION_ENABLE_IMAGE_DECODING stb: PNG/JPEG/... decoding (Image_decode).
//
// The C export set never changes: every guarded entry point compiles to a
// stub (null / 0 / no-op) so the Dart FFI bindings, dlopen and the wasm
// module stay valid in every variant. Thermion_getEnabledFeatures() reports
// the switches to Dart at runtime.
#ifndef THERMION_ENABLE_GLTF
#define THERMION_ENABLE_GLTF 1
#endif

#ifndef THERMION_ENABLE_KTX
#define THERMION_ENABLE_KTX 1
#endif

#ifndef THERMION_ENABLE_IMAGE_DECODING
#define THERMION_ENABLE_IMAGE_DECODING 1
#endif

// Runtime material compilation is opt-in and off by default. It uses the
// same value-macro convention as the three switches above: the header
// defaults it to 0 and hook/build.dart passes -DTHERMION_ENABLE_RUNTIME_MATERIALS=1
// only when `runtime_materials: true`. This is the atomic migration allowed
// by proposal §5.1 (decision D3): every guard — TMaterialCompiler.cpp,
// TThermionFeatures.cpp and the web CMake options — is a value check now, so
// a macro defined to 0 selects the stub instead of the real compiler.
#ifndef THERMION_ENABLE_RUNTIME_MATERIALS
#define THERMION_ENABLE_RUNTIME_MATERIALS 0
#endif
