# Proposal: Custom Thermion Build for Sakura

Status: **Proposal (no code or test changes)**.
Ticket: `the-qqfr`. Branch: `asb/custom-build-proposal`. Related: `the-qxv6`
(libc++ Linux rebuild), `asb/sakura-clone`.

## TL;DR

The sakura-clone work needs three things to match the reference render.
**Only one of them actually needs a custom Filament build.**

| Need | Needs a native rebuild? | Why |
|---|---|---|
| 1. Custom per-pixel toon material | **No** | Compiled to `.filamat` and embedded as base64 in `thermion_sakura/lib/src/materials_gen.dart`. Loaded at runtime via `createMaterial`. Runs on stock thermion. |
| 2. UV attributes (TEXCOORD_0/1) for tint/rampId | **No** | gltfio passes UVs through unchanged. Only the material `requires:` list and the GLB content change. |
| 3. COLOR_0 stays **linear** (no sRGB conversion) | **Yes** | Filament's gltfio converts COLOR_0. Fixing it means rebuilding the gltfio archive that is linked into `libthermion_dart.so`. |

So "the custom build" is really **one change**: stop gltfio converting
COLOR_0. Everything else is runtime/content work that already works on stock
thermion.

This document describes that change, the two ways to ship it (a patched
Filament build, or a lighter gltfio bypass), the plan, and the open questions.

## Background: how thermion ships Filament today

Two layers, kept separate on purpose.

### Build layer — `scripts/build_<plat>.sh` + `.github/workflows/build-filament.yml`

`build-filament.yml` is **manually triggered** (`workflow_dispatch`). For each
platform it:

1. Checks out Filament at the tag in `filament.version` (today `v1.69.1`).
2. Runs `scripts/build_linux.sh` (and the `-arm64` job). That script **patches
   Filament source in place** before building. Existing patches:
   - `FFilamentAsset.h` + `libs/gltfio/CMakeLists.txt` — make
     `GLTFIO_USE_FILESYSTEM` overridable and force it off.
   - `basisu` / `filamat` CMakeLists — position-independent code.
   - `imageio` / `tinyexr` — built with `-stdlib=libc++` (the `the-qxv6` ABI
     fix).
3. Zips the static archives + headers and uploads them to Cloudflare R2 under
   the key `filament-<version>-<platform>-<variant>.zip`, e.g.
   `filament-v1.69.1-linux-arm64-release.zip`.

This is the natural place for any new Filament source patch: another `sed`
step in `build_linux.sh`, applied before the build.

### Consumption layer — `thermion_dart/hook/build.dart`

Every consumer of `thermion_dart` runs this hook (`native_toolchain_c`
`CBuilder`). For non-web targets it:

1. Calls `getLibDir()`, which **downloads** the right zip from R2
   (`_getLibraryUrl` builds the key from `_FILAMENT_VERSION`, read from
   `filament.version`).
2. Links the static archives (including `gltfio_core`, `gltfio`) into
   `libthermion_dart.so` with `-stdlib=libc++`.

Key consequence: **what gets shipped is decided by which zip is on R2.** A
hook change alone changes nothing; a rebuilt zip on R2 changes it for
**every** consumer of that version. There is **no version/URL override** for
native today (only `web_local` exists, for web).

### How sakura consumes it

- `thermion_sakura` is web-only (`skip_native_build: true`).
- `thermion_sakura_native` is the native headless renderer: **arm64 Linux +
  OpenGL, release mode**, depends on `thermion_dart` via a path dependency. It
  loads the world GLB with `loadGltfFromBuffer` (the gltfio path). **This is
  the consumer that needs the COLOR_0 fix.**

The agreed scope is **one platform/backend: arm64 Linux + OpenGL.** Web and
mobile are out of scope for this proposal (see Open Questions).

## The root cause (COLOR_0)

