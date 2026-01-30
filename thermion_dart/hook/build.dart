import 'dart:io';
import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'log.dart';


void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);

    final logger = createLogger(pkgRootFilePath, "build.log");

    if (!input.config.buildCodeAssets) {
      logger.info("buildCodeAssets is false, assumed to be building for web");
      return;
    }

    logger.info(input.assets.encodedAssets.keys.toList());

    final config = input.config;

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
    final consumingPackageRoot =
        _extractConsumingPackageRoot(input.outputDirectory.toString(), logger);

    var platform = targetOS.toString().toLowerCase();

    logger.info("Building Thermion for ${targetOS} in mode ${buildMode.name}");

    var libDir = (await getLibDir(
            packageRoot, targetOS, targetArchitecture, logger, buildMode))
        .path;

    var sources = Directory(path.join(pkgRootFilePath, "native", "src"))
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((f) => !(f.contains("CMakeLists") || f.contains("main.cpp") || f.contains("build")))
        .toList();

    if (targetOS != OS.windows) {
      sources = sources.where((p) => !p.contains("windows")).toList();
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
      'wireframe': 'native/include/material/wireframe.c'
    };

    // Add gizmo resources (always included)
    sources.addAll([
      path.join(pkgRootFilePath, "native", "include", "resources",
          "translation_gizmo_glb.c"),
      path.join(pkgRootFilePath, "native", "include", "resources",
          "rotation_gizmo_glb.c"),
    ]);

    // Add Dart API DL for port-based frame scheduling (hot restart safe)
    sources.add(path.join(pkgRootFilePath, "native", "include", "dart",
        "dart_api_dl.c"));

    var libs = [
      "filament",
      "backend",
      "filameshio",
	if (targetOS != OS.iOS) "filamat",
      if (targetOS == OS.linux) "shaders",
      "utils",
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
      "zstd",
      //"mikktspace",
      "geometry",
      if (targetOS == OS.macOS && buildMode == BuildMode.debug) ...["matdbg", "fgviewer"]
    ];

    if (targetOS == OS.windows) {
      // we just need the libDir and don't need to explicitly link the actual libs
      // (these are linked via ThermionWin32.h)
      libDir =
          Directory(libDir).uri.toFilePath(windows: targetOS == OS.windows);
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

    // Collect include directories including plugin includes
    final includeDirs = <String>[
      'native/include',
      'native/include/filament',
    ];

    // Process plugins after flags and includeDirs are declared
    if (pluginConfigs != null && consumingPackageRoot != null) {
      await _processDeclarativePlugins(pluginConfigs, sources, libs, defines,
          flags, includeDirs, targetOS, logger, consumingPackageRoot);
    }

    // Process materials configuration
    final materialConfigs = input.userDefines["materials"] as Map<String, dynamic>?;
    _processMaterials(materialConfigs, materialSources, sources, defines, logger, pkgRootFilePath);

    var frameworks = [];

    if (targetOS != OS.windows) {
      if (!flags.any((f) => f.contains("-std=c++"))) {
        flags.addAll(['-std=c++17']);
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
        "/VERBOSE",
        ...defines.keys.map((k) => "/D$k=${defines[k]}").toList()
      ]);
    }

    if (targetOS == OS.iOS) {
      frameworks.addAll([
        'Foundation',
        'CoreGraphics',
        'QuartzCore',
        'GLKit',
        "Metal",
        'CoreVideo',
        'OpenGLES'
      ]);
    } else if (targetOS == OS.macOS) {
      frameworks.addAll([
        'Foundation',
        'CoreVideo',
        'Cocoa',
        "Metal",
      ]);

      if (buildMode == BuildMode.debug) {
        flags.addAll([
          "-g",
          "-O0",
        ]);
      }

      libs.addAll(["bluegl", "bluevk"]);
    } else if (targetOS == OS.android) {
      libs.addAll(["GLESv3", "EGL", "bluevk", "dl", "android"]);
      flags.add("-Wl,-z,max-page-size=16384");
    } else if (targetOS == OS.linux) {
      libs.addAll(["bluevk", "bluegl"]);
    }

    frameworks = frameworks.expand((f) => ["-framework", f]).toList();

    var srcs = File(Directory.systemTemp.path +
        Platform.pathSeparator +
        "thermion_sources.rsp");
    srcs.writeAsStringSync(sources.join("\n"));

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'thermion_dart.dart',
      sources: targetOS == OS.windows ? [] : sources,
      includes: platform == "windows" ? [] : includeDirs,
      defines: platform == "windows" ? {} : defines,
      flags: [
        if (targetOS == OS.macOS) '-mmacosx-version-min=13.0',
        if (targetOS == OS.iOS) '-mios-version-min=13.0',
        ...flags,
        ...frameworks,
        if (targetOS == OS.linux) ...["-stdlib=libc++", "-Wl,--whole-archive"],
        if (targetOS != OS.windows) ...[
          ...libs.map((lib) => "-l$lib"),
          if (targetOS == OS.linux) "-Wl,--no-whole-archive",
          if (targetOS != OS.linux) "-lstdc++",
          "-L$libDir"
        ],
        if (platform == "windows") ...[
          "/I${path.join(pkgRootFilePath, "native", "include")}",
          "/I${path.join(pkgRootFilePath, "native", "include", "filament")}",
          "/I${path.join(pkgRootFilePath, "native", "include", "windows", "vulkan")}",
          "@${srcs.uri.toFilePath(windows: true)}",
          // ...sources,
          // '/link',
          // "/LIBPATH:$libDir",
          // '/DLL',
        ]
      ],
      libraryDirectories: [libDir],
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );
    if (targetOS == OS.android) {
      final archExtension = switch (targetArchitecture) {
        Architecture.arm => "arm-linux-androideabi",
        Architecture.arm64 => "aarch64-linux-android",
        Architecture.x64 => "x86_64-linux-android",
        Architecture.ia32 => "i686-linux-android",
        _ => throw FormatException('Invalid')
      };

      var compilerPath = config.code.cCompiler!.compiler.path;

      if (Platform.isWindows && compilerPath.startsWith("/")) {
        compilerPath = compilerPath.substring(1);
      }

      var ndkRoot = File(compilerPath)
          .parent
          .parent
          .uri
          .toFilePath(windows: Platform.isWindows);

      var stlPath = File([
        ndkRoot,
        "sysroot",
        "usr",
        "lib",
        archExtension,
        "libc++_shared.so"
      ].join(Platform.pathSeparator));
      final libcpp = CodeAsset(
        package: "thermion_dart",
        name: "libc++_shared.so",
        linkMode: DynamicLoadingBundled(),
        file: stlPath.uri,
      );

      output.assets.addEncodedAsset(libcpp.encode());
    }
        
    output.metadata.addAll({"includeDirs":includeDirs.map((dir) => path.join(pkgRootFilePath,dir)).toList()});
    output.metadata.addAll({"outputDir":outputDirectory.path});
   

    if (targetOS == OS.windows) {
      var importLib = File(path.join(
          outputDirectory.path.substring(1).replaceAll("/", "\\"),
          "thermion_dart.lib"));

      output.assets.code.add(CodeAsset(
        package: packageName,
        name: "thermion_dart.lib",
        linkMode: DynamicLoadingBundled(),
        file: importLib.uri,
      ));

      for (final dir in ["windows/vulkan"]) {
        // , "filament/bluevk", "filament/vulkan"
        final targetSubdir =
            path.join(outputDirectory.path, "include", dir).substring(1);
        if (!Directory(targetSubdir).existsSync()) {
          Directory(targetSubdir).createSync(recursive: true);
        }

        for (var file
            in Directory(path.join(pkgRootFilePath, "native", "include", dir))
                .listSync()) {
          if (file is File) {
            final targetPath =
                path.join(targetSubdir, path.basename(file.path));
            file.copySync(targetPath);
            final include = CodeAsset(
              package: packageName,
              name: "include/$dir/${path.basename(file.path)}",
              linkMode: DynamicLoadingBundled(),
              file: file.uri,
            );
            output.assets.addEncodedAsset(include.encode());
          }
        }
      }
    }
  });
}

