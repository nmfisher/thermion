import 'package:thermion_dart/src/filament/src/interface/filament_app.dart';
import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_tone_mapper.dart';

/// Look options for AgX tone mapper
enum AgxLook {
  /// Base contrast with no look applied
  none,

  /// A punchy and more chroma laden look for sRGB displays
  punchy,

  /// A golden tinted, slightly washed look for BT.1886 displays
  golden,
}

/// Abstract tone mapper interface
///
/// ToneMapper instances define how HDR values are mapped to display-ready LDR values.
/// Use the static factory methods to create specific tone mapper types.
abstract class ToneMapper extends NativeHandle<dynamic> {
  /// Create a LinearToneMapper - returns input color clamped to 0..1 range
  /// Useful for debugging
  static Future<ToneMapper> linear(FilamentApp app) async {
    return FFIToneMapper.linear(app);
  }

  /// Create an ACESToneMapper - ACES Reference Rendering Transform (RRT)
  /// combined with the Output Device Transform (ODT) for sRGB monitors
  static Future<ToneMapper> aces(FilamentApp app) async {
    return FFIToneMapper.aces(app);
  }

  /// Create an ACESLegacyToneMapper - ACES tone mapper modified to match
  /// the perceived brightness of FilmicToneMapper (applies ~1.6x brightness)
  static Future<ToneMapper> acesLegacy(FilamentApp app) async {
    return FFIToneMapper.acesLegacy(app);
  }

  /// Create a FilmicToneMapper - designed to approximate ACES RRT + ODT
  /// for Rec.709. Exists for backward compatibility.
  static Future<ToneMapper> filmic(FilamentApp app) async {
    return FFIToneMapper.filmic(app);
  }

  /// Create a PBRNeutralToneMapper - Khronos PBR Neutral tone mapper
  /// designed to preserve material appearance across lighting conditions
  static Future<ToneMapper> pbrNeutral(FilamentApp app) async {
    return FFIToneMapper.pbrNeutral(app);
  }

  /// Create an AgxToneMapper with optional look
  ///
  /// [look] - Optional creative adjustment to contrast and saturation:
  ///   - AgxLook.none: Base contrast with no look applied
  ///   - AgxLook.punchy: More chroma laden look for sRGB displays
  ///   - AgxLook.golden: Golden tinted look for BT.1886 displays
  static Future<ToneMapper> agx(FilamentApp app, {AgxLook look = AgxLook.none}) async {
    return FFIToneMapper.agx(app, look: look);
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
    return FFIToneMapper.generic(app, contrast: contrast, midGrayIn: midGrayIn, midGrayOut: midGrayOut, hdrMax: hdrMax);
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
  static Future<ToneMapper> displayRange(FilamentApp app) async {
    return FFIToneMapper.displayRange(app);
  }

  /// Destroys the tone mapper and frees its native resources. Idempotent.
  ///
  /// A ColorGradingBuilder that references this mapper re-reads it on every
  /// build, so only dispose the mapper after disposing the builder (or after
  /// its final build, if you are certain no more builds will run). Every
  /// built ColorGrading holds a copy of this mapper's state, so disposing
  /// never affects an applied grading.
  Future dispose();
}
