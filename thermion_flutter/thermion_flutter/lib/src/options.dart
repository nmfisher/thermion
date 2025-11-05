import 'package:thermion_dart/thermion_dart.dart';

class ThermionFlutterOptions {
  final String? uberarchivePath;
  final Backend? backend;

  /// The format to use for the default render target color attachment.
  /// Currently only applicable on iOS/macOS.
  ///
  final TextureFormat renderTargetColorTextureFormat;

  /// The format to use for the default render target depth attachment.
  /// Currently only applicable on iOS/macOS.
  ///
  final TextureFormat renderTargetDepthTextureFormat;

  const ThermionFlutterOptions(
      {this.uberarchivePath = null,
      this.backend = null,
      this.renderTargetColorTextureFormat = TextureFormat.RGBA32F,
      this.renderTargetDepthTextureFormat = TextureFormat.DEPTH24_STENCIL8});
}

class ThermionFlutterWebOptions extends ThermionFlutterOptions {
  final bool createCanvas;
  final bool importCanvasAsWidget;
  final String jsPath;

  const ThermionFlutterWebOptions(
      {this.importCanvasAsWidget = false,
      this.createCanvas = true,
      this.jsPath = "./thermion_dart.js",

      String? uberarchivePath})
      : super(uberarchivePath: uberarchivePath);
}
