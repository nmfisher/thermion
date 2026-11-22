import 'package:thermion_dart/thermion_dart.dart';

/// The Android texture-registry surface used to present Filament frames.
enum AndroidTextureSource {
  /// Uses Flutter's `SurfaceTexture` external-texture path.
  ///
  /// This avoids the main-thread `ImageReader` work performed by
  /// [surfaceProducer] and is the preferred path for opaque views.
  surfaceTexture,

  /// Uses Flutter's `SurfaceProducer` path.
  ///
  /// This preserves premultiplied alpha when compositing a transparent
  /// Filament view with Impeller, but its ImageReader-backed implementation
  /// can be substantially more expensive on some Android devices.
  surfaceProducer,
}

class ThermionFlutterOptions {
  final String? uberarchivePath;

  final WebOptions webOptions;
  final NativeOptions nativeOptions;

  const ThermionFlutterOptions({
    this.webOptions = const WebOptions(),
    this.nativeOptions = const NativeOptions(),
    this.uberarchivePath,
  });
}

class NativeOptions {
  final Backend? backend;

  /// The texture-registry surface used on Android.
  ///
  /// Prefer [AndroidTextureSource.surfaceTexture] unless the Filament output
  /// must be composited transparently over Flutter content.
  final AndroidTextureSource androidTextureSource;

  /// The format to use for the default render target color attachment.
  /// Currently only applicable on iOS/macOS.
  final TextureFormat renderTargetColorTextureFormat;

  /// The format to use for the default render target depth attachment.
  /// Currently only applicable on iOS/macOS.
  final TextureFormat renderTargetDepthTextureFormat;

  /// If true, create the highlight overlay system at viewer initialization.
  /// The overlay persists for the lifetime of the viewer.
  final bool createOverlay;

  const NativeOptions({
    this.backend,
    this.androidTextureSource = AndroidTextureSource.surfaceTexture,
    this.renderTargetColorTextureFormat = TextureFormat.RGBA8,
    this.renderTargetDepthTextureFormat = TextureFormat.DEPTH24_STENCIL8,
    this.createOverlay = false,
  });
}

class WebOptions {
  final bool createCanvas;
  final bool importCanvasAsWidget;

  /// Hard cap on concurrent viewers. Web runs one engine + WebGL context per
  /// viewer; browsers allow ~16 contexts per tab, so this guards runaway
  /// mounting. 0 disables the cap.
  final int maxViewers;
  final String jsPath;

  /// Filament backend to use on the web. If null, defaults to [Backend.OPENGL]
  /// (WebGL2). Pass [Backend.WEBGPU] to use the WebGPU backend; the caller is
  /// responsible for verifying availability first via [WebGpu.isSupported].
  final Backend? backend;

  const WebOptions({
    this.importCanvasAsWidget = true,
    this.createCanvas = true,
    this.maxViewers = 8,
    this.jsPath = "./thermion_dart.js",
    this.backend,
  });
}
