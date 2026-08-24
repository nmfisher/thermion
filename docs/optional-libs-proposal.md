# Proposal: compile-time opt-in/out of optional native libraries

Status: **IMPLEMENTED on Linux** (2026-08-14, branch
`asb/optional-libs-proposal`). See §8 for measured results. Web edits are
in place but not build-verified (no emsdk in the sandbox).
Ticket: `the-0rkw`.

Goal: let consumers exclude native libraries they do not need, so binaries get
smaller. The named examples were libpng and libz. The short answer:

- **Image decoding is core, not optional.** The public Dart API
  `Texture.decodeToTexture()` ends in `stbi_load_from_memory()`
  (`TTexture.cpp:52`). Nearly every consumer loads PNG/JPEG textures, either
  directly or through glTF (`TGltfResourceLoader.cpp:45-49` registers the stb
  provider for `image/png` and `image/jpeg`). `stb`, `image`, and `ktxreader`
  are load-bearing. They cannot be compiled out.
- **"libpng is dead" does not mean "PNG support is dead".** PNG decoding goes
  through `stb_image`, which is self-contained. It does not use libpng. So we
  can drop libpng (where linked) without losing PNG support.
- **What is actually unused by the wrapper:** `imageio`, `tinyexr`, `libpng`,
  `z`, `filamat`, and `filameshio`. On Android, iOS, macOS, Windows, and web,
  dead-code elimination (DCE) removes most of them already. Expected gains
  there are small. `zstd` has no direct wrapper calls but is a required
  transitive dependency of four core archives, so it stays.
- **Linux was the exception.** The build hook wrapped *all* Filament archives
  in `--whole-archive` on Linux (`thermion_dart/hook/build.dart:407-411`). No
  DCE happened. Every linked archive was fully included. **Fixed — see §8:**
  the measured saving was 15.6 MB (-61%), far above the 1-3 MB estimated
  below, because the estimate predates discovering that `--whole-archive`
  was masking a flag-ordering bug (§8.2).

So the honest framing: image support stays; a short list of never-called
libraries can go. That is mostly a *Linux problem* plus a *hygiene problem*
(dead includes and dead link entries), not a cross-platform size emergency.

---

## 1. What is linked today, per platform

### Native-assets platforms (Android, iOS, Linux, macOS, Windows)

The link list lives in `thermion_dart/hook/build.dart:154-211`:

| Library | Linked | Notes |
|---|---|---|
| filament, backend, filabridge, utils, geometry, gltfio_core, gltfio (desktop), image, filaflat, ibl, ktxreader, stb, uberzlib, uberarchive, smol-v, basis_transcoder, dracodec, filament-iblprefilter | all platforms | core render path |
| filamat | all except iOS | runtime material compiler. iOS already ships without it — proof the core does not need it |
| filameshio | all | filamesh mesh loader |
| imageio, tinyexr | all | PNG/EXR decode+encode via imageio |
| z | all | zlib |
| zstd | all platforms (system library on Linux) | required transitively by filament, gltfio_core, uberzlib, and basis_transcoder |
| perfetto | Android | required by utils/Systrace |
| matdbg, fgviewer | debug desktop+Android | debug-only, by design |
| shaders | Linux | |

Windows links the same set through `#pragma comment(lib, ...)`
(`thermion_dart/native/include/ThermionWin32.h:10-38`).

**Linux special case:** `build.dart:407-411` puts every one of these between
`-Wl,--whole-archive` and `-Wl,--no-whole-archive`. Nothing is eliminated.
The comment in `thermion_flutter/thermion_flutter/linux/CMakeLists.txt:139-143`
shows the cost: whole-archive'd filamat drags basisu/draco *encoder* symbols
into the binary, which then need `--allow-shlib-undefined` to link at all.

### Web