String _FILAMENT_VERSION = "v1.58.0";
String _getLibraryUrl(String platform, String mode) {
  return "https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-${_FILAMENT_VERSION}-${platform}-${mode}.zip";
}

//
// Download precompiled Filament libraries for the target platform from Cloudflare.
//
Future<Directory> getLibDir(Uri packageRoot, OS targetOS,
    Architecture targetArchitecture, Logger logger, BuildMode buildMode) async {
  var platform = targetOS.toString().toLowerCase();

  var mode = buildMode == BuildMode.debug ? "debug" : "release";

  var libDir = Directory(path.join(
      packageRoot.toFilePath(windows: Platform.isWindows),
      ".dart_tool",
      "thermion_dart",
      "lib",
      _FILAMENT_VERSION,
      platform,
      mode));

  if (platform == "android") {
    final archExtension = switch (targetArchitecture) {
      Architecture.arm => "armeabi-v7a",
      Architecture.arm64 => "arm64-v8a",
      Architecture.x64 => "x86_64",
      Architecture.ia32 => "x86",
      _ => throw FormatException('Invalid')
    };
    libDir = Directory(path.join(libDir.path, archExtension));
  } else if (platform == "windows") {
    if (targetArchitecture != Architecture.x64) {
      throw Exception("Unsupported architecture : ${targetArchitecture}");
    }
  }

  logger.info("Searching for Filament libraries under ${libDir.path}");

  var url = _getLibraryUrl(platform, mode);

  if (targetOS == OS.windows) {
    url = url.replaceAll(".zip", "-vulkan-texture-import.zip");
  }

  final filename = url.split("/").last;

  // We will write an empty file called success to the unzip directory after successfully downloading/extracting the prebuilt libraries.
  // If this file already exists, we assume everything has been successfully extracted and skip
  final unzipDir = platform == "android" ? libDir.parent.path : libDir.path;
  final successToken = File(path.join(
      unzipDir, targetOS == OS.windows ? "success-vulkan" : "success"));
  final libraryZip = File(path.join(unzipDir, filename));

  if (!successToken.existsSync()) {
    if (libraryZip.existsSync()) {
      libraryZip.deleteSync();
    }

    if (!libraryZip.parent.existsSync()) {
      libraryZip.parent.createSync(recursive: true);
    }

    logger.info(
        "Downloading prebuilt libraries for $platform/$mode from $url to ${libraryZip}, files will be unzipped to ${unzipDir}");
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();

    await response.pipe(libraryZip.openWrite());

    final archive = ZipDecoder().decodeBytes(await libraryZip.readAsBytes());

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
  return libDir;
}

//
// Plugin configuration processing functions
//

String? _extractConsumingPackageRoot(String outputDirUri, Logger logger) {
  try {
    // Parse the URI to get file path
    final uri = Uri.parse(outputDirUri);
    final outputPath = uri.toFilePath();

    logger.info(
        "Extracting consuming package root from output directory: $outputPath");

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
      logger.warning(
          "Invalid plugin configuration, expected Map but got ${pluginConfig.runtimeType}");
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
    final pluginLibraryDirs =
        pluginConfig['library_dirs'] as Map<String, dynamic>?;
    if (pluginLibraryDirs != null) {
      final targetOSString = targetOS.toString().split('.').last;
      final platformLibraryDirs =
          pluginLibraryDirs[targetOSString] as List<dynamic>?;
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
    final pluginLinkLibraries =
        pluginConfig['link_libraries'] as List<dynamic>?;
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
    final pluginCompileOptions =
        pluginConfig['compile_options'] as List<dynamic>?;
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
      _includeMaterial(materialName, materialSources, sources, defines, logger,
          pkgRootFilePath);
    }
    return;
  }

  // Otherwise, only include materials explicitly set to true
  for (final entry in materialConfig.entries) {
    final materialName = entry.key;
    final shouldInclude = entry.value;

    if (shouldInclude == true) {
      if (materialSources.containsKey(materialName)) {
        _includeMaterial(materialName, materialSources, sources, defines,
            logger, pkgRootFilePath);
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
