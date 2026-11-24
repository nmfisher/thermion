import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import '../lib/filament_version.dart';
import '../lib/src/filament/src/interface/built_in_material.dart';
import '../lib/src/hooks/built_in_materials.dart';
import '../lib/src/hooks/resolve_pubspec_features.dart';
import '../lib/src/hooks/filament_artifacts.dart';
import '../lib/src/hooks/material_backend_resolution.dart';
import '../lib/src/hooks/material_tools.dart';
import '../lib/src/hooks/web_artifacts.dart';
import '../lib/src/logging/log.dart';

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);

    final logger = createBuildLogger(pkgRootFilePath, "build.log");

    // Opt-in compilation of the CONSUMING APP's own .mat files (issue #399).
    //
    // Set `material_compilation` under `hooks.user_defines.thermion_dart` in
    // the app's pubspec.yaml to point thermion at user .mat sources; the
    // hook then compiles them with the version-matched, WebGPU-capable
    // matc/resgen pair for the HOST platform (downloaded from R2 into a
    // per-user cache) into the configured output directory. User materials
    // are runtime assets loaded from bytes
    // (FilamentApp.createMaterial(Uint8List)), NOT compiled into the native
    // library — thermion's own materials stay the committed blobs under
    // native/include/material/.
    //
    // One exception: `link_generated: true` also compiles the emitted .c
    // files straight into libthermion_dart below (the same mechanism as
    // thermion's own materials), native builds only.
    //
    // A matcId (Filament tag + thermion_dart version + host platform/arch,
    // plus the downloaded matc binary's sha256, recorded separately) in
    // <output>/.thermion-materials.json makes repeat builds a no-op and
    // forces a FULL rebuild whenever the toolchain changes, even if no
    // .mat changed. Absent define -> nothing happens. Present but broken
    // (bad paths, no network, matc failure) -> the build fails with an
    // actionable message; it is never silently skipped.
    //
    // Runs before the branches below so web builds (which return early)
    // compile their user materials too.
    final materialCompilationRaw = input.userDefines["material_compilation"];
    UserMaterialsResult? userMaterials;
    if (materialCompilationRaw != null) {
      final consumingPackageRoot = _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);
      if (consumingPackageRoot == null) {
        throw Exception(
          "material_compilation is configured but the consuming package root "
          "could not be resolved from ${input.outputDirectory}; inputs/output "
          "are resolved relative to it.",
        );
      }
      final config = parseMaterialCompilationConfig(materialCompilationRaw, onLog: logger.warning);
      // Web builds have no CBuilder to link the generated .c into (their
      // material C is compiled into the wasm engine via CMakeLists), so
      // link_generated on a web build must fail loudly, not silently no-op.
      checkMaterialLinkingBuildable(buildCodeAssets: input.config.buildCodeAssets, config: config!);
      final hostArch = await detectHostArchitecture();
      final result = await compileUserMaterials(
        appRoot: Directory(consumingPackageRoot),
        config: config,
        filamentVersion: filamentVersion,
        packageVersion: await readPubspecVersion(Directory(pkgRootFilePath)),
        hostOS: Platform.operatingSystem,
        hostArch: hostArch ?? 'x64',
        toolsPin: _loadFilamentPin(packageRoot, logger),
        download: (url, destination) => _downloadWithRetry(url.toString(), destination, logger),
        onLog: logger.info,
      );
      userMaterials = result;
      // Include discovery directories, transitive includes and generated files
      // in runner invalidation; internal manifest checks cannot run otherwise.
      output.dependencies.addAll(result.dependencies);
      output.dependencies.add(File(path.join(pkgRootFilePath, 'pubspec.yaml')).uri);
      output.dependencies.add(File(path.join(pkgRootFilePath, filamentPinFileName)).uri);
    }

    final rawMaterialsDefine = input.userDefines['materials'];
    final selectedMaterials = selectBuiltInMaterials(rawMaterialsDefine, onWarning: logger.warning);

    // Detect the rendering backend early — it affects which R2 artifact we
    // download, which static libs we link, which web engine variant we
    // fetch, and which material variant we compile. Resolved before the web
    // branch below so web builds honor it too.
    //
    // The "backend" user define selects the material/shader variant:
    //   "native"  (default) — per-platform GLSL/SPIR-V/MSL set: Metal on
    //                         iOS/macOS, Vulkan+OpenGL on Android and desktop
    //   "webgpu"            — WebGPU only (WGSL). Enables native Dawn linking.
    //   "webgl2"            — WebGL2 only (GLSL). Web-only, smallest variant.
    //   "hybrid"            — WebGL2 + WebGPU combined (GLSL + WGSL). Web-only,
    //                         enables runtime backend selection.
    //
    // It accepts either a string (today's form — a global fallback applied to
    // every target OS) or a map keyed by target OS incl. web:
    //   backend: {web: webgpu, macos: native}
    // A per-OS entry wins; uncovered targets fall back to "native".
    //
    // Legacy spelling kept for older pubspecs: `webgpu: true` (bool or
    // string) maps to backend: "webgpu" when no explicit backend applies.
    final targetOSName = input.config.buildCodeAssets
        ? input.config.code.targetOS.toString().split('.').last.toLowerCase()
        : 'web';
    final backendResolution = resolveBackendUserDefine(
      raw: input.userDefines["backend"],
      targetOS: targetOSName,
      legacyWebgpu: input.userDefines["webgpu"],
    );
    for (final warning in backendResolution.warnings) {
      logger.warning(warning);
    }
    final backend = backendResolution.backend;

    // Compile-time feature opt-outs:
    //   features: { gltf: false, ktx: false, image_decoding: false }
    // Opt-out — absent key = enabled, so every existing app builds exactly as
    // before. Resolved here, before the web branch, so both branches see it;
    // the hook rejects gltf:true with a decoder off.
    final features = resolveFeatures(input.userDefines['features'], onWarning: logger.warning);

    if (!input.config.buildCodeAssets) {
      logger.info("buildCodeAssets is false, assumed to be building for web");
      // Web engines are prebuilt with every feature (a zip per subset would
      // multiply the published variants); the native-only switches are parsed
      // and validated above, then reported rather than silently ignored.
      if (anyFeatureDisabled(features)) {
        logger.warning(
          "web engines are prebuilt with all features; features.* only affects "
          "native builds (features.gltf: ${features.gltf}, features.ktx: ${features.ktx}, "
          "features.image_decoding: ${features.imageDecoding})",
        );
      }
      final webDir = _findWebDirectory(input, logger);
      if (webDir == null) {
        if (selectedMaterials.isNotEmpty) {
          throw MaterialToolsError(
            'Could not locate the app’s web/ directory. Set web_directory under '
            'hooks.user_defines.thermion_dart in the workspace pubspec.yaml.',
          );
        }
        return;
      }
      final engineDir = await _resolveWebEngine(input, logger, backend);
      output.dependencies.add(input.packageRoot.resolve('native/web/web.version'));
      await publishWebMaterials(
        root: Directory.fromUri(input.packageRoot),
        engineDir: engineDir,
        webDir: webDir,
        materials: selectedMaterials,
        // The resolved backend also picks the material variant embedded
        // into the staged engine (WGSL/GLSL/both).
        backend: backend,
        download: (url, destination) => _downloadWithRetry(url.toString(), destination, logger),
        onLog: logger.info,
        addDependency: output.dependencies.add,
      );
      return;
    }

    // Escape hatch for running pure-Dart tooling in this package — e.g.
    // `bin/download_web.dart`, which only fetches prebuilt artifacts over HTTP
    // and uses no native code — without paying for a host C++ build (and without
    // needing a C++ toolchain on the runner at all). `dart run` always resolves
    // this package's native assets and would otherwise fire the CBuilder below.
    // Set `skip_native_build: true` under `hooks.user_defines.thermion_dart` in
    // the *consuming* package's pubspec.yaml: CLI defines aren't supported, and
    // env vars aren't forwarded into the hook subprocess (it gets a curated
    // PATH/HOME-only environment). Placed after the web branch above so a web
    // build still downloads its artifacts. Produces no code assets, so only safe
    // for invocations that need no native library.
    if (input.userDefines["skip_native_build"] == true) {
      logger.info("skip_native_build userDefine is set; skipping host native build");
      return;
    }

    logger.info(input.assets.encodedAssets.keys.toList());

    final config = input.config;

    logger.info("Config : ${input.config}");

    // Most users will only need release builds of Filament.
    // Debug builds are probably only relevant if you're a package developer debugging an internal Filament issue.
    // Also note that there are known driver issues with Android debug builds, e.g.:
    // https://github.com/google/filament/issues/7162
    // (these aren't present in Filament release builds).
    // However, if you know what you're doing, you can change "mode" to "debug" in the
    // `hooks` section of pubspec.yaml.
    var buildMode = BuildMode.release;

    if (input.userDefines["mode"] == "debug") {
      buildMode = BuildMode.debug;
    }

    final packageName = input.packageName;
    final outputDirectory = input.outputDirectory;

    final targetOS = config.code.targetOS;

    final targetArchitecture = config.code.targetArchitecture;

    logger.info("""
packageRoot : $packageRoot
outputDirectory : ${outputDirectory.path}
""");

    // Extract consuming package root for plugin support
    final consumingPackageRoot = _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);

    var platform = targetOS.toString().toLowerCase();

    logger.info("Building Thermion for ${targetOS} in mode ${buildMode.name}");

    // Native WebGPU (Dawn) opt-in: a resolved backend of "webgpu" (from the
    // per-OS map, the global string, or the legacy `webgpu: true` spelling).
    // Resolved above, before the web branch, so getLibDir below can download
    // the -webgpu suffixed zip from R2 instead of the canonical artifact.
    final webgpuEnabled = backend == "webgpu";

    final isIOSSimulator = targetOS == OS.iOS && config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator;

    // Runtime material compilation (filamat). Opt-in because it bakes
    // glslang/SPIRV-Tools into libthermion_dart, adding tens of MB. See the
    // runtime_materials section in README.md.
    //
    // Set `runtime_materials: true` under hooks.user_defines.thermion_dart in
    // the consuming app's pubspec.yaml.
    final runtimeMaterialsRaw = input.userDefines["runtime_materials"];
    var runtimeMaterials = false;
    if (runtimeMaterialsRaw == true ||
        runtimeMaterialsRaw == "true" ||
        runtimeMaterialsRaw == 1 ||
        runtimeMaterialsRaw == "1") {
      runtimeMaterials = true;
    } else if (runtimeMaterialsRaw != null &&
        runtimeMaterialsRaw != false &&
        runtimeMaterialsRaw != "false" &&
        runtimeMaterialsRaw != 0 &&
        runtimeMaterialsRaw != "0") {
      logger.warning(
        "Ignoring unrecognized runtime_materials value '$runtimeMaterialsRaw' "
        "(expected true or false); continuing without runtime material compilation.",
      );
    }
    final defines = <String, String?>{};
    if (runtimeMaterials) {
      logger.info("runtime_materials enabled; linking matp + filamat for runtime material compilation");
      defines["THERMION_ENABLE_RUNTIME_MATERIALS"] = "1";
    }

    // Disabled features pass an explicit 0; ThermionFeatures.h defaults every
    // switch to 1, so an all-default build's compile command is IDENTICAL to
    // today's (keeps the CBuilder build identity, and cache, unchanged).
    if (anyFeatureDisabled(features)) {
      logger.info(
        "Feature opt-outs: gltf=${features.gltf} ktx=${features.ktx} "
        "image_decoding=${features.imageDecoding}",
      );
      defines.addAll(disabledFeatureDefines(features));
    }

    final libResult = await getLibDir(
      packageRoot,
      targetOS,
      targetArchitecture,
      logger,
      buildMode,
      isIOSSimulator: isIOSSimulator,
      webgpuEnabled: webgpuEnabled,
    );
    var libDir = libResult.libDir.path;
    // Version-matched Filament headers extracted from the same R2 artifact as
    // the libraries (see getLibDir). Expressed relative to the package root to
    // match the convention of the other includeDirs entries.
    final artifactIncludeRel = path.relative(libResult.includeDir.path, from: pkgRootFilePath);

    var sources = Directory(path.join(pkgRootFilePath, "native", "src"))
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((f) {
          // Only check path relative to package root for exclusions
          final relativePath = path.relative(f, from: pkgRootFilePath);
          return !(relativePath.contains("CMakeLists") ||
              relativePath.contains("main.cpp") ||
              relativePath.contains("build"));
        })
        .toList();

    if (targetOS != OS.windows) {
      sources = sources.where((p) => !p.contains("windows") && !p.contains("d3d")).toList();
    }

    if (targetOS != OS.linux) {
      sources = sources.where((p) => !p.contains("linux")).toList();
    }

    // iOS is Metal-only — exclude Vulkan-utility sources whose symbols
    // resolve through `bluevk` (which iOS does not link). Without this
    // exclusion, linking fails with "Undefined symbols: bluevk::vk*".
    // See native/src/vulkan/{VulkanUtils,BaseVulkanTexture}.cpp.
    if (targetOS == OS.iOS) {
      sources = sources.where((p) => !p.contains("vulkan")).toList();
    }

    // Material source paths — platform-specific variants.
    // Each material has per-platform native variants (_apple, _android,
    // _desktop, _opengl, _vulkan) plus _webgpu, _web_webgl, and
    // _web_combined variants, all with identical C symbols. The build hook
    // compiles exactly one, resolved by resolveMaterialBackend:
    //  - the "materials.backends" user define (per-OS backend subsets, e.g.
    //    { android: [vulkan] } → _vulkan),
    //  - else the "backend" user define (webgpu/webgl2/hybrid → their
    //    variants, incl. native Dawn),
    //  - else the target OS default (Apple = Metal, Android = Vulkan+GL,
    //    desktop Linux/Windows = Vulkan+GL — both GL-capable platforms keep
    //    runtime backend selection working).
    final backendsConfig = rawMaterialsDefine is Map<String, dynamic>
        ? rawMaterialsDefine["backends"] as Map<String, dynamic>?
        : null;
    final materialResolution = resolveMaterialBackend(
      backendsConfig: backendsConfig,
      targetOS: targetOSName,
      backendOverride: backend == "native" ? null : backend,
    );
    for (final warning in materialResolution.warnings) {
      logger.warning(warning);
    }
    final materialSuffix = materialResolution.suffix;

    // Add Dart API DL for port-based frame scheduling (hot restart safe)
    sources.add(path.join(pkgRootFilePath, "native", "include", "dart", "dart_api_dl.c"));

    logger.info("Sources : $sources");

    var libs = [
      // Windows has no platform block below that adds its system import
      // libraries, and it links through CBuilder's `libraries` (see the
      // CBuilder call below) rather than #pragma comment(lib) directives.
      // Keeping the entries here makes this list the single source of truth
      // for every platform; ThermionWin32.h only includes ThermionFeatures.h.
      if (targetOS == OS.windows) ...["Shlwapi", "opengl32", "gdi32", "user32", "shell32", "dwmapi", "comctl32"],
      "filament",
      // macOS adds bluegl/bluevk in its platform block below; Windows links
      // them explicitly here (Linux resolves them from its own block).
      if (targetOS == OS.windows) ...["bluevk", "bluegl"],
      "backend",
      // matp: the .mat parser behind matc, used by
      // MaterialCompiler_compileMaterialPackage. Opt-in with the same
      // runtime_materials flag (never needed by debug/Linux's filamat-only
      // uses). Must come BEFORE filamat: matp references
      // filamat::MaterialBuilder, and GNU ld resolves archives left to right.
      if (runtimeMaterials) "matp",
      // Runtime material compilation (filamat::MaterialBuilder). Opt-in via
      // the `runtime_materials` user define; see the block that parses it
      // above. Release builds link it only when enabled (it would otherwise
      // be dead weight — tens of MB of glslang/SPIRV-Tools), with two
      // exceptions that must ALWAYS link it:
      // - debug: filament's debug archives ship libmatdbg.a, whose
      //   ShaderReplacer references filamat::Chunk.
      // - Linux: the Linux archives deliberately exclude libzstd.a
      //   (scripts/build_linux.sh — "bundled in Filament already"), so the
      //   combined filamat archive is the only zstd provider for
      //   basis_transcoder/MaterialParser/gltfio (ZSTD_* symbols).
      if (runtimeMaterials || targetOS == OS.linux || (buildMode == BuildMode.debug && targetOS != OS.windows))
        "filamat",
      // libfilamat.a references SHADERS_PACKAGE etc. from libshaders.a
      // (the generated shader-common chunks CodeGenerator emits into every
      // material). On Linux, "shaders" was already linked for gltfio; other
      // platforms only need it when runtime_materials pulls the CodeGenerator
      // in (matdbg's filamat use is Chunk-only and doesn't reach it).
      if (runtimeMaterials && targetOS != OS.linux) "shaders",
      if (targetOS == OS.linux) "shaders",
      // Windows splits filamat's shader-compiler dependencies into separate
      // .lib files; filamat.lib alone leaves them unresolved.
      if (runtimeMaterials && targetOS == OS.windows) ...[
        "OSDependent",
        "glslang",
        "SPIRV",
        "SPIRV-Tools",
        "SPIRV-Tools-opt",
        "spirv-cross-core",
        "spirv-cross-glsl",
        "spirv-cross-msl",
      ],
      "utils",
      // Android links Filament's Perfetto tracing archive. utils is always
      // built with src/android/Systrace.cpp on Android, and its debug object
      // references perfetto::internal::InProcessTracingBackend::GetInstance().
      // build_android.sh bundles libperfetto.a in both release and debug zips;
      // linking it unconditionally is harmless when unused (static archives
      // only yield members needed to resolve references). Without it the
      // shared library keeps an undefined perfetto symbol and dlopen fails at
      // runtime: "cannot locate symbol ...InProcessTracingBackend...".
      if (targetOS == OS.android) "perfetto",
      "filabridge",
      // gltfio_core + its transitive archives (dracodec, uberzlib, the
      // ubershader blob) are only linked when glTF support is enabled; with
      // features.gltf: false the Thermion wrappers compile to stubs
      // (THERMION_ENABLE_GLTF=0, native/include/ThermionFeatures.h) and an
      // unguarded gltfio reference is a LINK error here, not a dlopen failure
      // on a device.
      if (features.gltf) "gltfio_core",
      // The full "gltfio" archive (createFilamentMaterialProvider, the
      // filamat-backed glTF material compiler) was listed on desktop but
      // nothing in Thermion references it (only gltfio_core symbols are
      // used), so it never contributed a byte. Dropped rather than gated.
      "filament-iblprefilter",
      "image",
      "filaflat",
      if (features.gltf) "dracodec",
      // Windows-only gltfio dependencies (meshopt extension, tangents).
      if (features.gltf && targetOS == OS.windows) ...["meshoptimizer", "mikktspace"],
      "ibl",
      if (features.ktx) "ktxreader",
      "z",
      if (features.imageDecoding) "stb",
      if (features.gltf) "uberzlib",
      // Linked DIRECTLY (not via the combined filamat archive): filament's
      // combine-static-libs.sh appends members with `ar -qc`, which does not
      // regenerate the archive symbol table, so smolv members bundled there
      // are invisible to linker symbol lookup. Keep it AFTER "filamat" above
      // (leaf library; left-to-right archive resolution).
      "smol-v",
      if (features.ktx) "basis_transcoder",
      if (features.gltf) "uberarchive",
      // Filament 1.75.0's libfilamat.a references external ZSTD_* symbols
      // (e.g. ZSTD_getFrameContentSize). Desktop/iOS/Android have no guarantee
      // of a system libzstd, so link the static libzstd.a bundled in the R2
      // artifact for every platform except Linux, which uses the system
      // libzstd.so. Without this, Android dlopen fails at runtime with
      // "cannot locate symbol ZSTD_getFrameContentSize" (Android ships no
      // libzstd), and the libzstd.a must be present in the Android zip — see
      // scripts/zip_android.sh.
      if (targetOS != OS.linux) "zstd",
      if (targetOS == OS.windows) ...["vulkan-1", "dxgi", "d3d11"],
      "geometry",
      // Debug builds of Filament enable the Material Debug Server and Frame
      // Graph viewer (build.sh -d/-t -> FILAMENT_ENABLE_MATDBG/FGVIEWER), so
      // the debug zips for desktop (macOS/Linux) and Android ship
      // libmatdbg.a/libfgviewer.a and their filament archives reference them
      // (e.g. filament::matdbg::DebugServer). Without these the debug shared
      // library keeps undefined matdbg/fgviewer symbols and dlopen fails at
      // runtime, just like the perfetto case above. iOS debug never enables
      // them (its cmake invocation passes neither option); Windows links
      // libraries via the `libraries` list below instead.
      if ({OS.macOS, OS.android}.contains(targetOS) && buildMode == BuildMode.debug) ...["matdbg", "fgviewer"],
    ];

    // Keep Linux's matdbg/fgviewer archives separate from the main list. This
    // was originally required to keep them outside a whole-archive group:
    // both archives bundle civetweb, and force-loading both produces duplicate
    // mg_* definitions. They now use normal archive semantics in `libraries`
    // below, which extracts only the members needed by Filament. See the-c8d3.
    final linuxDebugLibs = (targetOS == OS.linux && buildMode == BuildMode.debug) ? ["matdbg", "fgviewer"] : <String>[];

    if (targetOS == OS.windows) {
      // CBuilder emits the `libraries` list below as `<name>.lib` inputs
      // after /link, with libDir supplied via libraryDirectories. Windows used
      // to get these from #pragma comment(lib) in ThermionWin32.h; moving them
      // here keeps the link list (and its feature conditions) in one place.
      libDir = Directory(libDir).uri.toFilePath(windows: targetOS == OS.windows);
    }

    if ((input.userDefines["tracing"] as String?)?.isNotEmpty == true) {
      logger.info("Enabling tracing");
      defines["ENABLE_TRACING"] = "1";
    }

    // Opt-in native WebGPU support. Requires a Filament build with
    // FILAMENT_SUPPORTS_WEBGPU=ON whose Dawn static libs are co-located
    // with the regular filament libs in libDir. Intended for local
    // testing only — shipping native builds should continue to use
    // Metal/Vulkan/OpenGL. (webgpuEnabled is detected above, before
    // getLibDir, so the -webgpu artifact is downloaded.)
    if (webgpuEnabled) {
      logger.info("Enabling native WebGPU (Dawn)");
      defines["THERMION_SUPPORTS_WEBGPU"] = "1";
      // libwebgpu_dawn.a is a "monolithic" archive built by Dawn's
      // `webgpu_dawn` target — it already includes dawn_native,
      // dawn_proc, dawn_common, dawn_platform, dawn_wire AND the full
      // Tint compiler stack. Linking the granular libs alongside it
      // produces multiple-definition errors. Use the monolith alone;
      // add abseil because it's required by webgpu_dawn but exported
      // as a separate archive.
      libs.addAll(<String>["webgpu_dawn", "abseil"]);
    }

    // Check for plugin configuration. Plugin sources are compiled directly
    // into libthermion_dart and can call RegisterPlugin during initialization.
    // Prebuilt libraries currently use ordinary linker semantics; static
    // archives whose only effect is an automatic RegisterPlugin initializer
    // are not supported yet. Supporting those in future may require a scoped
    // --whole-archive group (or an explicit referenced registration symbol),
    // rather than force-loading every Thermion/Filament dependency.
    final pluginConfigs = input.userDefines["plugins"] as List<dynamic>?;

    logger.info("Defines : ${defines}");

    final flags = <String>[]; //"-fsanitize=address"];

    // Include directories:
    //  - `native/include`     : Thermion's OWN headers (c_api/, components/,
    //                           ...) still committed in-tree.
    //  - `artifactIncludeRel` : the Filament C++ headers, sourced from the
    //                           version-matched R2 artifact extracted by
    //                           getLibDir() (under .dart_tool/.../include).
    //                           This replaces a hand-committed Filament header
    //                           tree that drifted out of sync with the linked
    //                           libraries on version bumps. `<filament/...>`,
    //                           `<utils/...>`, `<backend/...>` and
    //                           `<gltfio/materials/uberarchive.h>` all resolve
    //                           from this flat root.
    final includeDirs = <String>['native/include', artifactIncludeRel];

    // Process plugins after flags and includeDirs are declared
    if (pluginConfigs != null && consumingPackageRoot != null) {
      await _processDeclarativePlugins(
        pluginConfigs,
        sources,
        libs,
        defines,
        flags,
        includeDirs,
        targetOS,
        logger,
        consumingPackageRoot,
      );
    }

    // Value-macro convention (ThermionFeatures.h): every built-in material key
    // gets an explicit =0/=1 define, so the native guards are `#if` value
    // checks and no translation unit can fall back to presence semantics.
    for (final material in BuiltInMaterial.values) {
      defines['${material.key.toUpperCase()}_ENABLED'] = selectedMaterials.contains(material) ? '1' : '0';
    }
    // unlit_fallback is hook-managed, not user-selectable: it is
    // compiled and enabled further below, only when features.gltf is
    // false. Every build still gets an explicit value macro.
    defines['UNLIT_FALLBACK_ENABLED'] = '0';
    // matc/resgen target set for the compiled material variants, resolved by
    // the material backend suffix (see resolveMaterialBackend above).
    final materialBackends = switch (materialSuffix) {
      '_apple' => ['metal'],
      '_opengl' || '_web_webgl' => ['opengl'],
      '_vulkan' => ['vulkan'],
      '_webgpu' => ['webgpu'],
      '_web_combined' => ['opengl', 'webgpu'],
      _ => ['opengl', 'vulkan'],
    };

    if (selectedMaterials.isNotEmpty) {
      final builtIns = await compileBuiltInMaterials(
        root: Directory.fromUri(packageRoot),
        materials: selectedMaterials,
        resgen: true,
        backends: materialBackends,
        download: (url, destination) => _downloadWithRetry(url.toString(), destination, logger),
        onLog: logger.info,
        addDependency: output.dependencies.add,
      );
      for (final material in selectedMaterials) {
        final outputDir = builtIns[material]!;
        linkGeneratedIntoNativeBuild(
          sources: sources,
          includeDirs: includeDirs,
          linkedSources: [File(path.join(outputDir.path, '${material.resgenPrefix}.c'))],
          outputDir: outputDir,
        );
      }
    }

    // Unlit fallback for procedural-only builds. With features.gltf: false
    // there is no gltfio ubershader provider, so the unlit material that
    // procedural code requests through createUnlitMaterialInstance()
    // (explicit materials for createGeometry, bounding-box helpers,
    // TextureProjection) is a small precompiled package instead: compiled
    // here, ONLY when gltf is off, with the same version-matched matc/resgen
    // pipeline as the built-in helpers (never by filamat at runtime).
    // Default builds are untouched — no extra compiler step, no extra
    // bytes. Dart builds the package through
    // Material_createBuiltIn(BUILT_IN_UNLIT_FALLBACK) (the
    // UNLIT_FALLBACK_ENABLED case in TMaterialInstance.cpp) and sets
    // baseColorFactor to opaque white on each instance.
    if (!features.gltf) {
      logger.info("features.gltf: false -> compiling the precompiled unlit fallback material");
      final fallbackDir = await compileUnlitFallbackMaterial(
        root: Directory.fromUri(packageRoot),
        backends: materialBackends,
        download: (url, destination) => _downloadWithRetry(url.toString(), destination, logger),
        onLog: logger.info,
        addDependency: output.dependencies.add,
      );
      linkGeneratedIntoNativeBuild(
        sources: sources,
        includeDirs: includeDirs,
        linkedSources: [File(path.join(fallbackDir.path, '$unlitFallbackMaterialKey.c'))],
        outputDir: fallbackDir,
      );
      defines['UNLIT_FALLBACK_ENABLED'] = '1';
    }

    // link_generated: compile the user's generated material .c files into
    // libthermion_dart too — the exact same mechanism as thermion's own
    // materials above (appended to `sources`), with the output directory on
    // `includeDirs` so each .c resolves its own `#include "x.h"`. The files
    // were emitted at the top of this hook, before any CBuilder work, and
    // only the set the materials manifest vouches for is linked. Must run
    // before CBuilder.library is constructed below (sources/includeDirs are
    // read there), and after the platform source filters so a path that
    // happens to contain e.g. "windows" is not filtered out.
    if (userMaterials != null && userMaterials.linkedSources.isNotEmpty) {
      final linkedCount = linkGeneratedIntoNativeBuild(
        sources: sources,
        includeDirs: includeDirs,
        linkedSources: userMaterials.linkedSources,
        outputDir: userMaterials.outputDir,
      );
      logger.info(
        "link_generated: compiling $linkedCount generated material source(s) "
        "into $packageName (${userMaterials.linkedSources.map((f) => path.basename(f.path)).join(', ')})",
      );
    }

    var frameworks = [];

    if (targetOS != OS.windows) {
      flags.add('-fno-exceptions');
      flags.add('-stdlib=libc++');
      if (!flags.any((f) => f.contains("-std=c++"))) {
        // Dawn's headers (dawn/webgpu_cpp.h and friends) use C++20 library
        // features (std::span), so the native WebGPU opt-in compiles the
        // glue sources as C++20. Default builds stay on C++17; Windows
        // already passes /std:c++20 unconditionally below.
        flags.add(webgpuEnabled ? '-std=c++20' : '-std=c++17');
      }
    } else {
      defines["WIN32"] = "1";
      defines["_DLL"] = "1";
      defines["_HAS_EXCEPTIONS"] = "0";
      if (buildMode == BuildMode.debug) {
        defines["_DEBUG"] = "1";
      } else {
        defines["RELEASE"] = "1";
        defines["NDEBUG"] = "1";
      }
      flags.addAll([
        "/std:c++20",
        "/EHs-c-",
        if (buildMode == BuildMode.debug) ...["/MDd", "/Zi"],
        if (buildMode == BuildMode.release) "/MD",
        // /VERBOSE is a linker option, not a compiler one — cl.exe parses it
        // as the deprecated /V<string> and emits warning D9035. If the
        // verbose link map is ever needed for diagnostics, pass it after
        // native_toolchain_c's own /link separator (see libraryDirectories
        // / linkerOptions paths in run_cbuilder.dart).
        ...defines.keys.map((k) => "/D$k=${defines[k]}").toList(),
      ]);
    }

    if (targetOS == OS.iOS) {
      frameworks.addAll(['Foundation', 'CoreGraphics', 'QuartzCore', 'GLKit', "Metal", 'CoreVideo', 'OpenGLES']);
    } else if (targetOS == OS.macOS) {
      frameworks.addAll(['Foundation', 'CoreVideo', 'Cocoa', 'Metal', 'QuartzCore']);

      libs.addAll(["bluegl", "bluevk"]);
    } else if (targetOS == OS.android) {
      final versionScript = File(path.join(pkgRootFilePath, "native", "android", "thermion_dart.map"));
      output.dependencies.add(versionScript.uri);

      libs.addAll(["GLESv3", "EGL", "bluevk", "dl", "android"]);
      flags.addAll([
        "-Wl,-z,max-page-size=16384",
        "-fvisibility=hidden",
        // All static archives are implementation details of
        // libthermion_dart.so. The version script retains only C entrypoints
        // explicitly marked with default visibility.
        "-Wl,--exclude-libs,ALL",
        "-Wl,--version-script=${versionScript.path}",
      ]);
    } else if (targetOS == OS.linux) {
      libs.addAll(["bluevk", "bluegl", "drm", "EGL", "GL", "gbm"]);
      // The -webgpu archives compile Filament's WebGPU backend with X11
      // surface support (only the host-tools build disables DAWN_USE_X11 —
      // scripts/build_linux.sh). libbackend.a's WebGPUPlatformLinux dlopens
      // libX11 at runtime but calls XGetWindowAttributes directly, so the
      // link line needs -lX11; without it the -Wl,-z,defs link below fails
      // with "undefined reference to XGetWindowAttributes" (the machine
      // needs libx11-dev for the libX11.so symlink). Dawn resolves its own
      // X11/XCB entry points dynamically (libX11.so.6 / libX11-xcb.so.1),
      // so no xcb library belongs on the link line.
      if (webgpuEnabled) {
        libs.add("X11");
      }
      flags.add("-I/usr/include/libdrm");
    }

    if ({OS.linux, OS.macOS}.contains(targetOS) && buildMode == BuildMode.debug) {
      flags.addAll(["-g", "-O0"]);
    }

    if (targetOS == OS.linux) {
      flags.add("-Wl,--export-dynamic");
      // Dawn's webgpu_dawn monolithic archive is built without RTTI, so
      // Thermion's WebGPUPlatform subclasses must match it to keep vtables
      // consistent. The canonical Filament artifacts are built with
      // FILAMENT_ENABLE_RTTI=ON (scripts/build_linux.sh), so default
      // (non-WebGPU) builds keep RTTI enabled and only gate these flags on
      // the WebGPU opt-in.
      if (webgpuEnabled) {
        flags.add("-fno-rtti");
        // Dawn's webgpu_dawn monolithic archive bundles its own copy of
        // SPIRV-Tools, which collides at link time with the SPIRV-Tools
        // objects that Filament's filamat bundles. Let the linker pick
        // one — both copies are compatible for symbol resolution and we
        // don't care which gets exported.
        flags.add("-Wl,--allow-multiple-definition");
      }
    }

    frameworks = frameworks.expand((f) => ["-framework", f]).toList();

    // Objective-C files must be compiled separately because CBuilder uses -x c++
    // which prevents clang from recognizing ObjC syntax.
    final objcSources = sources.where((s) => s.endsWith('.m')).toList();
    sources = sources.where((s) => !s.endsWith('.m')).toList();

    final objcObjectFiles = <String>[];
    if (objcSources.isNotEmpty && targetOS == OS.iOS) {
      final cc = config.code.cCompiler?.compiler.toFilePath() ?? 'clang';
      final archStr = targetArchitecture == Architecture.arm64 ? 'arm64' : 'x86_64';
      // Detect simulator vs device from the iOS config
      final isSimulator = config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator;
      final sdkName = isSimulator ? 'iphonesimulator' : 'iphoneos';
      final sdkPath = (await Process.run('xcrun', ['--sdk', sdkName, '--show-sdk-path'])).stdout.toString().trim();
      final targetTriple = isSimulator ? '$archStr-apple-ios-simulator' : '$archStr-apple-ios';

      for (final objcSource in objcSources) {
        final objFile = path.join(Directory.systemTemp.path, '${path.basenameWithoutExtension(objcSource)}.o');
        final result = await Process.run(cc, [
          '-x',
          'objective-c',
          '-target',
          targetTriple,
          '-mios-version-min=13.0',
          '-isysroot',
          sdkPath,
          '-fPIC',
          '-fobjc-arc',
          '-O3',
          ...includeDirs.map((d) => '-I${path.join(pkgRootFilePath, d)}'),
          '-c',
          objcSource,
          '-o',
          objFile,
        ]);
        if (result.exitCode != 0) {
          logger.severe('Failed to compile ObjC source $objcSource:\n${result.stderr}');
          throw Exception('ObjC compilation failed for $objcSource');
        }
        objcObjectFiles.add(objFile);
        logger.info('Compiled ObjC source: $objcSource -> $objFile');
      }

      // Create a static library from the ObjC object files so it can be
      // linked without -x c++ interfering (ar archives are recognized by extension).
      if (objcObjectFiles.isNotEmpty) {
        final objcLib = path.join(Directory.systemTemp.path, 'libthermion_objc.a');
        final arResult = await Process.run('ar', ['rcs', objcLib, ...objcObjectFiles]);
        if (arResult.exitCode != 0) {
          logger.severe('Failed to create ObjC static library:\n${arResult.stderr}');
          throw Exception('ar failed');
        }
        objcObjectFiles.clear();
        objcObjectFiles.add(objcLib);
        logger.info('Created ObjC static library: $objcLib');
      }
    }

    // Per-process name: concurrent builds on one machine must not share (and overwrite) one source list.
    var srcs = File(Directory.systemTemp.path + Platform.pathSeparator + "thermion_sources_$pid.rsp");
    srcs.writeAsStringSync(sources.join("\n"));

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      // All of Thermion's C++ code, including the prebuilt Filament archives,
      // is linked into this one shared library on Android. Keep libc++ in that
      // library rather than shipping a separate libc++_shared.so code asset.
      cppLinkStdLib: targetOS == OS.android ? 'c++_static' : null,
      assetName: 'thermion_dart.dart',
      sources: targetOS == OS.windows ? [] : sources,
      includes: platform == "windows" ? [] : includeDirs,
      defines: platform == "windows" ? {} : defines,
      flags: [
        if (targetOS == OS.macOS) '-mmacosx-version-min=13.0',
        if (targetOS == OS.iOS) '-mios-version-min=13.0',
        if (objcObjectFiles.isNotEmpty) ...['-lthermion_objc', '-L${Directory.systemTemp.path}'],
        ...flags,
        ...frameworks,
        // Keep every non-Linux link command unchanged. GNU ld processes
        // static archives from left to right, and CBuilder emits flags before
        // the source files, so Linux archives use `libraries` below instead.
        if (targetOS != OS.windows && targetOS != OS.linux) ...[
          ...libs.map((lib) => "-l$lib"),
          if (targetOS != OS.android) ...["-lc++", ""],
          "-L$libDir",
        ],
        if (targetOS == OS.linux) "-L$libDir",
        if (targetOS == OS.linux) ...[
          '-Wl,--no-as-needed',
          // Shared-library links normally permit unresolved symbols. Make
          // Linux fail at link time instead of deferring the error to
          // dlopen, where missing archive dependencies are harder to trace.
          '-Wl,-z,defs',
        ] else if (targetOS != OS.windows && targetOS != OS.android)
          '-lc++',
        if (platform == "windows") ...[
          ...includeDirs.map((d) => "/I${path.join(pkgRootFilePath, d)}"),
          "@${srcs.uri.toFilePath(windows: true)}",
          // Library inputs (filament.lib, backend.lib, bluevk.lib, etc.) come
          // from the `libraries` list below, not from #pragma comment(lib)
          // directives in ThermionWin32.h. The linker still needs to know
          // WHERE to find those .lib files — that is wired via
          // `libraryDirectories: [libDir]`, which native_toolchain_c emits
          // after its own /link separator (run_cbuilder.dart). Adding a second
          // /link here puts cl.exe's auto-generated /LD and /Fe: AFTER our
          // separator, where LINK ignores them as LNK4044 — the resulting
          // binary has no /DLL and no entry point, failing with LNK1561.
        ],
      ],
      libraryDirectories: [libDir],
      // CBuilder emits libraries after the source files. This lets GNU ld
      // extract only referenced archive members instead of forcing every
      // member into libthermion_dart.so with --whole-archive. Keep the full
      // existing library set; the second pass resolves Filament's circular
      // archive references. GL, EGL, and libm also belong after the objects
      // so --as-needed cannot discard them prematurely.
      libraries: targetOS == OS.linux
          ? [...libs, ...linuxDebugLibs, 'GL', 'EGL', ...libs, ...linuxDebugLibs, 'm']
          : targetOS == OS.windows
          ? libs
          : const [],
    );

    try {
      await cbuilder.run(input: input, output: output, logger: logger);
    } finally {
      try {
        srcs.deleteSync();
      } catch (_) {}
    }

    output.metadata.addAll({"includeDirs": includeDirs.map((dir) => path.join(pkgRootFilePath, dir)).toList()});
    output.metadata.addAll({"outputDir": outputDirectory.path});

    if (targetOS == OS.windows) {
      var importLib = File(path.join(outputDirectory.path.substring(1).replaceAll("/", "\\"), "thermion_dart.lib"));

      output.assets.code.add(
        CodeAsset(
          package: packageName,
          name: "thermion_dart.lib",
          linkMode: DynamicLoadingBundled(),
          file: importLib.uri,
        ),
      );
    }
  });
}

