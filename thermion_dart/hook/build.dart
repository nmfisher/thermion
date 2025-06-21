import 'dart:io';
import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);

    final config = input.config;

    // Most users will only need release builds of Filament.
    // Debug builds are probably only relevant if you're a package developer debugging an internal Filament issue.
    // Also note that there are known driver issues with Android debug builds, e.g.:
    // https://github.com/google/filament/issues/7162
    // (these aren't present in Filament release builds).
    // However, if you know what you're doing, you can change "release" to "debug" .
    final buildMode = BuildMode.release;

    final dryRun = false;
    final packageName = input.packageName;
    final outputDirectory = input.outputDirectory;
    final targetOS = config.code.targetOS;

    final targetArchitecture = config.code.targetArchitecture;
    var logPath = path.join(
        pkgRootFilePath, ".dart_tool", "thermion_dart", "log", "build.log");
    var logFile = File(logPath);
    if (!logFile.parent.existsSync()) {
      logFile.parent.createSync(recursive: true);
    }

    final logger = Logger("")
      ..level = Level.ALL
      ..onRecord.listen((record) => logFile.writeAsStringSync(
          record.message + "\n",
          mode: FileMode.append,
          flush: true));

    var platform = targetOS.toString().toLowerCase();

    if (!dryRun) {
      logger
          .info("Building Thermion for ${targetOS} in mode ${buildMode.name}");
    }

    // We don't support Linux (yet), so the native/Filament libraries won't be
    // compiled/available. However, we still want to be able to run the Dart
    // package itself on a Linux host (e.g. for a wasm/dartdev backend compiler).
    //  TODO
    if (platform == "linux") {
      throw Exception("TODO");
    }

    var libDir = (await getLibDir(
            packageRoot, targetOS, targetArchitecture, logger, buildMode))
        .path;

    var sources = Directory(path.join(pkgRootFilePath, "native", "src"))
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((f) => !(f.contains("CMakeLists") || f.contains("main.cpp")))
        .toList();

    if (targetOS != OS.windows) {
      sources = sources.where((p) => !p.contains("windows")).toList();
    }

    sources.addAll([
      path.join(pkgRootFilePath, "native", "include", "material",
          "unlit_fixed_size.c"),
      path.join(pkgRootFilePath, "native", "include", "material", "image.c"),
      path.join(pkgRootFilePath, "native", "include", "material", "grid.c"),
      path.join(pkgRootFilePath, "native", "include", "resources",
          "translation_gizmo_glb.c"),
      path.join(pkgRootFilePath, "native", "include", "resources",
          "rotation_gizmo_glb.c"),
    ]);

    var libs = [
      "filament",
      "backend",
      "filameshio",
      "viewer",
      if (targetOS != OS.iOS) "filamat",
      "meshoptimizer",
      "mikktspace",
      "geometry",
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
      "uberarchive",
      "zstd",
      "basis_transcoder",
      if (targetOS == OS.macOS) ...["matdbg", "fgviewer"]
    ];

    if (platform == "windows") {
      // we just need the libDir and don't need to explicitly link the actual libs
      // (these are linked via ThermionWin32.h)
      libDir =
          Directory(libDir).uri.toFilePath(windows: targetOS == OS.windows);
    } else {
      libs.add("stdc++");
    }

    final flags = []; //"-fsanitize=address"];

    final defines = <String, String?>{};

    if ((input.userDefines["tracing"] as String?)?.isNotEmpty == true) {
      defines["ENABLE_TRACING"] = "1";
    }

    var frameworks = [];
    if (platform != "windows") {
      flags.addAll(['-std=c++17']);
    } else if (!dryRun) {
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

    if (platform == "ios") {
      frameworks.addAll([
        'Foundation',
        'CoreGraphics',
        'QuartzCore',
        'GLKit',
        "Metal",
        'CoreVideo',
        'OpenGLES'
      ]);
    } else if (platform == "macos") {
      frameworks.addAll([
        'Foundation',
        'CoreVideo',
        'Cocoa',
        "Metal",
      ]);

      if (!dryRun && buildMode == BuildMode.debug) {
        flags.addAll([
          "-g",
          "-O0",
        ]);
      }

      libs.addAll(["bluegl", "bluevk"]);
    } else if (platform == "android") {
      libs.addAll(["GLESv3", "EGL", "bluevk", "dl", "android"]);
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
      sources: platform == "windows" ? [] : sources,
      includes: platform == "windows"
          ? []
          : ['native/include', 'native/include/filament'],
      defines: platform == "windows" ? {} : defines,
      flags: [
        if (targetOS == OS.macOS) ...['-mmacosx-version-min=13.0'],
        if (targetOS == OS.iOS) '-mios-version-min=13.0',
        ...flags,
        ...frameworks,
        if (platform != "windows") ...[
          ...libs.map((lib) => "-l$lib"),
          "-L$libDir"
        ],
        if (platform == "windows") ...[
          "/I${path.join(pkgRootFilePath, "native", "include")}",
          "/I${path.join(pkgRootFilePath, "native", "include", "filament")}",
          "/I${path.join(pkgRootFilePath, "native", "include", "windows", "vulkan")}",
          "@${srcs.uri.toFilePath(windows: true)}",
          // ...sources,
          '/link',
          "/LIBPATH:$libDir",
          '/DLL',
        ]
      ],
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );
    if (targetOS == OS.android) {
      if (!dryRun) {
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
    }

    if (targetOS == OS.windows) {
      var importLib = File(path.join(
          outputDirectory.path.substring(1).replaceAll("/", "\\"),
          "thermion_dart.lib"));
      final libthermion = CodeAsset(
        package: packageName,
        name: "thermion_dart.lib",
        linkMode: DynamicLoadingBundled(),
        file: importLib.uri,
      );
      output.assets.addEncodedAsset(libthermion.encode());

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
    url = url.replaceAll(".zip", "-vulkan.zip");
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
