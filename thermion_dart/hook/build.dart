import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import '../lib/src/logging/log.dart';

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);

    final logger = createBuildLogger(pkgRootFilePath, "build.log");

    if (!input.config.buildCodeAssets) {
      logger.info("buildCodeAssets is false, assumed to be building for web");
      await _downloadWebArtifacts(input, logger);
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

    final isIOSSimulator = targetOS == OS.iOS && config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator;

    final libResult = await getLibDir(
      packageRoot,
      targetOS,
      targetArchitecture,
      logger,
      buildMode,
      isIOSSimulator: isIOSSimulator,
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

    // Material source paths (used by _processMaterials below)
    final materialSources = <String, String>{
      'capture_uv': 'native/include/material/capture_uv.c',
      'grid': 'native/include/material/grid.c',
      'image': 'native/include/material/image.c',
      'linear_depth': 'native/include/material/linear_depth.c',
      'unlit_fixed_size': 'native/include/material/unlit_fixed_size.c',
      'silhouette': 'native/include/material/silhouette.c',
      'edge_outline': 'native/include/material/edge_outline.c',
      'wireframe': 'native/include/material/wireframe.c',
      'translation_axis': 'native/include/material/translation_axis.c',
      // Renamed from gizmo.c to avoid a case-insensitive .obj collision
      // with scene/Gizmo.cpp on Windows (both produced gizmo.obj, the
      // material write-clobbered the class .obj, and the linker reported
      // four LNK2019s for thermion::Gizmo::{Gizmo,pick,highlight,unhighlight}).
      'gizmo': 'native/include/material/gizmo_material.c',
      'bone_overlay': 'native/include/material/bone_overlay.c',
    };

    // Add gizmo resources (always included)
    sources.addAll([
      path.join(pkgRootFilePath, "native", "include", "resources", "translation_gizmo_glb.c"),
      path.join(pkgRootFilePath, "native", "include", "resources", "rotation_gizmo_glb.c"),
    ]);

    // Add Dart API DL for port-based frame scheduling (hot restart safe)
    sources.add(path.join(pkgRootFilePath, "native", "include", "dart", "dart_api_dl.c"));

    logger.info("Sources : $sources");

    var libs = [
      "filament",
      "backend",
      "filameshio",
      if (targetOS != OS.iOS) "filamat",
      if (targetOS == OS.linux) "shaders",
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
      "gltfio_core",
      if (targetOS != OS.android && targetOS != OS.iOS) "gltfio",
      "filament-iblprefilter",
      "image",
      "imageio",
      "tinyexr",
      "filaflat",
      "dracodec",
      "ibl",
      "ktxreader",
      "z",
      "stb",
      "uberzlib",
      "smol-v",
      "basis_transcoder",
      "uberarchive",
      if (!{OS.linux, OS.android}.contains(targetOS)) "zstd",
      //"mikktspace",
      "geometry",
      // Debug builds of Filament enable the Material Debug Server and Frame
      // Graph viewer (build.sh -d/-t -> FILAMENT_ENABLE_MATDBG/FGVIEWER), so
      // the debug zips for desktop (macOS/Linux) and Android ship
      // libmatdbg.a/libfgviewer.a and their filament archives reference them
      // (e.g. filament::matdbg::DebugServer). Without these the debug shared
      // library keeps undefined matdbg/fgviewer symbols and dlopen fails at
      // runtime, just like the perfetto case above. iOS debug never enables
      // them (its cmake invocation passes neither option); Windows links
      // libraries via #pragma comment(lib) in ThermionWin32.h instead.
      if ({OS.macOS, OS.android, OS.linux}.contains(targetOS) && buildMode == BuildMode.debug) ...["matdbg", "fgviewer"],
    ];

    if (targetOS == OS.windows) {
      // we just need the libDir and don't need to explicitly link the actual libs
      // (these are linked via ThermionWin32.h)
      libDir = Directory(libDir).uri.toFilePath(windows: targetOS == OS.windows);
    }

    final defines = <String, String?>{};

    if ((input.userDefines["tracing"] as String?)?.isNotEmpty == true) {
      logger.info("Enabling tracing");
      defines["ENABLE_TRACING"] = "1";
    }

    // Check for plugin configuration
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

    // Process materials configuration
    final materialConfigs = input.userDefines["materials"] as Map<String, dynamic>?;
    _processMaterials(materialConfigs, materialSources, sources, defines, logger, pkgRootFilePath);

    var frameworks = [];

    if (targetOS != OS.windows) {
      flags.add('-stdlib=libc++');
      if (!flags.any((f) => f.contains("-std=c++"))) {
        flags.add('-std=c++17');
      }
    } else {
      defines["WIN32"] = "1";
      defines["_DLL"] = "1";
      if (buildMode == BuildMode.debug) {
        defines["_DEBUG"] = "1";
      } else {
        defines["RELEASE"] = "1";
        defines["NDEBUG"] = "1";
      }
      flags.addAll([
        "/std:c++20",
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
      flags.add("-I/usr/include/libdrm");
    }

    if ({OS.linux, OS.macOS}.contains(targetOS) && buildMode == BuildMode.debug) {
      flags.addAll(["-g", "-O0"]);
    }

    if (targetOS == OS.linux) {
      flags.add("-Wl,--export-dynamic");
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

    var srcs = File(Directory.systemTemp.path + Platform.pathSeparator + "thermion_sources.rsp");
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
        if (targetOS == OS.linux) ...["-Wl,--whole-archive"],
        if (targetOS != OS.windows) ...[
          ...libs.map((lib) => "-l$lib"),
          if (targetOS == OS.linux) ...[
            "-Wl,--no-whole-archive",
            '-lGL',
            '-lEGL',
          ] else if (targetOS != OS.android) ...[
            "-lc++",
            "",
          ],
          "-L$libDir",
        ],
        if (targetOS == OS.linux)
          '-Wl,--no-as-needed'
        else if (targetOS != OS.windows && targetOS != OS.android)
          '-lc++',
        if (platform == "windows") ...[
          ...includeDirs.map((d) => "/I${path.join(pkgRootFilePath, d)}"),
          "@${srcs.uri.toFilePath(windows: true)}",
          // Library inputs (filament.lib, backend.lib, bluevk.lib, etc.)
          // are declared via #pragma comment(lib, ...) directives in
          // native/include/ThermionWin32.h, which is transitively included
          // by the c_api headers and the Windows vulkan/d3d sources. The
          // linker only needs to know WHERE to find those .lib files —
          // that is wired via `libraryDirectories: [libDir]` below, which
          // native_toolchain_c emits after its own /link separator
          // (run_cbuilder.dart). Adding a second /link here puts cl.exe's
          // auto-generated /LD and /Fe: AFTER our separator, where LINK
          // ignores them as LNK4044 — the resulting binary has no /DLL
          // and no entry point, failing with LNK1561.
        ],
      ],
      libraryDirectories: [libDir],
    );

    await cbuilder.run(input: input, output: output, logger: logger);

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

String _getFilamentVersion() {
  final versionFile = File(
    path.join(path.dirname(path.dirname(Platform.script.toFilePath(windows: Platform.isWindows))), 'filament.version'),
  );
  if (versionFile.existsSync()) {
    final parts = versionFile.readAsStringSync().trim().split(RegExp(r'\s+'));
    // Format: "<repo> <version>" - return the version (second field)
    return parts.length >= 2 ? parts[1] : parts[0];
  }
  // Fallback to hardcoded version if file doesn't exist
  return "v1.74.0";
}

String _FILAMENT_VERSION = _getFilamentVersion();
String _getLibraryUrl(String platform, String mode) {
  return "https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-${_FILAMENT_VERSION}-${platform}-${mode}.zip";
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
}) async {
  var platform = targetOS.toString().toLowerCase();

  // Use separate library directory for iOS simulator (arm64 simulator
  // libraries can't be lipo'd with arm64 device libraries).
  if (isIOSSimulator) {
    platform = "ios-simulator";
  }

  var mode = buildMode == BuildMode.debug ? "debug" : "release";

  var libDir = Directory(
    path.join(
      packageRoot.toFilePath(windows: Platform.isWindows),
      ".dart_tool",
      "thermion_dart",
      "lib",
      _FILAMENT_VERSION,
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
    // Linux x64 keeps the legacy zip URL + cache dir. arm64 consumers fetch
    // the arch-suffixed zip (filament-<v>-linux-arm64-<mode>.zip) and use an
    // arch-scoped cache dir so the two never collide.
    if (targetArchitecture == Architecture.arm64) {
      platform = "linux-arm64";
      libDir = Directory(path.join(libDir.path, "arm64"));
    } else if (targetArchitecture != Architecture.x64) {
      throw Exception("Unsupported architecture for Linux: ${targetArchitecture}");
    }
  }

  logger.info("Searching for Filament libraries under ${libDir.path}");

  var url = _getLibraryUrl(platform, mode);

  final filename = url.split("/").last;

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
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception("Libraries not found at $url");
    }

    await response.pipe(libraryZip.openWrite());

    final downloadedBytes = await libraryZip.readAsBytes();
    final downloadedHash = md5.convert(downloadedBytes);
    logger.info(
      "Downloaded library zip hash: $downloadedHash, size: ${downloadedBytes.length} bytes (${libraryZip.path})",
    );

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
  // The entire zip (libraries AND the `include/` header tree) is extracted to
  // `unzipDir`; for Android the per-arch libs live in a subdir but headers are
  // shared at the extraction root.
  return (libDir: libDir, includeDir: Directory(path.join(unzipDir, 'include')));
}

const _webR2BaseUrl = 'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev';

Future<void> _downloadWebArtifacts(BuildInput input, Logger logger) async {
  final packageRoot = input.packageRoot.toFilePath(windows: Platform.isWindows);

  // Local-build override: skip the R2 download and copy from the emscripten
  // build output instead. Set `web_local: true` under
  // `hooks.user_defines.thermion_dart` in the consuming app's pubspec.yaml
  // when iterating on native C++ that needs to ship to web.
  final webLocal = input.userDefines["web_local"];
  if (webLocal == true || webLocal == "true" || webLocal == 1 || webLocal == "1") {
    final localOut = Directory(path.join(packageRoot, 'native', 'web', 'build', 'build', 'out'));
    if (!localOut.existsSync()) {
      logger.warning(
        'web_local: true set but ${localOut.path} does not exist; '
        'build the web target first, then re-run.',
      );
      return;
    }
    final consumingPackageRoot = _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);
    if (consumingPackageRoot == null) {
      logger.warning('Could not determine consuming package root');
      return;
    }
    final webDir = Directory(path.join(consumingPackageRoot, 'web'));
    if (!webDir.existsSync()) {
      logger.info('No web/ directory at ${webDir.path}; skipping');
      return;
    }
    for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
      final src = File(path.join(localOut.path, name));
      if (!src.existsSync()) {
        logger.warning('$name not found in ${localOut.path}');
        continue;
      }
      src.copySync(path.join(webDir.path, name));
      logger.info('[web_local] Copied $name from ${localOut.path}');
    }
    return;
  }

  final versionFile = File(path.join(packageRoot, 'native', 'web', 'web.version'));
  if (!versionFile.existsSync()) {
    logger.warning('web.version not found at ${versionFile.path}; skipping web artifact download');
    return;
  }
  final version = versionFile.readAsStringSync().trim();
  if (version.isEmpty || version == 'pending') {
    logger.warning('web.version contains "$version"; skipping download (CI may not have uploaded yet)');
    return;
  }
  logger.info('Web artifact version: $version');

  final consumingPackageRoot = _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);
  if (consumingPackageRoot == null) {
    logger.warning('Could not determine consuming package root; skipping web artifact copy');
    return;
  }

  final cacheDir = Directory(path.join(packageRoot, '.dart_tool', 'thermion_dart', 'web', version));

  try {
    await _fetchWebZip(version, cacheDir, logger);
  } catch (e) {
    logger.warning('Failed to download web artifacts: $e');
    return;
  }

  final webDir = Directory(path.join(consumingPackageRoot, 'web'));
  if (!webDir.existsSync()) {
    logger.info('No web/ directory at ${webDir.path}; skipping artifact copy');
    return;
  }
  for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
    final src = File(path.join(cacheDir.path, name));
    if (!src.existsSync()) {
      logger.warning('$name not found in cache ${cacheDir.path}');
      continue;
    }
    final dest = File(path.join(webDir.path, name));
    src.copySync(dest.path);
    logger.info('Copied $name to ${dest.path}');
  }
}