`thermion_dart/native/web/CMakeLists.txt:303-328` links: gltfio_core,
filament, backend, geometry, mikktspace, dracodec, ibl-lite, ktxreader,
filaflat, filabridge, image, imageio, utils, stb, uberzlib, uberarchive,
meshoptimizer, basis_transcoder, **basis_encoder**, z, zstd, **png**, tinyexr.
(`filamat`, `filameshio`, `camutils` are imported as targets but *not* linked
— like iOS, web already ships without filamat.)

Emscripten does function-level DCE by default. Only `EXTERNAL_ALL_LIBRARIES`
(declarative plugins) get `--whole-archive`
(`web/CMakeLists.txt:330-339`). Unreferenced archive members cost nothing.
The question for web is empirical: measure before assuming.

---

## 2. What the wrapper actually uses (per-library verdicts)

Verified by grepping `thermion_dart/native/src` for includes, calls, and
template use. Every verdict below cites the evidence.

### Core — used by public APIs, must stay

| Library | Used where | Verdict |
|---|---|---|
| **stb** | `TTexture.cpp:26,42-52`: `Image_decode` calls `stbi_load_from_memory`. This is the back end of the public Dart API `Texture.decodeToTexture()` → `FilamentApp.decodeImage()` (`lib/src/filament/src/interface/texture.dart:504-514`, `ffi_filament_app.dart:548-551`). Also `TGltfResourceLoader.cpp:45,48-49`: gltfio stb provider for `image/png` + `image/jpeg` glTF textures | **core**. Nearly every consumer loads PNG/JPEG |
| **image** | `TTexture.cpp:15-16` (LinearImage, ColorTransform); `:62-77` every decode wraps the stb output in `toLinear`/`toLinearWithAlpha` + `sRGBToLinear`; `:104+` `image::Ktx1Bundle` | **core**. It is the return type of `Image_decode` |
| **ktxreader** | `TTexture.cpp:19-20,102-194`: `Ktx1Bundle_*`, `Ktx2Reader_createTexture`, `Ktx1Reader_createTexture`; render-thread variants in `ThermionDartRenderThreadApi.cpp:1897-1928`; gltfio ktx2 provider `TGltfResourceLoader.cpp:46-47` | **core** for any KTX1/KTX2 asset (incl. IBL/skybox textures) |
| **basis_transcoder** | no direct calls, but `ktxreader::Ktx2Reader` needs it for basis-supercompressed KTX2 | **core** (transitive, via ktxreader) |
| **uberzlib + uberarchive** | `TGltfAssetLoader.cpp:50`: `createUbershaderProvider` is the default material provider for glTF assets | **core** |
| **dracodec** | no direct wrapper references; referenced from inside gltfio_core for Draco-compressed glTF meshes | core by default; opt-out only for apps that know their assets have no Draco meshes |
| **filaflat, smol-v, ibl, filament-iblprefilter** | no direct wrapper references; filaflat/smol-v are referenced transitively by filament/gltfio | verify individually by removal, not by claim |

### Dead in the wrapper — candidates for removal or opt-out

