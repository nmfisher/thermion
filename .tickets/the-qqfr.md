---
id: the-qqfr
status: closed
deps: []
links: []
created: 2026-08-11T13:47:06Z
type: task
priority: 2
assignee: Nick Fisher
tags: [proposal, design, sakura, custom-build]
---
# Design: what is required to support the custom build

Brainstorm and design the custom thermion build support. Context: the sakura-clone work (branch asb/sakura-clone) needs a custom build of thermion with: (1) a custom per-pixel Filament toon material, (2) per-vertex attributes (COLOR_0 linear, no sRGB conversion in gltfio loader; UV attributes for tint/rampId), (3) the gltfio loader COLOR_0 sRGB fix. Question: what is required to fill out/support the custom build? We can limit to ONE platform/backend if that helps. Write a proposal document describing what the custom build looks like, what is required, and the plan. PROPOSAL-ONLY: no code or test changes.

## Proposal brief (for the sandbox agent — GLM, proposal-only)

You are a coding agent doing a DESIGN EXPLORATION for the thermion repo. Your job: analyze and write a PROPOSAL DOCUMENT. DO NOT change code or tests. Analysis and proposal only.

### Context

The sakura-clone project (branch asb/sakura-clone in this repo, project in thermion_sakura/) renders a ported reference world using thermion. To match the reference render exactly, it needs a custom build of thermion with:

1. A custom per-pixel Filament toon material (implemented, commit 9db46ae0 on asb/sakura-clone, materials/sakura_toon.mat + sakura_vcolor.mat).
2. Per-vertex attributes: COLOR_0 must stay LINEAR (no sRGB conversion). UV attributes (TEXCOORD_0/1) for per-vertex tint/rampId.
3. A gltfio loader fix in thermion_dart: gltfio applies a linear->sRGB conversion on COLOR_0 vertex attributes, which is wrong for Filament's linear pipeline. This is the known root cause of the "pink instead of red" colour mismatch.

The question from Nick: what is required to support/fill out the custom build? We can limit to ONE platform/backend if that helps. Brainstorm what the custom build looks like, what is required, and what the plan is.

### What to investigate

- How thermion_dart builds its native library today (native_toolchain_c? scripts? CI workflow build-filament.yml / build_linux.sh?).
- How the custom toon material (.filamat) gets compiled and bundled (matc? materials/ dir? Makefile target?).
- What the gltfio COLOR_0 sRGB fix touches in thermion_dart (gltfio loader code) and how it would flow through the build.
- What a "custom build" pipeline would look like: one platform (which one? linux x64? macOS?), one backend, how it integrates with the existing release/publish workflow (publish-pub-dev.yml) and the sakura-clone branch.
- Trade-offs: custom build vs upstream, versioning, how the sakura project consumes the custom build.

### Deliverable

Write a proposal document: docs/proposals/custom-build.md (or similar) covering:
1. What the custom build is (scope, platform/backend choice).
2. What is required (code changes, build changes, CI changes).
3. The plan (steps, order, effort).
4. Open questions for Nick.

Keep it practical and concise. Simplified technical English: short sentences, plain words.

### Rules

- PROPOSAL-ONLY: no code changes, no test changes, no builds, no installs.
- Update this ticket: tk start the-qqfr when you begin, tk close the-qqfr when done.
- Commit your work locally on the asb/ branch.
- Raise a PR when finished (push the branch, open the PR against develop). Never merge, never push to main/develop directly.

## Resolution (2026-08-11)

Proposal written: `docs/proposals/custom-build.md`.

Key finding — scope correction: of the three stated needs, **only the gltfio
COLOR_0 sRGB fix actually requires a native rebuild.** The toon material is
compiled to `.filamat` and embedded as base64 in
`thermion_sakura/lib/src/materials_gen.dart`, loaded at runtime — no build
change. UV attributes (TEXCOORD_0/1) pass through gltfio unchanged — no build
change. Only COLOR_0 (a Filament gltfio conversion) needs a rebuilt archive.

Two shipping options, scoped to **arm64 Linux + OpenGL** (the
`thermion_sakura_native` consumer):
- **Option A** — patched Filament build: a gated `sed` patch in
  `scripts/build_linux.sh`, a custom version string + separate R2 keys, and a
  native override (`filament_version` or `native_local`) in
  `thermion_dart/hook/build.dart`. Covers web later. ~2–3 days + rebuild.
- **Option B** — gltfio bypass: extend `CustomGeometry` to pass through a
  linear FLOAT4 COLOR + UV1, switch the cel pass to `createGeometry`. No
  rebuild, no distribution surface, native-only. ~1–2 days.

Recommendation: start with Option B for native; escalate to Option A when/if
web parity is required. Shared Phase 0: pin the exact gltfio COLOR_0 line in
Filament v1.69.1 (`ResourceLoader.cpp` / `AssetLoader.cpp`).

Open questions for Nick are in the doc (web parity, upstream intent,
distribution, patch site, UV scope).

Note: `tk` CLI is not installed in this sandbox; ticket frontmatter was edited
directly (same fallback as `the-qxv6`).