Future<void> _fetchWebZip(String version, Directory cacheDir, Logger logger) async {
  final successToken = File(path.join(cacheDir.path, 'success'));
  if (successToken.existsSync()) {
    logger.info('Web artifacts already cached at ${cacheDir.path}');
    return;
  }

  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  final zipName = 'thermion_dart-$version-web.zip';
  final url = '$_webR2BaseUrl/$zipName';
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
        logger.info("Found pubspec.yaml at: ${pubspecFile.path}");

        // Verify this is a consuming package (not thermion_dart itself)
        final pubspecContent = pubspecFile.readAsStringSync();

        // Check if this is thermion_dart package itself (avoid self-detection)
        if (pubspecContent.contains('name: thermion_dart')) {
          logger.info("Skipping thermion_dart package itself");
        } else if (pubspecContent.contains('thermion_dart')) {
          logger.info("Found consuming package root: $currentPath");
          return currentPath;
        }
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

    // Process link libraries (as -l flags)
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

//
// Material configuration processing functions
//

void _processMaterials(
  Map<String, dynamic>? materialConfig,
  Map<String, String> materialSources,
  List<String> sources,
  Map<String, String?> defines,
  Logger logger,
  String pkgRootFilePath,
) {
  // If no config provided, include all materials (default)
  if (materialConfig == null) {
    logger.info("No materials config specified, including all materials");
    for (final materialName in materialSources.keys) {
      _includeMaterial(materialName, materialSources, sources, defines, logger, pkgRootFilePath);
    }
    return;
  }

  // Otherwise, only include materials explicitly set to true
  for (final entry in materialConfig.entries) {
    final materialName = entry.key;
    final shouldInclude = entry.value;

    if (shouldInclude == true) {
      if (materialSources.containsKey(materialName)) {
        _includeMaterial(materialName, materialSources, sources, defines, logger, pkgRootFilePath);
      } else {
        logger.warning("Unknown material: $materialName");
      }
    }
  }
}

void _includeMaterial(
  String materialName,
  Map<String, String> materialSources,
  List<String> sources,
  Map<String, String?> defines,
  Logger logger,
  String pkgRootFilePath,
) {
  final sourcePath = path.join(pkgRootFilePath, materialSources[materialName]!);
  sources.add(sourcePath);
  defines["${materialName.toUpperCase()}_ENABLED"] = "1";
  logger.info("Included material: $materialName");
}
