// Dart wrapper for ToneMapper FFI bindings
import 'dart:ffi' as ffi;
import 'package:thermion_dart/src/bindings/src/thermion_dart_ffi.g.dart';

/// Look options for AgX tone mapper
enum AgxLook {
  /// Base contrast with no look applied
  none(0),

  /// A punchy and more chroma laden look for sRGB displays
  punchy(1),

  /// A golden tinted, slightly washed look for BT.1886 displays
  golden(2);

  const AgxLook(this.value);
  final int value;
}

/// Wrapper class for Filament ToneMapper with static factory methods
class ToneMapper {
  final ffi.Pointer<TToneMapper> _pointer;

  ToneMapper._(this._pointer);

  /// Get the native pointer
  ffi.Pointer<TToneMapper> get pointer => _pointer;

  /// Create a LinearToneMapper - returns input color clamped to 0..1 range
  /// Useful for debugging
  static ToneMapper linear(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createLinear(engine));
  }

  /// Create an ACESToneMapper - ACES Reference Rendering Transform (RRT)
  /// combined with the Output Device Transform (ODT) for sRGB monitors
  static ToneMapper aces(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createACES(engine));
  }

  /// Create an ACESLegacyToneMapper - ACES tone mapper modified to match
  /// the perceived brightness of FilmicToneMapper (applies ~1.6x brightness)
  static ToneMapper acesLegacy(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createACESLegacy(engine));
  }

  /// Create a FilmicToneMapper - designed to approximate ACES RRT + ODT
  /// for Rec.709. Exists for backward compatibility.
  static ToneMapper filmic(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createFilmic(engine));
  }

  /// Create a PBRNeutralToneMapper - Khronos PBR Neutral tone mapper
  /// designed to preserve material appearance across lighting conditions
  static ToneMapper pbrNeutral(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createPBRNeutral(engine));
  }

  /// Create an AgxToneMapper with optional look
  ///
  /// [look] - Optional creative adjustment to contrast and saturation:
  ///   - AgxLook.none: Base contrast with no look applied
  ///   - AgxLook.punchy: More chroma laden look for sRGB displays
  ///   - AgxLook.golden: Golden tinted look for BT.1886 displays
  static ToneMapper agx(ffi.Pointer<TEngine> engine, {AgxLook look = AgxLook.none}) {
    return ToneMapper._(ToneMapper_createAGXWithLook(engine, look.value));
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
  static ToneMapper generic(
    ffi.Pointer<TEngine> engine, {
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) {
    return ToneMapper._(ToneMapper_createGeneric(
      engine,
      contrast,
      midGrayIn,
      midGrayOut,
      hdrMax,
    ));
  }

  /// Create a DisplayRangeToneMapper - converts HDR RGB to 16 debug colors
  /// representing pixel exposure levels. Useful for validating scene lighting.
  ///
  /// Color mapping:
  /// - -5EV: black
  /// - -4EV: darkest blue
  /// - -3EV: darker blue
  /// - -2EV: dark blue
  /// - -1EV: blue
  /// -  0EV: cyan (middle gray)
  /// - +1EV: dark green
  /// - +2EV: green
  /// - +3EV: yellow
  /// - +4EV: yellow-orange
  /// - +5EV: orange
  /// - +6EV: bright red
  /// - +7EV: red
  /// - +8EV: magenta
  /// - +9EV: purple
  /// - +10EV: white
  static ToneMapper displayRange(ffi.Pointer<TEngine> engine) {
    return ToneMapper._(ToneMapper_createDisplayRange(engine));
  }

  /// Destroy the tone mapper and free its resources
  void destroy() {
    ToneMapper_destroy(_pointer);
  }
}