The world GLB stores vertex colours in **linear** space (see
`thermion_sakura/lib/src/mesh.dart`, `glb.dart`). The toon material reads them
with `getColor()`. Filament's gltfio loader applies a sRGB/linear conversion
to COLOR_0 on load, so by the time the shader sees the value it is no longer
the authored linear colour — this is the "pink instead of red" mismatch.

The conversion lives in Filament's gltfio source. Candidate files in
`v1.69.1`: `libs/gltfio/src/ResourceLoader.cpp` and/or
`libs/gltfio/src/AssetLoader.cpp`, in the COLOR-attribute decoding/binding
path. **Phase 0 of the plan is to pin the exact line** (the build scripts
already patch gltfio the same way, so the mechanism is proven).

Note: thermion has **no vendored copy** of gltfio. It uses Filament's gltfio
through headers (`#include <gltfio/...>`). So the fix has to be a Filament
patch, not a thermion-source edit.

## Option A — Patched Filament build (the "custom build")

This is the change the ticket asks about, end to end.

### What changes

1. **Build script** (`scripts/build_linux.sh`, both x64 and arm64 use it): add
   a `sed` patch that neutralises the COLOR_0 conversion in gltfio, next to
   the existing `FFilamentAsset.h` patch. Gate it behind an env var
   (e.g. `SAKURA_COLOR_PATCH=1`) so default upstream builds are untouched.
2. **CI** (`.github/workflows/build-filament.yml`): run a one-off Linux+arm64
   build with `SAKURA_COLOR_PATCH=1` and a **custom version string**
   (e.g. `v1.69.1-sakura`). It uploads
   `filament-v1.69.1-sakura-linux-arm64-release.zip` etc. under a **new** R2
   key — never overwriting `filament-v1.69.1-*`.
3. **Consumption** (`thermion_dart/hook/build.dart`): add a native override so
   the sakura build fetches the custom zip instead of the stock one. Two
   shapes, pick one:
   - `filament_version` userDefine — overrides `_FILAMENT_VERSION` so the R2
     key becomes the custom one. Smallest change; reuses the existing URL
     scheme.
   - `native_local` userDefine — mirror `web_local`: skip R2, copy archives
     from a local dir. Best for fast iteration; needs the patched zip hosted
     somewhere for non-local runs.
4. **Verify**: rebuild sakura reference frames (`thermion_sakura_native/bin/
   render_ref.dart`) and compare against the reference. Red, not pink.

### Why a custom version string / separate R2 key

Uploading under the stock `filament-v1.69.1-*` keys would change behaviour for
**every** thermion consumer and silently regress anything that relied on
gltfio's current COLOR_0 handling. A separate key (`...-sakura-...`) keeps
upstream thermion untouched and makes the custom build opt-in.

### Pros / cons

- ✅ Matches the ticket framing exactly. Sakura keeps the `loadGltfFromBuffer`
  path, so the **same fix covers web** later.
- ✅ Reuses the proven patch-in-build-script pattern.
- ❌ Full Filament rebuild (~50 min on CI), plus per-Filament-version re-runs.
- ❌ New distribution surface (custom R2 keys + a hook override to maintain).
- ❌ Patch must be re-applied and re-verified on every Filament bump.

## Option B — gltfio bypass via CustomGeometry (lighter; no rebuild)

Filament applies the sRGB/linear logic only inside gltfio. Thermion's own
`CustomGeometry` (`thermion_dart/native/src/scene/CustomGeometry.cpp`)
declares `VertexAttribute::COLOR` as raw `FLOAT4`, and Filament does **not**
convert float vertex attributes. Today it writes dummy white colours, but the
plumbing for a real COLOR buffer is mostly there.

### What changes

1. Extend `CustomGeometry` (and its Dart API / `GeometrySceneAsset`) to accept
   a per-vertex **colour** buffer (FLOAT4, linear, passthrough) and expose
   **UV1**. (UV0 already exists.)
2. Switch the sakura **cel** pass from `loadGltfFromBuffer` to
   `createGeometry` — the same path the **depth** pass already uses.