/// Loads the shipped artifact pin (filament.libs.json at the package root).
/// Missing/malformed pins degrade to legacy artifact keys with a warning —
/// see lib/src/hooks/filament_artifacts.dart.
FilamentPin _loadFilamentPin(Uri packageRoot, Logger logger) {
  final file = File(path.join(packageRoot.toFilePath(windows: Platform.isWindows), filamentPinFileName));
  final warnings = <String>[];
  final pin = parseFilamentPin(file.existsSync() ? file.readAsStringSync() : null, warnings: warnings);
  for (final warning in warnings) {
    logger.warning(warning);
  }
  return pin;
}

const _maxRetries = 3;
const _connectionTimeout = Duration(seconds: 30);
const _responseTimeout = Duration(minutes: 5);

/// Download [url] to [destination] with retry and exponential backoff.
///
/// Retries up to [_maxRetries] times on network errors, non-200 responses,
/// and empty downloads. Waits 2^attempt seconds between attempts.
Future<void> _downloadWithRetry(String url, File destination, Logger logger) async {
  for (var attempt = 1; attempt <= _maxRetries; attempt++) {
    try {
      final client = HttpClient()..connectionTimeout = _connectionTimeout;
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(_responseTimeout);

      if (response.statusCode != 200) {
        await response.drain<void>();
        throw Exception("HTTP ${response.statusCode} downloading $url");
      }

      await response.pipe(destination.openWrite());

      if (!destination.existsSync() || destination.lengthSync() == 0) {
        throw Exception("Downloaded file is empty: ${destination.path}");
      }

      logger.info("Download succeeded on attempt $attempt");
      return;
    } catch (e) {
      // Clean up partial download.
      if (destination.existsSync()) {
        destination.deleteSync();
      }
      if (attempt == _maxRetries) {
        logger.severe("Download failed after $_maxRetries attempts: $e");
        rethrow;
      }
      final delay = Duration(seconds: 1 << attempt); // 2s, 4s, 8s
      logger.warning(
        "Download attempt $attempt/$_maxRetries failed ($e), "
        "retrying in ${delay.inSeconds}s...",
      );
      await Future<void>.delayed(delay);
    }
  }
}