| Library | Evidence | Verdict |
|---|---|---|
| **imageio** | only two includes in `TEngine.cpp:31-32`. Zero `ImageDecoder`/`ImageEncoder` calls anywhere. Screenshot PNG encoding happens on the **Dart side** (`lib/src/utils/src/image.dart:3,147`, the `image` package's `encodePng`) | **dead** |
| **tinyexr** | dependency of imageio only; no direct references | **dead** |
| **png (libpng)** | zero direct calls. PNG decode goes through self-contained stb, not libpng. The hook does not even link it (web does) | **dead** — and dropping it does *not* lose PNG support |
| **z (zlib)** | referenced only by libpng/tinyexr (both dead). stb does not need zlib. uberzlib is a separate self-contained amalgamation. **Verified by link:** no remaining archive references `inflate`/`deflate`/`zlibVersion` (`nm` over every linked `.a`), and the stripped Linux build resolves cleanly without `-lz` | **dead** on native. On web, `z` stays in the link list until a web build verifies its removal |
| **zstd** | ~~pulled only by filamat~~ **WRONG — found by build.** `nm` on the v1.75.0 archives: `filament` (5 refs), `gltfio_core` (4), `uberzlib` (5), and `basis_transcoder` (3) all reference `ZSTD_*`. Removing zstd left `ZSTD_decompress`/`ZSTD_getFrameContentSize`/`ZSTD_getErrorName`/`ZSTD_isError` unresolved | **core (transitive)**. Linux links the system `libzstd.so` (the artifact ships no `libzstd.a`); other platforms use the static `libzstd.a` from the artifact |
| **filamat** | zero `<filamat/...>` includes, zero calls. All materials are precompiled `.package` blobs built with `filament::Material::Builder().package(...)` (`TEngine.cpp:290`, `TMaterialInstance.cpp:57-115`) — that is the `filament` lib, not filamat. iOS and web already ship without it | **dead for core**; keep available for declarative plugins that compile materials at runtime |
| **filameshio** | zero references in wrapper source (only `native/test/macos`) | **dead** |
| **basis_encoder (web)** | linked in web CMakeLists but no wrapper references (encoding happens at build time elsewhere) | likely already DCE'd on web; drop from link list and measure |

---

## 3. Which libraries can be optional

**Core (keep always):** filament, backend, filabridge, utils, geometry,
gltfio(_core), image, stb, uberzlib, uberarchive, ktxreader,
basis_transcoder, dracodec (by default), filaflat, smol-v, perfetto
(Android), matdbg/fgviewer (debug).

**Dead today — candidates for deletion, not flags:**
imageio, tinyexr, libpng, filameshio. Nothing calls them. Removing them is a
bug fix, not a feature.

**Dead for core, needed by plugins:** filamat. External declarative plugins
may compile materials at runtime; that is why filamat was linked on non-iOS.
It is now unlinked; if such a plugin appears, re-add filamat for its build.
**zstd is NOT in this set** — see the corrected verdict in §2: four core
archives reference `ZSTD_*`, so zstd stays linked everywhere.

**Possible later opt-outs (real API impact, not proposed now):**
- dracodec — only needed for Draco-compressed glTF assets.
- ktxreader/basis_transcoder — only needed for KTX1/KTX2 textures. These are
  *public APIs* (`Ktx1Bundle_*`, `Ktx*Reader_createTexture`, plus the gltfio
  `image/ktx2` provider), so opting out means guarded stubs and a capability
  flag, not a quiet removal.
Both are referenced from *inside* gltfio_core / ktxreader, so opting out
needs the wrappers in our own C API to be guarded, and (for draco) possibly
a Filament rebuild — see §6 phase 4.

**z (zlib):** verify. If nothing references it after imageio/tinyexr go, it
is dead too. Note uberzlib is a self-contained zlib amalgamation, separate
from `z`.

---

## 4. Mechanism

### 4.1 Hook flags via `user_defines` (desktop, Android, iOS, Windows)

The mechanism already exists: `tracing`, `web_local`, `materials`, `plugins`
all flow through `input.userDefines` in `hook/build.dart` and are set in the
consumer's pubspec.yaml:

```yaml
hooks:
  user_defines:
    thermion_dart:
      image_io: false          # imageio, tinyexr, png, z
      runtime_materials: false # filamat
      filamesh: false
      draco: false             # later phase
```

Implementation: gate entries in the `libs` list (`build.dart:154-211`) and
pass matching `-DTHERMION_*` defines so the wrapper source can guard code.

### 4.2 Preprocessor guards in the wrapper

Wrap the feature entry points (e.g. `Ktx*Reader_*`,
`MaterialProvider_createMaterialInstance`) in
`#if defined(THERMION_ENABLE_...)`. Compiled-out functions must still exist
and return a clear error — a missing FFI symbol crashes the isolate, a
returned error does not. Example:

```cpp
#if THERMION_ENABLE_KTX
TTexture *Ktx2Reader_createTexture(...) { ... }
#else
TTexture *Ktx2Reader_createTexture(...) {
    Log("KTX support compiled out (THERMION_ENABLE_KTX=OFF)");
    return nullptr;
}
#endif
```

The two dead `imageio` includes in `TEngine.cpp:31-32` are deleted outright.
`Image_decode`, `LinearImage`, and the stb/image code paths are **not**
touched — they are core.

### 4.3 Web CMake options

Add options in `native/web/CMakeLists.txt`:

```cmake
option(THERMION_ENABLE_IMAGE_IO "Link imageio/png/tinyexr/z" OFF)
option(THERMION_ENABLE_BASIS_ENCODER "Link basis_encoder" OFF)
```

and gate the `add_library(... IMPORTED)` blocks and the
`target_link_libraries` entries. Thread them through the existing web build
path (`build_web.sh` / `make wasm`) as `-D` flags.

### 4.4 Dart capability query

Export one C function returning a bitmask of compiled-in features:

```cpp
EMSCRIPTEN_KEEPALIVE uint32_t Engine_getCapabilities() {
    return (THERMION_ENABLE_KTX ? CAP_KTX : 0) | ...;
}
```

Expose it through the FFI bindings and the JS interop bindings (both are
generated today — `make bindings`). Dart checks before use and throws a
descriptive error ("KTX support not compiled in; enable it with
hooks.user_defines.thermion_dart.ktx") instead of failing at the C boundary.

### 4.5 Plugins

`_processDeclarativePlugins` already merges plugin link libraries into
`libs`. Extend plugin config with a `requires:` list (e.g.
`requires: [runtime_materials]`). If a plugin declares a feature the
consumer disabled, fail the build with a clear message. This keeps the
opt-out safe.

---

## 5. Realistic size impact

Be honest: static linking with DCE only includes referenced symbols. On
Android, iOS, macOS, Windows, and web, the dead libs are mostly *already
gone*. Estimates below are per-architecture, release, stripped, for the code
that actually lands in the binary **when DCE cannot remove it** (Linux
whole-archive today; other platforms ≈ 0):

| Library | Est. size in binary | Basis |
|---|---|---|
| filamat | ~1-3 MB | contains the GLSL/material compiler subset; the Linux whole-archive link includes all of it plus its basisu/draco encoder references |
| zstd | ~0.2-0.5 MB | core transitive dependency; retained, but selective archive linking avoids unrelated members |
| tinyexr | ~0.15-0.3 MB | EXR decode paths |
| libpng | ~0.08-0.15 MB | decode paths |
| imageio | ~0.05-0.15 MB | thin wrapper |
| z (zlib) | ~0.07-0.1 MB | |
| filameshio | ~0.02-0.05 MB | small parser |
| basis_encoder (web) | ~0.4-1 MB | likely already DCE'd; measure |
| dracodec | ~0.2-0.4 MB | needs Filament rebuild to remove |

Expected outcomes:

- **Linux: ~1.5-4 MB smaller `libthermion_dart.so`** — the whole-archive
  link means every removal is a full win. This is the headline.
- **Web: likely 0-1 MB (gzipped less)** — DCE probably already removed the
  unreferenced archives. Measure with `wasm-opt --strip` + gzip before and
  after.
- **Android/iOS/macOS/Windows: likely near 0** for the dead libs; real gains
  only for draco/ktx in a later phase, and only for apps that know their
  assets.

Because of this, **step 1 of the plan is measurement**, not flag plumbing.

---

## 6. Risks

1. **Core image decoding must not regress.** `Image_decode` (stb + image)
   and the gltfio stb/ktx2 providers (`TGltfResourceLoader.cpp:45-49`) are
   on every asset-load path. The proposal does not touch them. Any change
   to the link list must keep `stb`, `image`, `ktxreader`,
   `basis_transcoder` linked everywhere.
2. **Plugins that need filamat.** Removing filamat by default can break
   declarative plugins that compile materials at runtime. Mitigation: the
   `requires:` mechanism (§4.5) and a release-note warning.
3. **Linux whole-archive exists for a reason.** Do not remove the flag
   itself without understanding why it was added (likely symbol
   interposition/callback ordering). Only shrink the lib list inside it.
4. **Windows link list is in a header.** `ThermionWin32.h` pragmas must
   stay in sync with the flags, or LINK fails. Gate the pragmas with the
   same defines.
5. **Test impact.** `native/test/linux/CMakeLists.txt:67,77-78` and
   `native/test/macos/CMakeLists.txt:101-102,109-110` link
   filamat/imageio/tinyexr/filameshio. Tests keep the full (all-features)
   configuration; flags default matters: if flags default to OFF, CI must
   build a "minimal" matrix entry to keep it honest.
6. **Version drift.** The R2 artifacts stay complete; flags only change
   link selection. No new artifact variants are needed for the hook
   platforms. Web ships its own lib dir, so its CMake option needs no
   artifact change either.
7. **zlib removal may surprise.** Some Filament archive member added in a
   future version could reference `z` again. Keep `z` in the list but let
   DCE handle it (it is only a real cost on Linux whole-archive; decide
   after measurement).

---

## 7. Recommended plan (ordered)

1. **Measure.** Build release for each platform. Record
   `.so`/`.dll`/`.framework`/`.wasm` sizes. On Linux run the link with
   `-Wl,-Map` (or `bloaty`) and attribute bytes per input archive; on web
   compare `.wasm` gzip size. This produces the real table for §5. No code
   change.
2. **Dead-code hygiene (small PR, low risk).** Delete the two unused
   `imageio` includes (`TEngine.cpp:31-32`). Remove `imageio`, `tinyexr`,
   `filameshio` from `hook/build.dart` `libs`, from the Windows pragmas,
   and from the web link list. Keep `z`/`zstd` decisions pending step 1
   data. Expect the Linux win here. Re-run tests.
3. **Flags + capability query.** Add `image_io`, `runtime_materials`,
   `filamesh`, and (later) `ktx`/`draco` user_defines; preprocessor guards
   with error-returning stubs; `Engine_getCapabilities`; regenerate
   bindings (`make bindings`); plugin `requires:` list; document in
   `thermion_dart/README.md` next to the existing `user_defines` examples.
   Default: everything ON at first, so no consumer breaks. Let consumers
   opt out. After a deprecation window, flip dead-code defaults to OFF.
4. **(Later, larger) draco/ktx compile-out in Filament.** dracodec is
   referenced from inside gltfio_core, so removing it fully means a Filament
   rebuild with draco disabled (patch or upstream CMake option) in
   `scripts/build_android.sh` / `build_ios.sh` / `build_linux.sh` /
   `build_macos.sh`. ktxreader is our own wrapper API plus the gltfio
   provider, so it needs guarded stubs and a capability flag. Only do this
   if step 1 shows meaningful sizes and users ask for it.
5. **CI size report.** Print binary sizes per platform per PR, so future
   additions show their cost immediately.

---

## 8. Implementation results (2026-08-14, branch asb/optional-libs-proposal)

### What changed

1. `thermion_dart/hook/build.dart`: removed `imageio`, `tinyexr`, `z`,
   `filamat`, `filameshio` from the link list; `zstd` stays (corrected
   verdict, see §2). The two dead `imageio` includes were deleted from
   `TEngine.cpp`.
2. **The `--whole-archive` on Linux was the real cause of the bloat, and it
   was masking a flag-ordering bug.** `native_toolchain_c` emits
   `CBuilder.flags` *before* the source files on the link command, but emits
   the `libraries:` argument *after* the output file. The old hook passed
   `-l<lib>` through `flags`, so every archive was searched **before any
   object existed** — selective extraction could never pull anything, and
   `--whole-archive` was the only way to make that link work (it includes
   every member unconditionally, position irrelevant). The fix passes the
   libraries via CBuilder's `libraries:` argument (correct position) and
   lists them twice to handle the circular references between Filament
   archives (poor man's `--start-group`). `--whole-archive` is gone.
3. `ThermionWin32.h`: removed the `filamat`, `imageio`, `tinyexr`, and `z`
   pragmas. The `zstd` pragma stays because core archives require it. Windows
   links only via these pragmas; the edits are not build-verified because the
   sandbox had no Windows toolchain.
4. `native/web/CMakeLists.txt`: removed `imageio`, `tinyexr`, `png` link
   entries and the unused `filamat`/`filameshio` imported targets. `z` and
   `basis_encoder` stay pending a web build. Not build-verified (no emsdk
   in the sandbox).
5. `thermion_flutter/linux/CMakeLists.txt`: dropped the
   `--allow-shlib-undefined` workaround. Its cause (unresolved basisu/draco
   encoder symbols from whole-archive'd filamat) is gone; `ldd -r` now
   reports zero unresolved symbols, and the example app links without it.

### Measured size (Linux arm64, release, quickstart example)

| | bytes | vs baseline |
|---|---|---|
| baseline (whole-archive, full lib list) | 25,679,848 | — |
| stripped list + `libraries:` placement | **10,051,304** | **-61%** |

Intermediate data point: stripping the lib list while keeping the flags in
the old position produced a 2,231,536-byte `.so` that *looked* fine but had
silently-unresolved `cgltf_*` symbols (shared libraries allow undefined
symbols at link time). `ldd -r` catches this class of bug — always run it
after touching this link.

### Verification

- `flutter analyze`: 0 errors.
- Clean `flutter build linux --release`: links, with and without the
  `--allow-shlib-undefined` workaround removed.
- `ldd -r libthermion_dart.so`: **0 undefined symbols** after relocation.
- `nm` audit: 0 references to `png_*`, `inflate`/`deflate`, `imageio`,
  `filamesh`, `cgltf_*` (cgltf now defined inside the `.so`).
- Runtime: quickstart app runs under `xvfb` for 45 s+ without crash;
  `libthermion_dart.so` is mapped in every app process; the app loads
  `cube.glb` (exercises gltfio/cgltf) and KTX skybox/IBL (exercises
  ktxreader/basis).
- Core APIs still exported: `Image_decode`, `Ktx2Reader_createTexture`,
  `Engine_buildMaterial` (stb/image/ktxreader untouched).

### Per-library outcome

| Library | Outcome | Why |
|---|---|---|
| imageio | **stripped** (all platforms incl. web link list) | dead includes removed; no references |
| tinyexr | **stripped** | imageio dependency only |
| png (libpng) | **stripped** (web link list) | PNG decode is stb, self-contained |
| z (zlib) | **stripped** (hook) | verified: no linked archive references zlib symbols; Linux artifact never shipped libz.a/libpng.a anyway |
| filamat | **stripped** (hook + web target + Windows pragma) | precompiled materials only; iOS and web already shipped without it |
| filameshio | **stripped** | zero references |
| zstd | **REVERTED (kept everywhere)** | build evidence: filament/gltfio_core/uberzlib/basis_transcoder reference `ZSTD_*`. Linux uses system `libzstd.so`; other platforms retain the artifact's static library |
| basis_transcoder, dracodec, filaflat, smol-v, ibl, filament-iblprefilter | **kept** | per ticket instructions; filaflat/smol-v are transitively required by filament/gltfio and link-verified |

### Issues found during the original validation

- Linux debug builds initially exposed the missing `bluevk/BlueVK.h` artifact
  issue. That was independent of this work and has since been handled by
  `the-c8d3` on `develop`.
- `examples/dart/cli_headless` no longer compiles against the current Dart
  API (`ThermionViewerFFI` signature changed). Pre-existing example rot.

### Not verified in this sandbox

- Windows (no toolchain): pragma edits are evidence-based but unbuilt.
- Web (no emsdk): link-list edits applied; `z`/`basis_encoder` removal
  deferred until a web build can confirm.
- Android/iOS/macOS: not buildable here; the hook change (lib list +
  `libraries:` placement) applies to them too. `matdbg`/`fgviewer` (debug
  desktop+Android) and `perfetto` (Android) are still linked as before.
  The `libraries:`-position change should be neutral (better) for them,
  but a CI build should confirm.
