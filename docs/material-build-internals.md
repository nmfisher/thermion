# Material build internals

This page describes how the package compiles and caches app materials and
optionally links the generated C assets. For app setup and a loading example,
see [Compile a custom material at build time](https://thermion.dev/build_configuration/#compile-a-custom-material-at-build-time).

## Build steps

On every build the hook:

1. Expands `inputs` to `.mat` files (a directory is scanned recursively, a
   glob like `materials/**/*.mat` is matched against files; anything that
   resolves to nothing fails the build with the input named).
2. Reads `build/materials/.thermion-materials.json`, the manifest recording
   what was compiled, by which toolchain, from which inputs.
3. Compiles exactly what is stale with the version-matched `matc` — and
   skips everything (no download, no tool run) when nothing changed.

The result is one **blended** `.filamat` per material — a single package
carrying every requested backend, with one stable filename, so loading it
at runtime (`FilamentApp.createMaterial(Uint8List data)` after reading the
file) works on every platform.

## The `matcId`

The manifest records a `matcId`: a SHA-256 over the pipeline version, the
Filament tag pinned in `filament.version`, the `thermion_dart` package
version, and the host platform/arch. The sha256 of the downloaded `matc`
binary is recorded separately as `matcSha256`. When either changes — for
example a Filament or Thermion bump ships a new `matc` — **every material is
recompiled, even if no `.mat` file changed.** When the compiler is unchanged:

- a material or transitive quoted include changed, a material was added, or
  a recorded output is missing or has different bytes → that material recompiles;
- an input was removed from the config → its outputs are deleted;
- everything matches → the hook logs why it skipped and does nothing else.

## Tools and cache

`matc` (and `resgen` when `resgen: true`) are downloaded from Thermion's R2
bucket for the **host** platform. The hook selects the release archive through
the shipped `filament.libs.json` pin and verifies its full SHA-256 before
extracting `bin/`. Pinned archives use immutable hash-suffixed URLs; a pin
change selects a separate tool cache and rebuilds the app’s material packages.
The cache lives under:

```
${XDG_CACHE_HOME:-$HOME/.cache}/thermion/filament-tools/filament-<tag>-webgpu-<host>-<hash16>/
```

Without a pin entry, the hook falls back to the legacy archive URL and omits
the hash suffix from the cache directory.

The cache is shared by all projects on the machine and is trusted only
after `matc` passes a `-a webgpu` smoke test. Installation holds a shared
cache lock across app builds. Downloads and extraction use a private temporary
directory; only a complete installation that passes the smoke test is renamed
into the live cache. A failed download leaves no partial installation. These
builds of `matc` support WebGPU (WGSL) — the
official Filament release binaries do not.

## `backends`

- `all` (default): `-a metal -a vulkan -a opengl -a webgpu` — one package
  that works everywhere Thermion runs.
- `native`: metal + vulkan + opengl (no WebGPU).
- `web`: opengl + webgpu (what a browser can load).
- an explicit list, e.g. `[vulkan]`, passed straight to `matc -a`.

## `resgen`

With `resgen: true`, each `.filamat` is additionally converted to C:

```
resgen -c -p <prefix> -x <output>/ <stem>.filamat
```

producing `<prefix>.c` and `<prefix>.h` beside the `.filamat` (plus
whatever else resgen emits). The prefix defaults to the sanitised material
name (non `[A-Za-z0-9_]` characters become `_`, so `my-eye.mat` →
`my_eye`); override it per material with:

```yaml
        resgen_prefixes:
          skin: APP_SKIN
```

Because every material is one blended package, there is exactly one
`.c`/`.h` per material and no per-variant symbol collision. Like
Thermion's own materials pipeline, the emitted `.c` gets a prepended
`#include` of its own header (so the package symbol has external C linkage
when the file is compiled as C++) and the header's `extern "C"` block gets
`__cplusplus` guards (so it is also valid C) — without the include, a C++
compile gives the `const` array internal linkage and the optimiser drops
the unreferenced symbol entirely. Public declarations also get explicit
export annotations: default visibility on Android/ELF and `dllexport` on Windows.

## `link_generated`

`resgen: true` only writes the `.c`/`.h` files; nothing compiles them, so
they are only usable if you build your own native library. With
`link_generated: true` the build hook additionally compiles the emitted
`.c` files **straight into `libthermion_dart`** — the exact same mechanism
Thermion uses for its own materials under `native/include/material/`. Each
generated `.c` is appended to the native build's source list and the output
directory is added to its include path (so `skin.c` resolves
`#include "skin.h"`), before the native library is compiled and linked in
the same build.

Notes:

- `link_generated: true` **implies `resgen`** emission — you never set both.
- The generated symbols (`<PREFIX>_PACKAGE[]`, e.g. `SKIN_PACKAGE`) are
  exported by `libthermion_dart`, so they are resolvable from Dart FFI
  through the default code asset — no separate asset id or loading step.
- **Native only.** Web builds compile their material C sources into the
  wasm engine via CMakeLists, and a web build with `link_generated: true`
  fails with an error explaining this — remove the flag for web targets.
- **Symbol collisions fail the build at plan time.** Two materials whose
  prefixes sanitise to the same symbol (or a material whose prefix matches
  one of Thermion's built-in materials — `grid`, `image`, `gizmo`, ...) would
  define the same `<PREFIX>_PACKAGE` symbol and fail at link time with an
  obscure error; the hook catches this before compiling anything and names
  both inputs. Give one of them a distinct `resgen_prefixes` entry.
- Only the `.c` files the materials manifest vouches for are linked —
  stale leftovers in the output directory are never picked up, and the
  manifest records whether the generated sources were linked.

## Failure behaviour

All materials compile in staging before any output is published. If a tool
fails, the previous generation remains intact. Publication keeps backups and
writes the manifest last; a publication error restores the previous generation,
and the next hook run recovers any publication interrupted by process exit.
Stale cleanup never deletes a filename owned by a current material. Before
compiling, the hook rejects output filenames shared by different inputs,
including collisions introduced by `resgen_prefixes` with cached materials.

The hook registers discovery directories, transitive include files, the
manifest and generated files as build dependencies. New directory/glob matches
and deleted or changed outputs therefore invalidate the build-runner cache.
Quoted includes resolve relative to the file that contains them, including
nested includes. Failures are loud, never silent skips:

- No network and no cached tools: the build fails naming the R2 URL and the
  Filament version.
- `matc`/`resgen` exit non-zero: the build fails with the tool's stderr.
- Bad configuration (unknown key values, an input that resolves to
  nothing, two inputs with the same output name or the same resgen symbol,
  `link_generated` on a web build): the build fails with an
  actionable message.

If `material_compilation` is absent, the hook does nothing new.