//
// Download precompiled Filament libraries for the target platform from Cloudflare.
//
// The downloaded zip also contains a complete, version-matched Filament header tree
// under `include/`, which is extracted alongside the libraries. We return that include
// directory so consumers compile against headers that always match the linked
// libraries (rather than a hand-committed tree that drifts on version bumps).
//
Future<({Directory libDir, Directory includeDir})> getLibDir(
  Uri packageRoot,
  OS targetOS,
  Architecture targetArchitecture,
  Logger logger,
  BuildMode buildMode, {
  bool isIOSSimulator = false,
  bool webgpuEnabled = false,
}) async {
  var platform = targetOS.toString().toLowerCase();

  final version = filamentVersion;

  // Use separate library directory for iOS simulator (arm64 simulator
  // libraries can't be lipo'd with arm64 device libraries).
  if (isIOSSimulator) {
    platform = "ios-simulator";
  }

  var mode = buildMode == BuildMode.debug ? "debug" : "release";

  // Content-addressed artifact resolution: a pinned entry in
  // filament.libs.json selects an immutable hash-suffixed zip (and its
  // full SHA-256 for download verification); unpinned entries fall back
  // to the legacy mutable key. See lib/src/hooks/filament_artifacts.dart.
  // Resolved AFTER the platform splits below so ios-simulator/linux-arm64
  // use their own pin entries.
  final pin = _loadFilamentPin(packageRoot, logger);

  var libDir = Directory(
    path.join(
      packageRoot.toFilePath(windows: Platform.isWindows),
      ".dart_tool",
      "thermion_dart",
      "lib",
      version,
      platform,
      mode,
    ),
  );

  if (platform == "android") {
    final archExtension = switch (targetArchitecture) {
      Architecture.arm => "armeabi-v7a",
      Architecture.arm64 => "arm64-v8a",
      Architecture.x64 => "x86_64",
      Architecture.ia32 => "x86",
      _ => throw FormatException('Invalid'),
    };
    libDir = Directory(path.join(libDir.path, archExtension));
  } else if (platform == "windows") {
    if (targetArchitecture != Architecture.x64) {
      throw Exception("Unsupported architecture : ${targetArchitecture}");
    }
  } else if (platform == "linux") {
    // Linux arm64 consumers fetch their own archive and use an
    // arch-scoped cache dir so the two never collide.
    if (targetArchitecture == Architecture.arm64) {
      platform = "linux-arm64";
      libDir = Directory(path.join(libDir.path, "arm64"));
    } else if (targetArchitecture != Architecture.x64) {
      throw Exception("Unsupported architecture for Linux: ${targetArchitecture}");
    }
  }

  // Resolve the artifact for the FINAL platform slug (post ios-simulator /
  // linux-arm64 split). Pinned artifacts get a hash-scoped cache directory:
  // flipping the pin lands in a fresh dir, so the old `success` token can
  // never mask new contents (and reverting the pin reuses the old cache).
  // Unpinned artifacts keep the exact legacy path — existing caches stay valid.
  // WebGPU (Dawn) builds download a different zip (-webgpu suffix); keep
  // their cache separate from the canonical artifact's.
  final artifact = resolveFilamentArtifact(version, platform, mode, pin, webgpu: webgpuEnabled);
  var cacheSuffix = artifact.cacheSuffix;
  if (webgpuEnabled) {
    cacheSuffix = '$cacheSuffix-webgpu';
  }
  if (cacheSuffix.isNotEmpty) {
    if (platform == 'android') {
      // Every ABI shares this zip's extraction root and success token.
      // Keep the ABI directory names exactly as packaged in the archive.
      libDir = Directory(path.join('${libDir.parent.path}$cacheSuffix', path.basename(libDir.path)));
    } else {
      libDir = Directory('${libDir.path}$cacheSuffix');
    }
  }

  logger.info("Searching for Filament libraries under ${libDir.path}");

  // WebGPU (Dawn) artifacts resolve against the same filament.libs.json pin
  // as the canonical ones (<platform>-webgpu/<variant> entries, published
  // under content-addressed keys by build-filament.yml + publish-filament-
  // to-r2.yml); an absent pin entry falls back to the legacy mutable
  // -webgpu suffixed key, exactly like unpinned canonical artifacts.
  final url = artifact.url;

  final filename = artifact.zipName;

  // We will write an empty file called success to the unzip directory after successfully downloading/extracting the prebuilt libraries.
  // If this file already exists, we assume everything has been successfully extracted and skip
  final unzipDir = platform == "android" ? libDir.parent.path : libDir.path;
  final successToken = File(path.join(unzipDir, "success"));
  final libraryZip = File(path.join(unzipDir, filename));

  if (libraryZip.existsSync()) {
    final zipBytes = await libraryZip.readAsBytes();
    final zipHash = md5.convert(zipBytes);
    logger.info("Existing library zip hash: $zipHash, size: ${zipBytes.length} bytes (${libraryZip.path})");
  }

  if (!successToken.existsSync()) {
    if (libraryZip.existsSync()) {
      libraryZip.deleteSync();
    }

    if (!libraryZip.parent.existsSync()) {
      libraryZip.parent.createSync(recursive: true);
    }

    logger.info(
      "Downloading prebuilt libraries for $platform/$mode from $url to ${libraryZip}, files will be unzipped to ${unzipDir}",
    );

    await _downloadWithRetry(url, libraryZip, logger);

    final downloadedBytes = await libraryZip.readAsBytes();
    final downloadedHash = md5.convert(downloadedBytes);
    logger.info(
      "Downloaded library zip hash: $downloadedHash, size: ${downloadedBytes.length} bytes (${libraryZip.path})",
    );

    // Content-addressed artifacts are verified against the pin's full
    // SHA-256 before extraction: a corrupt/truncated download (or a proxy
    // serving an error page with HTTP 200) must never be cached under the
    // success token. Legacy (unpinned) artifacts — canonical or -webgpu
    // suffixed — have no digest to check.
    final expectedSha = artifact.sha256;
    if (expectedSha != null) {
      final actualSha = sha256.convert(downloadedBytes).toString();
      if (actualSha != expectedSha) {
        libraryZip.deleteSync();
        throw Exception(
          "SHA-256 mismatch for $filename: pin expects $expectedSha, "
          "downloaded $actualSha. The artifact on R2 does not match "
          "$filamentPinFileName — re-publish it or fix the pin.",
        );
      }
      logger.info("SHA-256 verified against $filamentPinFileName");
    }

    final archive = ZipDecoder().decodeBytes(downloadedBytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File('${unzipDir}/$filename');
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        final d = Directory('${unzipDir}/$filename');
        await d.create(recursive: true);
      }
    }
    successToken.writeAsStringSync("SUCCESS");
  }

  // Some published debug artifacts (e.g. the v1.75.0 linux debug zip) were
  // built by a script bug that copied the bluevk headers into the *release*
  // target dir, so their include/ tree lacks bluevk/, vulkan/ and vk_video/
  // and any compile of <bluevk/BlueVK.h> fails (LinuxVulkanContext/
  // LinuxVulkanUtils under native/include/vulkan/linux/). Those headers are
  // build-mode-independent, so heal the cache by merging them in from the
  // release artifact of the same version. Checked outside the success-token
  // guard above so caches extracted from an already-broken zip are repaired
  // too. No-op once the artifact is re-uploaded with the headers present.
  // See the-c8d3.
  if (targetOS != OS.iOS && !File(path.join(unzipDir, 'include', 'bluevk', 'BlueVK.h')).existsSync()) {
    logger.warning(
      "include/bluevk/BlueVK.h is missing from the $platform/$mode artifact; "
      "fetching bluevk headers from the release artifact to repair the cache",
    );
    final releaseArtifact = resolveFilamentArtifact(version, platform, "release", pin);
    final releaseUrl = releaseArtifact.url;
    final releaseZip = File(path.join(Directory.systemTemp.path, 'thermion_bluevk_repair_${releaseArtifact.zipName}'));
    final releaseRequest = await HttpClient().getUrl(Uri.parse(releaseUrl));
    final releaseResponse = await releaseRequest.close();
    if (releaseResponse.statusCode != 200) {
      throw Exception("Release libraries not found at $releaseUrl (needed for missing bluevk headers)");
    }
    await releaseResponse.pipe(releaseZip.openWrite());
    final releaseBytes = await releaseZip.readAsBytes();
    // Same pin verification as the main download when the release artifact
    // is content-addressed.
    if (releaseArtifact.sha256 != null && sha256.convert(releaseBytes).toString() != releaseArtifact.sha256) {
      await releaseZip.delete();
      throw Exception(
        "SHA-256 mismatch for ${releaseArtifact.zipName} "
        "(bluevk repair download) — see $filamentPinFileName.",
      );
    }
    final releaseArchive = ZipDecoder().decodeBytes(releaseBytes);
    for (final file in releaseArchive) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name.startsWith('include/bluevk/') ||
          name.startsWith('include/vulkan/') ||
          name.startsWith('include/vk_video/')) {
        final f = File(path.join(unzipDir, name));
        await f.create(recursive: true);
        await f.writeAsBytes(file.content as List<int>);
      }
    }
    await releaseZip.delete();
    logger.warning("Repaired include/ with bluevk headers from $releaseUrl");
  }
  // The entire zip (libraries AND the `include/` header tree) is extracted to
  // `unzipDir`; for Android the per-arch libs live in a subdir but headers are
  // shared at the extraction root.
  return (libDir: libDir, includeDir: Directory(path.join(unzipDir, 'include')));
}

