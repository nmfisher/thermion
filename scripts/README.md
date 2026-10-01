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
