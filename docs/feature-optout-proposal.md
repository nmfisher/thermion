# Proposal: compile-time feature opt-outs for native libraries

| | |
| --- | --- |
| Status | **Proposal only.** No code, build or test changes are made by this document. |
| Branch | `feature-opt-libs` (branched from `origin/develop` at `9029ba90`) |
| Filament | v1.77.2 (`filament.version`) |
| Supersedes | The open ideas in `.tickets/the-0rkw.md` (optional libraries for binary size). This document uses the real link list and measured archive closures. |

## 1. Summary

Every native build of `thermion_dart` links one C++ wrapper
(`libthermion_dart`) against the same Filament archive set on every platform.
An app that only draws procedural geometry still compiles in the glTF loader,
its animation stack, Draco, the KTX/Basis texture decoders and the PNG/JPEG
decoder, because Thermion's own C++ references them. Removing a `-l` flag
alone does not change the binary: static archives only contribute the object
files that something references. The size is in the references.

This proposal adds three **opt-out** user defines (default: everything on, so
existing apps are unchanged):

```yaml
hooks:
  user_defines:
    thermion_dart:
      features:
        gltf: false            # no glTF loading, glTF animation, ubershader materials
        ktx: false             # no KTX1/KTX2/Basis textures
        image_decoding: false  # no PNG/JPEG decoding (stb)
```

For each one:

1. the hook stops passing the archives that only that feature needs, so a
   missed guard fails at **link time**, not at `dlopen`;
2. every Thermion translation unit that references those archives is guarded
   by a `THERMION_ENABLE_<FEATURE>` macro and falls back to the stub pattern
   already used by `TMaterialCompiler.cpp` (`runtime_materials`): the same C
   symbols are exported, they return null/0, so the Dart FFI bindings are
   byte-for-byte the same and `dlopen`/wasm load never sees a missing symbol;
3. a new `Thermion_getEnabledFeatures()` C function lets Dart report what the
   loaded build has (`FilamentApp.instance!.supports(ThermionFeature.gltf)`),
   and the affected Dart APIs throw `UnsupportedError` instead of returning
   garbage.

Of the eight libraries in scope:

| Library | Verdict | Marginal cost when referenced (Linux x64 release, see §7) |
| --- | --- | --- |
| `gltfio` (`gltfio_core`, `gltfio`, `uberarchive`) | **opt-out** (`features.gltf`) | ≈ 4.4 MB including everything it drags in (Draco, KTX/Basis, stb) |
| `stb` | **opt-out** (`features.image_decoding`) | ≈ 0.12 MB |
| `image` | **keep** (core data type `LinearImage`; 9 KB marginal) | ≈ 0.01 MB |
| `ktxreader` | **opt-out** (`features.ktx`) | ≈ 0.08 MB (+ `basis_transcoder` 1.4 MB) |
| `basis_transcoder` | **opt-out**, but only *through* `features.ktx` (no direct Thermion reference) | ≈ 1.4 MB |
| `draco` (`dracodec`) | **opt-out**, but only *through* `features.gltf` (no direct Thermion reference; gltfio's `AssetLoader` always calls it) | ≈ 1.0 MB |
| `filamat` (+ `matp`) | **already opt-in** (`runtime_materials`); two forced-link cases remain and are cost-free | ≈ 41 MB when `runtime_materials: true` |
| `filameshio` | **already gone** (#287); nothing links it, 0 bytes | 0 |

The headline saving for a procedural-only app (all three off) is roughly
**4.6 MB of object code** on Linux x64 (Filament's part only; Thermion's own
guarded wrappers add a little more, not measured). The per-feature numbers
overlap: dropping glTF alone also drops Draco and the glTF texture providers.

## 2. What is linked today

All of the following is forced by `thermion_dart/hook/build.dart` (native) or
`thermion_dart/native/web/CMakeLists.txt` (web) and does not depend on what the
app calls.

### 2.1 Native hook (`hook/build.dart`, the `libs` list, lines 316-395)

| Archive | Condition today | Needed by |
| --- | --- | --- |
| `filament`, `backend`, `utils`, `filabridge`, `filaflat`, `geometry`, `filament-iblprefilter` | always | core engine; `geometry` also by `TSurfaceOrientation` / `CustomGeometry` |
| `gltfio_core` | always | every glTF wrapper (§3.1) |
| `gltfio` (full archive) | `!android && !ios` | **nothing.** Thermion only uses `gltfio_core` symbols (`createUbershaderProvider`, never `createFilamentMaterialProvider`). Pulls 0 bytes today. |
| `uberarchive` | always | the ubershader material blob used by `TGltfAssetLoader.cpp` (`UBERARCHIVE_DEFAULT_DATA`) |
| `dracodec` | always | gltfio `AssetLoader` (Draco-compressed glTF meshes) |
| `ktxreader` | always | `TTexture.cpp` (`Ktx1Reader`, `Ktx2Reader`) and gltfio's `createKtx2Provider` |
| `basis_transcoder` | always | `ktxreader` (KTX2 with BasisLZ/ASTC payloads, KTX1 with Basis payload) |
| `stb` | always | `TTexture.cpp` `Image_decode` (`stbi_load_from_memory`) and gltfio's `createStbProvider` |
| `image` | always | `LinearImage` (public `createImage`/`setLinearImage`/`loadImage` APIs), `Ktx1Bundle`, ktxreader |
| `z`, `uberzlib` | always | ktxreader/gltfio inflate (system `z` is free; `uberzlib` is 3 KB when pulled) |
| `ibl` | always | **nothing** in Thermion sources (no `#include <ibl/...>`); pulls 0 bytes |
| `smol-v` | always | **core**: `filaflat::DictionaryReader` calls `smolv::Decode` for every material package (53 KB pulled even with no features); `filamat` only adds the encoder side |
| `zstd` | `!linux` | `filament::ZstdHelper` / `MaterialParser` (`ZSTD_*`) — core; on Linux the combined `libfilamat.a` is the provider |
| `matp`, `filamat`, `shaders` | `runtime_materials`, plus `filamat` in **debug** (matdbg `ShaderReplacer`) and on **Linux** (zstd provider) | `TMaterialCompiler.cpp` (guarded by `THERMION_ENABLE_RUNTIME_MATERIALS`); `TMaterialPackage.cpp` uses only the header constant `filamat::MaterialVersion` |
| `matdbg`, `fgviewer` | debug on macOS/Android (and Linux debug via `libraries`) | Filament debug builds only |
| `meshoptimizer`, `mikktspace` | Windows only (`#pragma comment(lib)` in `native/include/ThermionWin32.h`) | gltfio (meshopt extension, tangents) |

Platform extras (`bluegl`/`bluevk`, Android `GLESv3`/`EGL`/`perfetto`, Linux
`drm`/`EGL`/`GL`/`gbm`, `webgpu_dawn`/`abseil` for the WebGPU backend) are
core and unaffected by this proposal.

Windows differs in one way: `ThermionWin32.h` links `matp.lib` and
`filamat.lib` unconditionally (lines 14-15), regardless of `runtime_materials`.
As with every archive, this costs nothing unless referenced, but the pragma
should move under the same `THERMION_ENABLE_RUNTIME_MATERIALS` guard as the
glslang/SPIRV pragmas below it for consistency (§5.5).

### 2.2 Web (`native/web/CMakeLists.txt`, `target_link_libraries`, lines 365-407)

`gltfio_core filament backend geometry mikktspace dracodec ibl-lite ktxreader
filaflat filabridge image utils stb uberzlib uberarchive meshoptimizer
basis_transcoder basis_encoder z zstd png`, plus `matp filamat shaders smol_v`
under `THERMION_ENABLE_RUNTIME_MATERIALS`. The engine is published prebuilt in
a small set of variants (default, main-thread, runtime-materials, WebGPU), so
web users cannot opt out per app; §4.6 explains how the schema treats web.

### 2.3 What already works as a precedent

`runtime_materials` is the exact mechanism this proposal generalises:

- hook: `defines["THERMION_ENABLE_RUNTIME_MATERIALS"] = "1"` and conditional
  `libs` entries (`hook/build.dart` lines 236-240, 324-343);
- C: `TMaterialCompiler.cpp` compiles the real implementation under
  `#ifdef THERMION_ENABLE_RUNTIME_MATERIALS` and a complete stub set under
  `#else` (lines 665-740), so every `MaterialCompiler_*` symbol exists;
- Dart: `MaterialCompiler_isSupported()` backs `runtimeMaterialsSupported`,
  and `compileMaterialSource`/`compileMaterialPackage` throw
  `UnsupportedError` when it is 0 (`ffi_filament_app.dart` lines 707, 792);
- web: `option(THERMION_ENABLE_RUNTIME_MATERIALS)` selects a separate engine
  zip; the default engine dead-code-eliminates the unreferenced archive.

<!-- continued -->