// R2 base URL for the web engine artifacts lives in
// lib/src/hooks/web_artifacts.dart (webR2BaseUrl), shared with its tests.

Directory? _findWebDirectory(BuildInput input, Logger logger) {
  final configuredPath = input.userDefines['web_directory'];
  if (configuredPath != null) {
    final uri = input.userDefines.path('web_directory');
    if (configuredPath is! String || configuredPath.trim().isEmpty || uri == null || uri.scheme != 'file') {
      throw MaterialToolsError('web_directory must be a path to the app’s existing web/ directory.');
    }
    final directory = Directory.fromUri(uri);
    if (!directory.existsSync()) {
      throw MaterialToolsError('web_directory does not exist: ${directory.path}');
    }
    return directory;
  }

  final root = _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);
  if (root == null) return null;
  final directory = Directory(path.join(root, 'web'));
  return directory.existsSync() ? directory : null;
}

Future<Directory> _resolveWebEngine(BuildInput input, Logger logger, String backend) async {
  final packageRoot = input.packageRoot.toFilePath(windows: Platform.isWindows);

  // The "web_variant" user define selects which prebuilt engine to fetch:
  //   unset / "worker" / "default" — the standard engine (render commands
  //                                dispatched to a worker thread)
  //   "main_thread"               — the main-thread engine (commands and
  //                                callbacks execute on the calling thread)
  // Unknown values warn and fall back to the default. See
  // lib/src/hooks/web_artifacts.dart (pure logic, unit-tested).
  //
  // With WebGL2, `runtime_materials: true` selects an engine with filamat
  // linked so apps can compile materials at runtime.
  //
  // The resolved `backend` user define (per-OS map or global string) selects
  // the WebGPU-capable engine for webgpu/hybrid targets — built with
  // THERMION_ENABLE_WEBGPU=ON with Filament's Dawn port and fetched
  // under a -webgpu suffix. webgl2/native keep the default WebGL2 engine.
  final variant = withWebBackend(
    withRuntimeMaterials(resolveWebVariant(input.userDefines["web_variant"]), input.userDefines["runtime_materials"]),
    backend,
  );
  for (final warning in variant.warnings) {
    logger.warning(warning);
  }

  // Local-build override: skip the R2 download and copy from the emscripten
  // build output instead. Set `web_local: true` under
  // `hooks.user_defines.thermion_dart` in the consuming app's pubspec.yaml
  // when iterating on native C++ that needs to ship to web.
  final webLocal = input.userDefines["web_local"];
  if (webLocal == true || webLocal == "true" || webLocal == 1 || webLocal == "1") {
    final localOut = Directory(
      path.join(packageRoot, 'native', 'web', webLocalBuildDir(variant.zipSuffix), 'build', 'out'),
    );
    if (!localOut.existsSync()) {
      throw MaterialToolsError(
        'web_local: true set but ${localOut.path} does not exist; '
        'build the web target first, then re-run.',
      );
    }
    return localOut;
  }

  final versionFile = File(path.join(packageRoot, 'native', 'web', 'web.version'));
  if (!versionFile.existsSync()) {
    throw MaterialToolsError('Missing web engine version at ${versionFile.path}.');
  }
  final version = versionFile.readAsStringSync().trim();
  if (version.isEmpty || version == 'pending') {
    throw MaterialToolsError('No published web engine version in ${versionFile.path}.');
  }
  logger.info('Web artifact version: $version');

  // Variant-scoped cache: the default and main-thread engines must never
  // share a directory — the success token would otherwise mask the wrong
  // contents when switching variants.
  final cacheDir = Directory(
    path.join(packageRoot, '.dart_tool', 'thermion_dart', 'web', '$version${variant.cacheSuffix}'),
  );

  await _fetchWebZip(version, variant.zipSuffix, cacheDir, logger);
  return cacheDir;
}

