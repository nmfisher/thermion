# Proposal: compile-time opt-in/opt-out of optional native libraries

Status: draft (proposal only, no code changes).
Ticket: `the-0rkw`.

Goal: let consumers exclude native libraries they do not need, so binaries get
smaller. The named examples were libpng and libz. The short answer:

- **Most of the "optional" libraries are already dead in the link.** The
  wrapper source never calls into `imageio`, `tinyexr`, `libpng`, `filamat`,
  or `filameshio`. On Android, iOS, macOS, Windows, and web, dead-code
  elimination (DCE) removes most of them already. Expected gains there are
  small.
- **Linux is the exception.** The build hook wraps *all* Filament archives in
  `--whole-archive` on Linux (`thermion_dart/hook/build.dart:407-411`). No
  DCE happens. Every linked archive is fully included. This is where a real
  win waits: roughly 1-3 MB or more per build.

So the honest framing: this is mostly a *Linux problem* plus a *hygiene
problem* (dead includes and dead link entries), not a cross-platform size
emergency.

---

## 1. What is linked today, per platform

### Native-assets platforms (Android, iOS, Linux, macOS, Windows)

The link list lives in `thermion_dart/hook/build.dart:154-211`:

| Library | Linked | Notes |
|---|---|---|
| filament, backend, filabridge, utils, geometry, gltfio_core, gltfio (desktop), image, filaflat, ibl, ktxreader, stb, uberzlib, uberarchive, smol-v, basis_transcoder, dracodec, filament-iblprefilter | all platforms | core render path |
| filamat | all except iOS | runtime material compiler |
| filameshio | all | filamesh mesh loader |
| imageio, tinyexr | all | PNG/EXR decode+encode |
| z | all | zlib |
| zstd | all except Linux | pulled by filamat (1.75.0 refs `ZSTD_*`) |
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
(`filamat`, `filameshio`, `camutils` are imported but *not* linked — web
already ships without filamat, which proves the core does not need it.)

Emscripten does function-level DCE by default. Only `EXTERNAL_ALL_LIBRARIES`
(declarative plugins) get `--whole-archive`
(`web/CMakeLists.txt:330-339`). Unreferenced archive members cost nothing.
The question for web is empirical: measure before assuming.

---

## 2. What the wrapper actually uses

Verified by grepping `thermion_dart/native/src`:

| Library | Used where | Verdict |
|---|---|---|
| **stb** | `TTexture.cpp:26,52` (`stbi_load_from_memory` for `Image_decode`, used by e.g. the picking example); `TGltfResourceLoader.cpp:45-49` (gltfio stb provider for `image/png` + `image/jpeg`) | **core** — nearly every consumer loads PNG/JPEG textures |
| **image** | `TTexture.cpp:15-16` (LinearImage, color transform) | core |
| **ktxreader** (+ basis_transcoder) | `TTexture.cpp:19-20,132-194` (KTX1/KTX2); `TGltfResourceLoader.cpp:46-47` (`image/ktx2`) | core for KTX2 assets; could be opt-out for apps that use no KTX2 |
| **uberarchive + uberzlib** | `TGltfAssetLoader.cpp:22,49`, `TEngine.cpp:29` (default ubershader materials) | core |
| **imageio** | only two includes in `TEngine.cpp:31-32`. Zero calls anywhere. Screenshot PNG encoding happens on the **Dart side** (`lib/src/utils/src/image.dart:72-147`, the `image` package) | **dead** |
| **tinyexr** | dependency of imageio only | **dead** |
| **png (libpng)** | dependency of imageio only; hook does not even link it | **dead** |
| **z (zlib)** | referenced by libpng/tinyexr (both dead) and gltfio's stb provider (stb needs zlib for PNG? no — stb is self-contained) | **likely dead**; verify by linking without it |
| **filamat** | zero includes of `<filamat/...>` in wrapper source. All materials are precompiled `.package` blobs built with `Material::Builder().package(...)` (`TEngine.cpp:290`, `TMaterialInstance.cpp:57-114`) — that is the `filament` lib, not filamat | **dead for core**; kept only for declarative plugins that compile materials at runtime |
| **zstd** | pulled only by filamat (`build.dart:187-195`) | dead if filamat goes |
| **filameshio** | zero references in wrapper source (only `native/test/macos`) | **dead** |
| **dracodec** | not referenced by wrapper directly; referenced by gltfio_core (Draco-compressed glTF meshes) | core unless assets are known Draco-free |
| **filaflat, smol-v, ibl, filament-iblprefilter** | no direct wrapper references; referenced transitively by filament/gltfio (filaflat, smol-v) or not at all (ibl-prefilter) | verify individually by removal |

