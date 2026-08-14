---
id: the-0rkw
status: open
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
- DO NOT raise a PR. DO NOT push the branch. This is LOCAL PLANNING ONLY —
  Nick will review the proposal document in the sandbox volume.
- Do NOT close this ticket (the-0rkw) — leave it open until Nick reviews.
- Keep the sandbox/volume alive: commit locally, that is all.
- Simplified technical English: short sentences, plain words.
- PROPOSAL-ONLY: no code/test/build changes. Ever. This is a plan.