Future<void> _fetchWebZip(String version, String zipSuffix, Directory cacheDir, Logger logger) async {
  final successToken = File(path.join(cacheDir.path, 'success'));
  if (successToken.existsSync()) {
    logger.info('Web artifacts already cached at ${cacheDir.path}');
    return;
  }

  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  final zipName = webArtifactZipName(version, zipSuffix);
  final url = webArtifactUrl(version, zipSuffix);
  final zipFile = File(path.join(cacheDir.path, zipName));

  logger.info('Downloading $url');
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} fetching $url');
  }

  await response.pipe(zipFile.openWrite());
  final bytes = await zipFile.readAsBytes();

  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    final filePath = path.join(cacheDir.path, file.name);
    if (file.isFile) {
      final f = File(filePath);
      await f.create(recursive: true);
      await f.writeAsBytes(file.content as List<int>);
    } else {
      await Directory(filePath).create(recursive: true);
    }
  }

  successToken.writeAsStringSync('SUCCESS');
  logger.info('Extracted web artifacts to ${cacheDir.path}');
}

//
// Plugin configuration processing functions
//

String? _extractConsumingPackageRoot(String outputDirUri, Logger logger) {
  try {
    // Parse the URI to get file path
    final uri = Uri.parse(outputDirUri);
    final outputPath = uri.toFilePath();

    logger.info("Extracting consuming package root from output directory: $outputPath");

    // Navigate up the directory tree to find the consuming package root
    // The path typically looks like: /path/to/consuming_package/.dart_tool/hooks_runner/shared/thermion_dart/build/hash/
    var currentPath = outputPath;

    while (currentPath != path.dirname(currentPath)) {
      // Stop at filesystem root
      final pubspecFile = File(path.join(currentPath, 'pubspec.yaml'));

      if (pubspecFile.existsSync()) {
        logger.info("Found consuming pubspec.yaml at: ${pubspecFile.path}");
        return currentPath;
      }

      // Move up one directory level
      currentPath = path.dirname(currentPath);
    }

    logger.info("Could not find consuming package root from output directory");
    return null;
  } catch (e) {
    logger.info("Error extracting consuming package root: $e");
    return null;
  }
}