---

## 3. Which libraries can be optional

**Core (keep always):** filament, backend, filabridge, utils, geometry,
gltfio(_core), image, stb, uberzlib, uberarchive, ktxreader,
basis_transcoder, filaflat, smol-v, perfetto (Android), matdbg/fgviewer
(debug).

**Dead today — candidates for deletion, not flags:**
imageio, tinyexr, libpng, filameshio. Nothing calls them. Removing them is a
bug fix, not a feature.

**Dead for core, needed by plugins:** filamat (+ zstd). External declarative
plugins may compile materials at runtime; that is why filamat is linked. Make
it opt-in (`runtime_materials: true`), default off, and let the plugin
config declare it.

**Genuinely optional features (opt-out with real API impact):**
- dracodec — only needed for Draco-compressed glTF assets.
- ktxreader/basis_transcoder — only needed for KTX1/KTX2 textures.
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
      runtime_materials: false # filamat, zstd
      filamesh: false
      draco: false             # later phase
```

Implementation: gate entries in the `libs` list (`build.dart:154-211`) and
pass matching `-DTHERMION_*` defines so the wrapper source can guard code.

### 4.2 Preprocessor guards in the wrapper

Wrap the feature entry points (e.g. `Image_decode`, `Ktx*Reader_*`,
`Engine_buildMaterial`) in `#if defined(THERMION_ENABLE_...)`. Compiled-out
functions must still exist and return a clear error — a missing FFI symbol
crashes the isolate, a returned error does not. Example:

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
| zstd | ~0.2-0.5 MB | only a few `ZSTD_*` symbols are referenced; whole-archive includes the rest |
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

1. **gltfio texture decoding.** `TGltfResourceLoader.cpp:45-49` registers
   stb (png/jpeg) and ktx2 providers. These are core; the proposal does not
   touch them. Draco opt-out breaks loading of Draco-compressed glTFs at
   runtime — the error must be clear, and the docs must say so.
2. **Plugins that need filamat.** Removing filamat by default can break
   declarative plugins that compile materials at runtime. Mitigation: the
   `requires:` mechanism (§4.5) and a release-note warning.
3. **Linux whole-archive exists for a reason.** Do not remove the flag
   itself without understanding why it was added (likely symbol
   interposition/callback ordering). Only shrink the lib list inside it.
4. **Windows link list is in a header.** `ThermionWin32.h` pragmas must
   stay in sync with the flags, or LINK fails. Gate the pragmas with the
   same defines.
5. **Test impact.** `native/test/linux/CMakeLists.txt:77` and
   `native/test/macos/CMakeLists.txt:101,109` link imageio/filameshio.
   Tests keep the full (all-features) configuration; flags default matters:
   if flags default to OFF, CI must build a "minimal" matrix entry to keep
   it honest.
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
   `filamesh`, `ktx`, (later) `draco` user_defines; preprocessor guards
   with error-returning stubs; `Engine_getCapabilities`; regenerate
   bindings (`make bindings`); plugin `requires:` list; document in
   `thermion_dart/README.md` next to the existing `user_defines` examples.
   Default: everything ON at first, so no consumer breaks. Let consumers
   opt out. After a deprecation window, flip dead-code defaults to OFF.
4. **(Later, larger) draco/ktx compile-out in Filament.** dracodec is
   referenced from inside gltfio_core, so removing it fully means a Filament
   rebuild with draco disabled (patch or upstream CMake option) in
   `scripts/build_android.sh` / `build_ios.sh` / `build_linux.sh` /
   `build_macos.sh`. Only do this if step 1 shows meaningful sizes and users
   ask for it.
5. **CI size report.** Print binary sizes per platform per PR, so future
   additions show their cost immediately.