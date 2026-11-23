#pragma once

// Compile-time feature switches for the native library
// (docs/feature-optout-proposal.md §5.1).
//
// The build hook (hook/build.dart, `features` user define) passes
// -DTHERMION_ENABLE_<FEATURE>=0 only for DISABLED features. Enabled features
// and default builds pass nothing, so their compile command lines are
// unchanged. Every switch is a value macro with a header default of 1 so that
// each guarded translation unit (and ThermionWin32.h) sees the same value,
// and a typo in an `#if` fails loudly under -Wundef instead of silently
// disabling a feature.
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

// THERMION_ENABLE_RUNTIME_MATERIALS is deliberately NOT defaulted here. It
// keeps its existing presence semantics: defined (=1) when runtime_materials
// is enabled, UNDEFINED when off. Its guards are `#ifdef` /
// `#if defined(...)` checks (TMaterialCompiler.cpp, ThermionWin32.h), so
// defining it to 0 would still select the real compiler. Migrating those to
// value checks is only allowed as one atomic change covering every guard.
