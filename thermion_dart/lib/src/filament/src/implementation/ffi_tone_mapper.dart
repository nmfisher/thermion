import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ToneMapper
class FFIToneMapper extends ToneMapper {
  final Pointer<TToneMapper> _pointer;

  FFIToneMapper._(this._pointer);

  @override
  Pointer<TToneMapper> getNativeHandle() => _pointer;

  /// Create a LinearToneMapper - returns input color clamped to 0..1 range
  /// Useful for debugging
  static Future<ToneMapper> linear(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createLinearRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create an ACESToneMapper - ACES Reference Rendering Transform (RRT)
  /// combined with the Output Device Transform (ODT) for sRGB monitors
  static Future<ToneMapper> aces(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create an ACESLegacyToneMapper - ACES tone mapper modified to match
  /// the perceived brightness of FilmicToneMapper (applies ~1.6x brightness)
  static Future<ToneMapper> acesLegacy(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESLegacyRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a FilmicToneMapper - designed to approximate ACES RRT + ODT
  /// for Rec.709. Exists for backward compatibility.
  static Future<ToneMapper> filmic(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createFilmicRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a PBRNeutralToneMapper - Khronos PBR Neutral tone mapper
  /// designed to preserve material appearance across lighting conditions
  static Future<ToneMapper> pbrNeutral(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createPBRNeutralRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create an AgxToneMapper with optional look
  ///
  /// [look] - Optional creative adjustment to contrast and saturation:
  ///   - AgxLook.none: Base contrast with no look applied
  ///   - AgxLook.punchy: More chroma laden look for sRGB displays
  ///   - AgxLook.golden: Golden tinted look for BT.1886 displays
  static Future<ToneMapper> agx(FFIFilamentApp app, {AgxLook look = AgxLook.none}) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createAGXWithLookRenderThread(
        filamentApp.engine,
        look.index,
        cb,
      ),
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
  static Future<ToneMapper> generic(FFIFilamentApp app, {
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createGenericRenderThread(
        filamentApp.engine,
        contrast,
        midGrayIn,
        midGrayOut,
        hdrMax,
        cb,
      ),
    );
    return FFIToneMapper._(pointer);
  }

  /// Create a DisplayRangeToneMapper - converts HDR RGB to 16 debug colors
  /// representing pixel exposure levels. Useful for validating scene lighting.
  static Future<ToneMapper> displayRange(FFIFilamentApp app) async {
    final filamentApp = app;
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createDisplayRangeRenderThread(filamentApp.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  @override
  Future dispose() async {
    await withVoidCallback((requestId, cb) {
      ToneMapper_destroyRenderThread(_pointer, requestId, cb);
    });
  }
}
