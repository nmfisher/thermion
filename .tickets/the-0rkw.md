---
id: the-0rkw
status: closed
deps: []
links: []
created: 2026-08-14T10:09:54Z
type: task
priority: 2
assignee: Nick Fisher
tags: [build, cmake, binary-size, proposal]
---
# Proposal: compile-time opt-in/out of optional libraries (libpng, libz, etc.) to reduce binary size

Plan how to make optional native libraries (e.g. libpng, libz) opt-in/opt-out at compile time so consumers who don't need them get smaller binaries. PROPOSAL-ONLY: analysis + proposal document, no code changes.

## Sandbox brief (for the agent — read this first)

You are a coding agent writing a PROPOSAL for the thermion native build.
This task is PROPOSAL-ONLY: analyze and write a proposal document. Make NO
code, build, or test changes. Do not run builds.

### Goal

Plan how to make optional native libraries opt-in/opt-out at compile time,
so consumers who do not need them get smaller binaries. Examples Nick
named: libpng, libz. The question: are these always needed, and can we
compile them out to reduce binary sizes?

### Context (verified on the host)

- Per-platform build scripts in scripts/: build_android.sh, build_ios.sh,
  build_linux.sh, build_macos.sh, build_web.sh, build_windows.bat.
- Linux/macOS builds add Filament third_party include dirs, e.g.
  -I$FILAMENT_BASE_DIR/third_party/libpng, tinyexr, basisu/encoder
  (build_linux.sh:210/226, build_macos.sh:184/197/243/256).
- Web CMakeLists (thermion_dart/native/web/CMakeLists.txt) imports static
  libs: filament, gltfio_core, image, uberzlib, z, zstd, mikktspace,
  filameshio, etc. (lines ~157-278).
- Filament itself bundles these third_party libs; thermion_dart/native
  holds the Dart FFI bindings + native wrapper.

### Deliverable — proposal document (docs/optional-libs-proposal.md or similar)

Cover:
1. Which native libraries are linked today, per platform, and what they
   are used for (find actual usage in thermion_dart/native source —
   e.g. where does the wrapper touch png/zlib/image decoding?).
2. Which libraries could plausibly be optional (not needed by every
   consumer) vs which are core (Filament runtime deps).
3. The mechanism: CMake options (e.g. THERMION_ENABLE_IMAGE_IO=OFF),
   feature flags, preprocessor guards, per-platform wiring in the build
   scripts, and how the Dart side would expose the capability at runtime
   (e.g. capability query so the app knows what is compiled in).
4. Realistic binary-size impact per library (estimate; note that static
   linking only includes referenced symbols, so dead-code elimination may
   already shrink much of it — be honest about expected gains).
5. Risks: what breaks if a lib is removed (gltfio needs image decoding?
   assets need png?), API surface changes, test impact.
6. Recommended first step(s) and an ordered plan.

### Rules

- Update this ticket with tk: start the-0rkw when you begin, close it when
  done (tk may not be installed — edit the status field directly).
- Commit the proposal document locally on the asb/ branch.
- Push + open a PR when finished (if push is blocked, commit and report).
- Never merge the PR. Never commit or push directly to master/develop.
- Simplified technical English: short sentences, plain words.
- PROPOSAL-ONLY: no code/test/build changes. Ever. This is a plan.

## RESUME — your proposal's headline claim is WRONG, re-review (2026-08-14)

Nick reviewed your proposal. Your headline said: "The wrapper source never
calls into imageio, tinyexr, libpng, filamat, or filameshio... DCE removes
most of them already." Nick disagrees, and he is RIGHT. The main agent
re-reviewed the source independently and confirmed it. Your headline
overgeneralized. Re-review and fix the document. Be comprehensive this time.

### Evidence from an independent source review (verified line by line)

1. **PNG decoding IS a first-class, user-facing feature.** The Dart API
   `Texture.decodeToTexture()` -> `FilamentApp.decodeImage()` -> FFI
   `Image_decode()` -> `stbi_load_from_memory()` (TTexture.cpp:52) decodes
   PNG/JPEG textures. This is a public API used on every image load. Your
   doc's own detail table (lines 74-76) correctly listed stb as "core -
   nearly every consumer loads PNG/JPEG textures" — that CONTRADICTS your
   headline claim. stb is NOT optional.

2. **stb provider for glTF is used.** TGltfResourceLoader.cpp:45-49:
   `gltfio::createStbProvider()` + `addTextureProvider("image/png", ...)`
   + `("image/jpeg", ...)`. glTF assets load PNG/JPEG textures through it.

3. **The `image` library is heavily used.** Ktx1Bundle/Ktx2Bundle +
   LinearImage + sRGBToLinear color transforms across TTexture.cpp and
   ThermionDartRenderThreadApi.cpp. Not dead.

4. **What MIGHT actually be dead (verify, don't assume):**
   - imageio/ImageDecoder.h + ImageEncoder.h are INCLUDED in TEngine.cpp
     (lines 31-32) but no instantiated calls were found — possibly dead
     includes; the imageio/tinyexr LIBRARIES may be DCE'd.
   - Direct libpng calls: none found (PNG goes through stb_image, which is
     self-contained — NOT libpng). So "libpng" may be droppable, but PNG
     decode capability is NOT.
   - filamat / filameshio: no direct calls found — verify before claiming.

### What to do (approved by Nick)

1. Re-review comprehensively: for EVERY library in your link lists, grep
   the actual native source (thermion_dart/native/src/ and the web
   CMakeLists) for real usage — includes, instantiated calls, template
   instantiations, and transitive needs (e.g. does gltfio's stb provider
   need zlib? does ktxreader need basis_transcoder? does image need
   anything?).
2. Correct the document: fix the headline and section 2 (optional vs core)
   to match the evidence. stb, image, ktxreader are CORE. Only genuinely
   unused libs (imageio/tinyexr/filamat/filameshio, maybe direct libpng)
   are candidates for opt-out.
3. Keep the Linux --whole-archive finding (it is real and valuable), but
   present the whole picture honestly: per-library verdict table with
   evidence, per platform, and realistic size impact.
4. Commit the corrected document on this branch. Do NOT push, do NOT raise
   a PR, do NOT close the ticket — local planning only, as instructed.
5. Report what you changed and your per-library verdicts.

Rules unchanged: no code/test/build changes, simplified technical English,
commit locally only.
