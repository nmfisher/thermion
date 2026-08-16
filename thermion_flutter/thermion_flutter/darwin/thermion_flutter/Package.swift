// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "thermion_flutter",
  platforms: [
    .iOS("13.0"),
    .macOS("13.0"),
  ],
  products: [
    // If the plugin name contains "_", the library name uses "-" instead.
    .library(name: "thermion-flutter", targets: ["thermion_flutter"])
  ],
  dependencies: [],
  targets: [
    // The Dart Native API dynamic-linking layer (dart_api_dl.c). SPM does not
    // allow C and Swift sources in the same target, so the C code lives in its
    // own target that the Swift plugin depends on.
    .target(
      name: "thermion_flutter_dart_api",
      dependencies: []
    ),
    // The Flutter plugin glue: Metal texture wrappers, the frame scheduler and
    // the FlutterPlugin registrant. Filament itself is delivered separately by
    // thermion's native-assets build hook and is not part of this package.
    .target(
      name: "thermion_flutter",
      dependencies: ["thermion_flutter_dart_api"]
    ),
  ]
)
