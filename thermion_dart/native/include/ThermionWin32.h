#pragma once

// Feature switches (gltf / ktx / image_decoding user defines) so the link
// list below only names archives the hook actually ships for this build; an
// unguarded reference is then a link error, not a missing DLL at runtime.
// THERMION_ENABLE_RUNTIME_MATERIALS stays a presence check (undefined when
// off), see ThermionFeatures.h and docs/feature-optout-proposal.md §4.4/§5.1.
#include "ThermionFeatures.h"

#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "filament.lib")
#pragma comment(lib, "bluevk.lib")
#pragma comment(lib, "bluegl.lib")
#pragma comment(lib, "backend.lib")
#if defined(THERMION_ENABLE_RUNTIME_MATERIALS)
// Runtime material compilation (opt-in via runtime_materials): matp is the
// .mat parser behind matc, filamat the compiler. On Windows, filamat's shader
// compiler dependencies are separate .lib files.
// Link them explicitly when runtime compilation is enabled; filamat.lib alone
// leaves unresolved references to shader compiler code and the generated shader
// data (SHADERS_PACKAGE) provided by shaders.lib.
#pragma comment(lib, "matp.lib")
#pragma comment(lib, "filamat.lib")
#pragma comment(lib, "shaders.lib")
#pragma comment(lib, "OSDependent.lib")
#pragma comment(lib, "glslang.lib")
#pragma comment(lib, "SPIRV.lib")
#pragma comment(lib, "SPIRV-Tools.lib")
#pragma comment(lib, "SPIRV-Tools-opt.lib")
#pragma comment(lib, "spirv-cross-core.lib")
#pragma comment(lib, "spirv-cross-glsl.lib")
#pragma comment(lib, "spirv-cross-msl.lib")
#endif
#pragma comment(lib, "geometry.lib")
#pragma comment(lib, "utils.lib")
#pragma comment(lib, "filabridge.lib")
// gltfio_core and the archives only it needs (Draco, uberzlib, the ubershader
// blob, meshopt/tangents) — linked only when glTF support is enabled.
#if THERMION_ENABLE_GLTF
#pragma comment(lib, "gltfio_core.lib")
#pragma comment(lib, "dracodec.lib")
#pragma comment(lib, "uberzlib.lib")
#pragma comment(lib, "uberarchive.lib")
#pragma comment(lib, "meshoptimizer.lib")
#pragma comment(lib, "mikktspace.lib")
#endif
#pragma comment(lib, "filament-iblprefilter.lib")
#pragma comment(lib, "image.lib")
#pragma comment(lib, "filaflat.lib")
#pragma comment(lib, "ibl.lib")
// KTX1/KTX2 (incl. Basis Universal) — linked only when KTX support is enabled.
#if THERMION_ENABLE_KTX
#pragma comment(lib, "ktxreader.lib")
#pragma comment(lib, "basis_transcoder.lib")
#endif
#pragma comment(lib, "z.lib")
// PNG/JPEG decoding (stb) — linked only when image decoding is enabled.
#if THERMION_ENABLE_IMAGE_DECODING
#pragma comment(lib, "stb.lib")
#endif
#pragma comment(lib, "smol-v.lib")
#pragma comment(lib, "zstd.lib")
#pragma comment(lib, "vulkan-1.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
 
