import 'dart:io';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    var platform = config.targetOS.toString().toLowerCase();

    var libDir = "${config.packageRoot.toFilePath()}/native/lib/$platform/";

    if (platform == "macos") {
      libDir +=
          "${config.dryRun ? "debug" : config.buildMode == BuildMode.debug ? "debug" : "release"}";
    } else if (platform == "android") {
      // we don't recommend using Filament debug builds on Android, since there
      // are known driver issues, e.g.:
      // https://github.com/google/filament/issues/7162
      // (these aren't present in Filament release builds).
      // However, if for some reason you need to debug a Filament-specific issue,
      // you can build your own debug libraries, copy to the native/lib/android/debug folder, then change the following to "debug".
      libDir += "release";
    } else if (platform == "windows") {
      libDir += "x86_64/mdd";
    }

    if (platform == "android") {
      if (!config.dryRun) {
        final archExtension = switch (config.targetArchitecture) {
          Architecture.arm => "armeabi-v7a",
          Architecture.arm64 => "arm64-v8a",
          Architecture.x64 => "x86_64",
          Architecture.ia32 => "x86",
          _ => throw FormatException('Invalid')
        };
        libDir += "/$archExtension";
      }
    }

    final packageName = config.packageName;

    final sources = Directory("${config.packageRoot.toFilePath()}/native/src")
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .toList();
    sources.addAll([
      "${config.packageRoot.toFilePath()}/native/include/material/gizmo.c",
      "${config.packageRoot.toFilePath()}/native/include/material/image.c",
    ]);

    final libs = [
      "filament",
      "backend",
      "filameshio",
      "viewer",
      "filamat",
      "geometry",
      "utils",
      "filabridge",
      "gltfio_core",
      "filament-iblprefilter",
      "image",
      "imageio",
      "tinyexr",
      "gltfio_core",
      "filaflat",
      "dracodec",
      "ibl",
      "ktxreader",
      "png",
      "z",
      "stb",
      "uberzlib",
      "smol-v",
      "uberarchive",
      "zstd",
      "basis_transcoder"
    ];

    final linkWith = <String>[];

    if (platform == "windows") {
      linkWith.addAll(libs.map((lib) => "$libDir/$lib.lib"));
      linkWith.addAll(["$libDir/bluevk.lib", "$libDir/bluegl.lib"]);
      linkWith.addAll([
        "gdi32.lib",
        "user32.lib",
        "shell32.lib",
        "opengl32.lib",
        "dwmapi.lib",
        "comctl32.lib"
      ]);
    } else {
      libs.add("stdc++");
    }
    final flags = [];
    final defines = <String, String?>{};
    var frameworks = [];

    if (platform != "windows") {
      flags.addAll(['-std=c++17']);
    } else {
      defines["WIN32"] = "1";
      defines["_DEBUG"] = "1";
      defines["_DLL"] = "1";
      flags.addAll(["/std:c++20", "/MDd"]);
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
      libs.addAll(["bluegl", "bluevk"]);
    } else if (platform == "android") {
      libs.addAll(["GLESv3", "EGL", "bluevk", "dl", "android"]);
    }

    frameworks = frameworks.expand((f) => ["-framework", f]).toList();

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'dart_filament.dart',
      sources: sources,
      includes: ['native/include', 'native/include/filament'],
      defines: defines,
      linkWith: linkWith,
      flags: [
        if (platform == "macos") '-mmacosx-version-min=13.0',
        if (platform == "ios") '-mios-version-min=13.0',
        ...flags,
        ...frameworks,
        if (platform != "windows") ...libs.map((lib) => "-l$lib"),
        "-L$libDir",
      ],
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      config: config,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
    if (config.targetOS == OS.android) {
      if (!config.dryRun) {
        final archExtension = switch (config.targetArchitecture) {
          Architecture.arm => "arm-linux-androideabi",
          Architecture.arm64 => "aarch64-linux-android",
          Architecture.x64 => "x86_64-linux-android",
          Architecture.ia32 => "i686-linux-android",
          _ => throw FormatException('Invalid')
        };
        var ndkRoot = File(config.cCompiler.compiler!.path).parent.parent.path;
        var stlPath =
            File("$ndkRoot/sysroot/usr/lib/${archExtension}/libc++_shared.so");
        output.addAsset(NativeCodeAsset(
            package: "dart_filament",
            name: "libc++_shared.so",
            linkMode: DynamicLoadingBundled(),
            os: config.targetOS,
            file: stlPath.uri,
            architecture: config.targetArchitecture));
      }
    }
    if (config.targetOS == "windows") {
         final packageName = config.packageName;
    final allAssets = [
      DataAsset(
        package: packageName,
        name: 'unused_asset',
        file: config.packageRoot.resolve('assets/unused_asset.json'),
      ),
      DataAsset(
        package: packageName,
        name: 'used_asset',
        file: config.packageRoot.resolve('assets/used_asset.json'),
      )
    ];
    output.addAssets(allAssets, linkInPackage: packageName);
      output.addAsset(
          NativeCodeAsset(
              package: "dart_filament",
              name: "dart_filament.dll",
              linkMode: DynamicLoadingBundled(),
              os: config.targetOS,
              file: Uri.file(
                  config.outputDirectory.toFilePath() + "/dart_filament.dll"),
              architecture: config.targetArchitecture),
          linkInPackage: config.packageName);
    }
  });
}
