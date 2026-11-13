# Building Filament for Thermion

The `build_<platform>` scripts build the Filament version from `filament.version`
for use by Thermion. Both debug and release runtime archives disable C++
exceptions. The existing `build-filament.yml` workflow runs these scripts.

`filament-no-exceptions.patch` adapts Filament 1.77.2 for this build:

- Desktop runtime builds disable C++ exceptions for C++ and Objective-C++
  sources; MSVC uses `/EHs-c-` with `_HAS_EXCEPTIONS=0`. Host tools keep
  exceptions: upstream `build.sh` already passes `-DFILAMENT_ENABLE_EXCEPTIONS=ON`
  to the split host-tools build, and the patch only adds a
  `FILAMENT_HOST_TOOLS_OPTIONS` pass-through there (used for the WebGPU host
  tools on Linux).
- Desktop runtime builds skip the tools, samples and third-party apps that
  require exceptions; `libpng`, `libz` and `tinyexr` do not and stay enabled.
- When the host tools are built separately (`-y`), the Android and iOS target
  builds no longer rebuild them.
- Android builds the native libraries without the Java/JNI wrappers.
- The debug frame-graph viewer parses numbers without C++ exception handling.
- Runtime builds exclude the image decoder test that requires C++ exceptions.

`filament-matp-runtime.patch` builds `matp` (the material parser behind `matc`)
for the runtime archives on desktop, Android, iOS and WASM, and installs its
include-resolution headers (`Includes.h`, `IncludeCallback.h`) alongside the
public `filament-matp` headers. Thermion links `matp` when the
`runtime_materials` build option is enabled, to compile full `.mat` packages
with `#include` support at runtime. `matp` itself is exception-free.

Linux archives also include the matching `matc` and `resgen` in `bin/`. The
separate host-tool build enables WGSL compilation for the committed WebGPU
materials; this does not enable a new runtime backend.

The runtime packages omit `imageio`, which requires exceptions and is used only
by the host tools. Thermion does not link or call that library. The other
separately built archives use the same C++ settings as the runtime.

Filament 1.77.2 uses the standard `filament-<version>-<platform>-<mode>.zip`
names. The version change keeps these builds separate from the existing
1.75.0/1.76.0 archives. Use a fresh Filament checkout for each artifact build, as the workflow
does. Refresh and validate the patch when changing the Filament version.

When updating `filament.version`, run `python3 scripts/generate-filament-version.py`
and commit the resulting Dart constant. The build and publishing workflows check
that it matches the pin. The build hook reads this constant too, so hosted, Git
and path consumers all download the version exposed by the public API.

Before merging, build and publish the 1.77.2 archives for all supported platforms
using this branch's Build Filament workflow. Existing 1.75.0/1.76.0 downloads stay available.

## Content-addressed artifacts and the pin

Filament zips are published under **immutable, content-addressed keys**:

```
filament-<version>-<platform>-<variant>-<hash16>.zip
```

`<hash16>` is the first 16 hex chars of the zip's SHA-256. The full digest is
recorded in `thermion_dart/filament.libs.json` (the *pin*), keyed
`<platform>/<variant>` (platforms: macos, ios, ios-simulator, android, linux,
linux-arm64, windows, web). The pin ships with the package; the build hook
(`thermion_dart/hook/build.dart`) resolves each artifact through it, verifies
the download against the full SHA-256, and caches under a hash-scoped
directory so a pin flip can never be masked by an old `success` token.
Entries absent from the pin fall back to the legacy mutable
`filament-<version>-<platform>-<variant>.zip` keys — those still exist for
already-published thermion versions and are **never written anymore**.

Rollout / rollback:

1. Dispatch **Build Filament** (any `upload_to_r2` setting — uploads go to
   hash keys via `scripts/upload_filament_hashed.sh`, which also writes a
   `.sha256` sidecar). Zips are also GitHub artifacts (7-day retention).
2. Verify the zips (matp contents; a `runtime_materials` test run).
3. Dispatch **Publish Filament to R2 (from artifacts)** with the run IDs.
   It re-hashes each zip, uploads the hash key (skipping identical content
   already on R2), and merges the digests into the pin. The merged pin is a
   workflow artifact; `commit_pin: true` also commits it to the dispatch
   branch — that commit **is** the rollout.
4. Rollback = revert the pin commit. Old artifacts remain on R2.

Shell/CI callers resolve URLs with `python3 scripts/filament-artifact-url.py
<platform> <variant>` (used by the Makefile `wasm` target,
`web-canvas-thread.yml`, the regenerate workflow's cache self-heal, and
`regenerate-materials.sh`). The pure Dart logic lives in
`thermion_dart/lib/src/hooks/filament_artifacts.dart` (unit-tested in
`test/filament_artifacts_test.dart`); keep the Python resolver in sync.

`scripts/upload_r2.sh` is a generic helper that uploads under the file's
existing name — do **not** use it for Filament artifacts (it would write the
legacy mutable keys).

