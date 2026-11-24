/// Pure resolution of which Filament debug-server archives (the material
/// debug server `matdbg` and the frame graph viewer `fgviewer`) a build
/// links, and of the extra archives they need on Windows.
///
/// Kept free of any build-hook or native-assets imports so it can be unit
/// tested directly (see test/debug_server_link_test.dart) and imported by
/// hook/build.dart via a relative path.
library;

/// Filament's debug-server archives, in link order.
const List<String> debugServerArchives = ['matdbg', 'fgviewer'];

/// Archives `matdbg.lib` references that are otherwise absent from the
/// Windows link line.
///
/// Windows ships every Filament dependency as its own `.lib` (the
/// Linux/macOS/Android builds fold them into the debug-server archives),
/// so linking matdbg without these leaves `mg_*`/`CivetServer` (civetweb),
/// `spv*` (SPIRV-Tools), `spirv_cross::*` (spirv-cross) and
/// `MATDBG_RESOURCES_PACKAGE` unresolved. `filamat`, `filaflat`, `utils`
/// and `smol-v` are already linked; the glslang/SPIRV-Tools inputs come
/// from [windowsShaderCompilerArchives]. Symbol-level closure verified
/// against the pinned v1.77.2 Windows debug artifact.
const List<String> windowsMatdbgDependencies = [
  'matdbg_resources',
  'civetweb',
  'SPIRV-Tools',
  'spirv-cross-core',
  'spirv-cross-glsl',
];

/// The shader-compiler archives `filamat.lib` needs on Windows, where (unlike
/// the combined Linux/Android `libfilamat.a`) they are not folded into
/// `filamat.lib` itself.
///
/// glslang's three targets carry a CMake `DEBUG_POSTFIX`, so their file
/// names differ per build mode: `glslangd.lib` in the debug artifact vs
/// `glslang.lib` in the release one (same for `OSDependent` and `SPIRV`).
List<String> windowsShaderCompilerArchives({required bool debug}) => [
  for (final archive in const ['OSDependent', 'glslang', 'SPIRV']) debug ? '${archive}d' : archive,
  'SPIRV-Tools',
  'SPIRV-Tools-opt',
  'spirv-cross-core',
  'spirv-cross-glsl',
  'spirv-cross-msl',
];

/// Result of [resolveDebugServerLink].
typedef DebugServerLinkResolution = ({
  /// Debug-server archives to link (a subset of [debugServerArchives]).
  List<String> archives,

  /// Whether `matdbg` is among [archives]. Drives the `ENABLE_MATDBG`
  /// define, the debug-only `filamat` link (matdbg's ShaderReplacer uses
  /// `filamat::GLSLTools`/`Chunk`) and [windowsMatdbgDependencies].
  bool matdbgLinked,

  /// Archives the artifact does not ship (Windows only; logged by the hook).
  List<String> notShipped,
});

/// Resolves which debug-server archives a build links.
///
/// Filament's `libfilament` only references matdbg/fgviewer when its build
/// enabled `FILAMENT_ENABLE_MATDBG` / `FILAMENT_ENABLE_FGVIEWER`
/// (`build.sh -d -t`). Every artifact script passes those for its debug
/// build except iOS (never) and Windows: `scripts/build_windows.bat` passes
/// neither option, so the pinned Windows debug zip was built with both OFF
/// — `filament.lib` references neither, `fgviewer.lib` is not shipped at
/// all and `matdbg.lib` is shipped but unreferenced.
///
/// [targetOS] is a lowercase OS name. Release builds and iOS link nothing.
/// On Windows an archive is linked only when [shipped] reports it in the
/// artifact, so the current zip (no fgviewer) links today and a future zip
/// that ships `fgviewer.lib` is picked up without a hook change. Every
/// other platform links unconditionally, so a missing archive fails the
/// link loudly instead of deferring to dlopen.
DebugServerLinkResolution resolveDebugServerLink({
  required String targetOS,
  required bool debug,
  required bool Function(String archive) shipped,
}) {
  if (!debug || targetOS == 'ios') {
    return (archives: const [], matdbgLinked: false, notShipped: const []);
  }
  final archives = <String>[];
  final notShipped = <String>[];
  for (final archive in debugServerArchives) {
    if (targetOS == 'windows' && !shipped(archive)) {
      notShipped.add(archive);
    } else {
      archives.add(archive);
    }
  }
  return (archives: archives, matdbgLinked: archives.contains('matdbg'), notShipped: notShipped);
}
