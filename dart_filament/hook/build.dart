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
    }

    if (platform == "android" || platform == "windows") {
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
      "-lfilament",
      "-lbackend",
      "-lfilameshio",
      "-lviewer",
      "-lfilamat",
      "-lgeometry",
      "-lutils",
      "-lfilabridge",
      "-lgltfio_core",
      "-lfilament-iblprefilter",
      "-limage",
      "-limageio",
      "-ltinyexr",
      "-lgltfio_core",
      "-lfilaflat",
      "-ldracodec",
      "-libl",
      "-lktxreader",
      "-lpng",
      "-lz",
      "-lstb",
      "-luberzlib",
      "-lsmol-v",
      "-luberarchive",
      "-lzstd",
      "-lstdc++",
      "-lbasis_transcoder"
    ];

    var frameworks = [];

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
      libs.addAll(["-lbluegl", "-lbluevk"]);
    } else if (platform == "android") {
      libs.addAll(["-lGLESv3", "-lEGL", "-lbluevk", "-ldl", "-landroid"]);
    }

    frameworks = frameworks.expand((f) => ["-framework", f]).toList();

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'dart_filament.dart',
      sources: sources,
      includes: ['native/include', 'native/include/filament'],
      flags: [
        '-std=c++17',
        if (platform == "macos") '-mmacosx-version-min=13.0',
        if (platform == "ios") '-mios-version-min=13.0',
        ...frameworks,
        ...libs,
        "-L$libDir",
      ],
      dartBuildFiles: ['hook/build.dart'],
    );
    await cbuilder.run(
      buildConfig: config,
      buildOutput: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
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
  });
}