3. No Filament rebuild, no R2, no versioning. Consumed via the existing
   `thermion_dart` package on the sakura branch (or via the hook's existing
   `plugins` userDefine).

### Pros / cons

- ✅ No Filament rebuild. No distribution/versioning problem. Isolated to the
  sakura branch — zero risk to upstream consumers.
- ✅ Fast iteration.
- ❌ Does **not** cover web: the sakura README notes `createGeometry` renders
  nothing on the web build, where gltfio is the only working geometry route.
  So Option B is native-only (which matches the agreed scope).
- ❌ Adds a thermion native API surface (colour + UV1 on CustomGeometry).

## Recommendation

Given the agreed scope is **native arm64 Linux + OpenGL only**:

1. **Start with Option B.** It removes the blocker with no rebuild and no new
   distribution surface. It also exposes COLOR/UV1 on `CustomGeometry`, which
   is useful beyond sakura.
2. **Keep Option A as the escalation** if/when web parity is required, or if
   Nick prefers the sakura render path to stay on gltfio for parity with the
   web build. Option A is then the long-term home for the fix and a candidate
   for an upstream Filament PR.

Either way, **Phase 0 (pin the exact gltfio COLOR_0 line) is shared** and
should happen first — it tells us how large the Option A patch really is and
confirms Option B is genuinely conversion-free.

## Plan

### Phase 0 — Pin the COLOR_0 conversion (shared, ~0.5 day)

- Read Filament `v1.69.1` gltfio source; locate the COLOR_0 conversion
  (`ResourceLoader.cpp` / `AssetLoader.cpp`).
- Confirm with a one-off instrumented build (log COLOR_0 before/after
  `ResourceLoader::loadResources`) that this is the conversion to remove.
- Confirm CustomGeometry's FLOAT4 COLOR path is conversion-free (read the
  Filament `VertexBuffer` docs / source).

### Phase 1 — Option B (native), ~1–2 days

- Extend `CustomGeometry` + Dart API for COLOR and UV1.
- Switch sakura cel pass to `createGeometry`.
- Re-render reference frames; match-check against the reference.

### Phase 2 — Option A (custom Filament build), ~2–3 days (only if needed)

- Add the gated COLOR_0 `sed` patch to `scripts/build_linux.sh`.
- Add a native override to `thermion_dart/hook/build.dart`
  (`filament_version` or `native_local`).
- Run `build-filament.yml` for linux + linux-arm64 with the custom version;
  upload under separate R2 keys.
- Point sakura at the custom build; re-render and match-check.
- Document the custom-build runbook (how to rebuild on a Filament bump).

### Phase 3 — Versioning / release hygiene

- Decide whether the patched zips are sakura-only (R2 key + branch override)
  or published (separate pub package / forked `thermion_dart`).
- Make sure no CI path can overwrite the stock `filament-v1.69.1-*` keys.

## Trade-offs summary

| | Option A (custom build) | Option B (CustomGeometry) |
|---|---|---|
| Filament rebuild | Yes (~50 min) | No |
| Covers web | Yes | No |
| Distribution/versioning | New R2 keys + hook override | None |
| Risk to upstream consumers | Low if keyed separately | None |
| Iteration speed | Slow (rebuild) | Fast |
| Effort | ~2–3 days | ~1–2 days |

## Open questions for Nick

1. **Web parity**: is native (arm64 Linux + OpenGL) the only target for now,
   or must sakura also render correctly on web (gltfio path)? This decides
   Option A vs B.
2. **Upstream intent**: is the COLOR_0 conversion a Filament bug worth a PR,
   or a deliberate behaviour we patch locally and carry?
3. **Distribution**: who consumes the patched build — just the sakura branch,
   or other projects too? (Decides R2-key-only vs a published fork.)
4. **Patch site**: do you already know the exact gltfio line in `v1.69.1`, or
   is Phase 0 (pinning it) acceptable as the first deliverable?
5. **UV tint/rampId**: should the TEXCOORD_0/1-based tint/rampId land in this
   work or a follow-up? (No build impact either way — just material + GLB.)
