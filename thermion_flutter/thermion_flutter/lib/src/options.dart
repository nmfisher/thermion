import 'package:thermion_dart/thermion_dart.dart';

class ThermionFlutterOptions {
  final String? uberarchivePath;

  final WebOptions webOptions;
  final NativeOptions nativeOptions;

  const ThermionFlutterOptions(
      {this.webOptions = const WebOptions(),
      this.nativeOptions = const NativeOptions(),
      this.uberarchivePath});
}

class NativeOptions {
  final Backend? backend;

  /// The format to use for the default render target color attachment.
  /// Currently only applicable on iOS/macOS.
  ///
  final TextureFormat renderTargetColorTextureFormat;

  /// The format to use for the default render target depth attachment.
  /// Currently only applicable on iOS/macOS.
  ///
  final TextureFormat renderTargetDepthTextureFormat;

  const NativeOptions(
      {this.backend,
      this.renderTargetColorTextureFormat = TextureFormat.RGBA32F,
      this.renderTargetDepthTextureFormat = TextureFormat.DEPTH24_STENCIL8});
}

class WebOptions {
  final bool createCanvas;
  final bool importCanvasAsWidget;
  final String jsPath;

  const WebOptions(
      {this.importCanvasAsWidget = false,
      this.createCanvas = true,
      this.jsPath = "./thermion_dart.js"});
}
