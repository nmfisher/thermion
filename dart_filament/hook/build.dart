// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    var platform = config.targetOS.toString().toLowerCase();
    
    var libDir = "${config.packageRoot.toFilePath()}/native/lib/$platform/${config.dryRun ? "debug" : config.buildMode == BuildMode.debug ? "debug" : "release"}";

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
    }

    frameworks = frameworks.expand((f) => ["-framework", f]).toList();

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'dart_filament.dart',
      sources: sources,
      includes: ['native/include', 'native/include/filament'],
      flags: [
        if (platform == "macos") '-mmacosx-version-min=13.0',
        if (platform == "ios") '-mios-version-min=13.0',
        ...frameworks,
        '-std=c++17',
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
        if (platform == "macos") "-lbluegl",
        if (platform == "macos") "-lbluevk",
        "-lbasis_transcoder",
        "-L$libDir",
        "-force_load",
        "$libDir/libbackend.a",
        "-force_load",
        "$libDir/libktxreader.a",
        "-force_load",
        "$libDir/libvkshaders.a",
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
  });
}
