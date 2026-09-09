# Building Filament for Thermion

The `build_<platform>` scripts build the Filament version from `filament.version`
for use by Thermion. Both debug and release runtime archives disable C++
exceptions. The existing `build-filament.yml` workflow runs these scripts.

`filament-no-exceptions.patch` adapts Filament 1.75.0 for this build:

- Host tools use a separate build. Their image encoders and command-line parsers
  require exceptions, but those executables are never linked into Thermion.
- Desktop runtime builds import the host tools instead of rebuilding them.
- Windows uses MSVC's flags. Metal's Objective-C++ files keep their Objective-C
  handling while using the same C++ header configuration as the C++ files.
- The debug frame-graph viewer parses numbers without C++ exception handling.
- Runtime builds exclude the image decoder test that requires C++ exceptions.
- Android builds the native libraries without the Java/JNI wrappers.

The runtime packages omit `imageio`, which requires exceptions and is used only
by the host tools. Thermion does not link or call that library. The other
separately built archives use the same C++ settings as the runtime.

Rebuilt zip names end in `-no-exceptions.zip`. The Dart hook and web build use
separate `no-exceptions` cache directories. Do not rename an older archive to
the new name: its code and C++ header configuration would disagree with Thermion.
Use a fresh Filament checkout for each artifact build, as the workflow does.
Refresh and validate the patch when changing the Filament version.

Before merging a consumer change, build and publish the new archives for all
supported platforms using the branch's existing workflow. The old archive names
remain available to older Thermion versions.