Future<void> _processDeclarativePlugins(
  List<dynamic> pluginConfigs,
  List<String> sources,
  List<String> libs,
  Map<String, String?> defines,
  List<String> flags,
  List<String> includeDirs,
  OS targetOS,
  Logger logger,
  String consumingPackageRoot,
) async {
  for (final pluginConfig in pluginConfigs) {
    if (pluginConfig is! Map<String, dynamic>) {
      logger.warning("Invalid plugin configuration, expected Map but got ${pluginConfig.runtimeType}");
      continue;
    }

    final pluginName = pluginConfig['name'] as String?;
    if (pluginName == null) {
      logger.warning("Plugin configuration missing 'name' field");
      continue;
    }

    logger.info("Processing plugin: $pluginName");

    // Process sources
    final pluginSources = pluginConfig['sources'] as List<dynamic>?;
    if (pluginSources != null) {
      for (final source in pluginSources) {
        if (source is String) {
          final sourcePath = path.join(consumingPackageRoot, source);
          sources.add(sourcePath);
          logger.fine("Added plugin source: $sourcePath");
        }
      }
    }

    // Process include directories
    final pluginIncludeDirs = pluginConfig['include_dirs'] as List<dynamic>?;
    if (pluginIncludeDirs != null) {
      for (final includeDir in pluginIncludeDirs) {
        if (includeDir is String) {
          final includePath = path.join(consumingPackageRoot, includeDir);
          includeDirs.add(includePath);
          logger.fine("Added plugin include directory: $includePath");
        }
      }
    }

    // Process library directories (as -L flags)
    final pluginLibraryDirs = pluginConfig['library_dirs'] as Map<String, dynamic>?;
    if (pluginLibraryDirs != null) {
      final targetOSString = targetOS.toString().split('.').last;
      final platformLibraryDirs = pluginLibraryDirs[targetOSString] as List<dynamic>?;
      if (platformLibraryDirs != null) {
        for (final libraryDir in platformLibraryDirs) {
          if (libraryDir is String) {
            final libraryPath = path.join(consumingPackageRoot, libraryDir);
            flags.add("-L$libraryPath");
            logger.fine("Added plugin library directory: -L$libraryPath");
          }
        }
      }
    }

    // Process link libraries (as -l flags). These are ordinary dependencies,
    // not force-loaded static plugins. If static self-registering plugins are
    // supported in future, their archives may need a narrowly scoped
    // --whole-archive/--no-whole-archive pair so their initializers are kept.
    final pluginLinkLibraries = pluginConfig['link_libraries'] as List<dynamic>?;
    if (pluginLinkLibraries != null) {
      for (final library in pluginLinkLibraries) {
        if (library is String) {
          libs.add(library);
          logger.fine("Added plugin link library: $library");
        }
      }
    }

    // Process defines
    final pluginDefines = pluginConfig['defines'] as List<dynamic>?;
    if (pluginDefines != null) {
      for (final define in pluginDefines) {
        if (define is String) {
          if (define.contains('=')) {
            final parts = define.split('=');
            defines[parts[0]] = parts[1];
          } else {
            defines[define] = "1";
          }
          logger.fine("Added plugin define: $define");
        }
      }
    }

    // Process compile options
    final pluginCompileOptions = pluginConfig['compile_options'] as List<dynamic>?;
    if (pluginCompileOptions != null) {
      for (final option in pluginCompileOptions) {
        if (option is String) {
          flags.add(option);
          logger.fine("Added plugin compile option: $option");
        }
      }
    }

    // Add plugin enabled define
    defines["${pluginName.toUpperCase()}_ENABLED"] = "1";

    logger.info("Successfully processed plugin: $pluginName");
  }
}
