import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/src/filament/src/interface/filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_tone_mapper.dart';

/// Look options for AgX tone mapper
enum AgxLook {
  /// Base contrast with no look applied
  none,

  /// A punchy and more chroma laden look for sRGB displays
  punchy,

  /// A golden tinted, slightly washed look for BT.1886 displays
  golden
}

/// Abstract tone mapper interface
///
/// ToneMapper instances define how HDR values are mapped to display-ready LDR values.
/// Use the static factory methods to create specific tone mapper types.
abstract class ToneMapper extends NativeHandle<dynamic> {
  /// Create a LinearToneMapper - returns input color clamped to 0..1 range
  /// Useful for debugging
  static Future<ToneMapper> linear() async {
    return FFIToneMapper.linear();
  }

  /// Create an ACESToneMapper - ACES Reference Rendering Transform (RRT)
  /// combined with the Output Device Transform (ODT) for sRGB monitors
  static Future<ToneMapper> aces() async {
    return FFIToneMapper.aces();
  }

  /// Create an ACESLegacyToneMapper - ACES tone mapper modified to match
  /// the perceived brightness of FilmicToneMapper (applies ~1.6x brightness)
  static Future<ToneMapper> acesLegacy() async {
    return FFIToneMapper.acesLegacy();
  }

  /// Create a FilmicToneMapper - designed to approximate ACES RRT + ODT
  /// for Rec.709. Exists for backward compatibility.
  static Future<ToneMapper> filmic() async {
    return FFIToneMapper.filmic();
  }

  /// Create a PBRNeutralToneMapper - Khronos PBR Neutral tone mapper
  /// designed to preserve material appearance across lighting conditions
  static Future<ToneMapper> pbrNeutral() async {
    return FFIToneMapper.pbrNeutral();
  }

  /// Create an AgxToneMapper with optional look
  ///
  /// [look] - Optional creative adjustment to contrast and saturation:
  ///   - AgxLook.none: Base contrast with no look applied
  ///   - AgxLook.punchy: More chroma laden look for sRGB displays
  ///   - AgxLook.golden: Golden tinted look for BT.1886 displays
  static Future<ToneMapper> agx({AgxLook look = AgxLook.none}) async {
    return FFIToneMapper.agx(look: look);
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
  static Future<ToneMapper> generic({
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) async {
    return FFIToneMapper.generic(
        contrast: contrast,
        midGrayIn: midGrayIn,
        midGrayOut: midGrayOut,
        hdrMax: hdrMax);
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
  static Future<ToneMapper> displayRange() async {
    return FFIToneMapper.displayRange();
  }

  /// Destroy the tone mapper and free its resources
  Future dispose();
}
