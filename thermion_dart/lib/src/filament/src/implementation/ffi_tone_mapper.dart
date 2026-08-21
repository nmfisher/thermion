import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ToneMapper
class FFIToneMapper extends ToneMapper {
  final Pointer<TToneMapper> _pointer;
  bool _disposed = false;

  FFIToneMapper._(this._pointer);

  @override
  Pointer<TToneMapper> getNativeHandle() => _pointer;

  /// Create a LinearToneMapper - returns input color clamped to 0..1 range
  /// Useful for debugging
  static Future<ToneMapper> linear(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createLinearRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  /// Create an ACESToneMapper - ACES Reference Rendering Transform (RRT)
  /// combined with the Output Device Transform (ODT) for sRGB monitors
  static Future<ToneMapper> aces(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createACESRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  /// Create an ACESLegacyToneMapper - ACES tone mapper modified to match
  /// the perceived brightness of FilmicToneMapper (applies ~1.6x brightness)
  static Future<ToneMapper> acesLegacy(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESLegacyRenderThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a FilmicToneMapper - designed to approximate ACES RRT + ODT
  /// for Rec.709. Exists for backward compatibility.
  static Future<ToneMapper> filmic(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createFilmicRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  /// Create a PBRNeutralToneMapper - Khronos PBR Neutral tone mapper
  /// designed to preserve material appearance across lighting conditions
  static Future<ToneMapper> pbrNeutral(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createPBRNeutralRenderThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create an AgxToneMapper with optional look
  ///
  /// [look] - Optional creative adjustment to contrast and saturation:
  ///   - AgxLook.none: Base contrast with no look applied
  ///   - AgxLook.punchy: More chroma laden look for sRGB displays
  ///   - AgxLook.golden: Golden tinted look for BT.1886 displays
  static Future<ToneMapper> agx(FilamentApp app, {AgxLook look = AgxLook.none}) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createAGXWithLookRenderThread(app.engine, look.index, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a GenericToneMapper with configurable parameters
  ///
  /// Provides control over the tone mapping curve aesthetics and dynamic range.
  /// Default parameters approximate an ACES tone mapping curve.
  ///
  /// [contrast] - Controls the contrast of the curve (must be > 0.0)
  ///              Recommended range: 0.5..2.0 (default: 1.55)
  /// [midGrayIn] - Input middle gray value (0.0..1.0, default: 0.18)
  /// [midGrayOut] - Output middle gray value (0.0..1.0, default: 0.215)
  /// [hdrMax] - Maximum input value mapped to output white (>= 1.0, default: 10.0)
  static Future<ToneMapper> generic(
    FilamentApp app, {
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createGenericRenderThread(app.engine, contrast, midGrayIn, midGrayOut, hdrMax, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a DisplayRangeToneMapper - converts HDR RGB to 16 debug colors
  /// representing pixel exposure levels. Useful for validating scene lighting.
  static Future<ToneMapper> displayRange(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createDisplayRangeRenderThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  @override
  Future dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await withVoidCallback((requestId, cb) {
      ToneMapper_destroyRenderThread(_pointer, requestId, cb);
    });
  }
}
