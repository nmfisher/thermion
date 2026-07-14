import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ColorGrading
class FFIColorGrading extends ColorGrading {
  final Pointer<TColorGrading> pointer;

  FFIColorGrading(this.pointer);

  @override
  Pointer<TColorGrading> getNativeHandle() => pointer;

  @override
  Future dispose() async {
    await withVoidCallback(
      (requestId, cb) => Engine_destroyColorGradingRenderThread(
        FilamentApp.instance!.engine,
        pointer,
        requestId,
        cb,
      ),
    );
  }
}

/// FFI implementation of ColorGradingBuilder
class FFIColorGradingBuilder extends ColorGradingBuilder {
  final Pointer<TColorGradingBuilder> _builder;
  bool _built = false;

  FFIColorGradingBuilder(this._builder);

  void _checkNotBuilt() {
    if (_built) {
      throw StateError('Builder has already been built and cannot be reused');
    }
  }

  @override
  ColorGradingBuilder quality(QualityLevel level) {
    _checkNotBuilt();
    ColorGradingBuilder_quality(_builder, level.index);
    return this;
  }

  @override
  ColorGradingBuilder format(LutFormat format) {
    _checkNotBuilt();
    ColorGradingBuilder_format(_builder, format.index);
    return this;
  }

  @override
  ColorGradingBuilder dimensions(int dim) {
    _checkNotBuilt();
    ColorGradingBuilder_dimensions(_builder, dim);
    return this;
  }

  @override
  ColorGradingBuilder toneMapper(ToneMapper mapper) {
    _checkNotBuilt();
    // Extract the native pointer from the ToneMapper object
    final Pointer<TToneMapper> toneMapperPtr = mapper.getNativeHandle();
    ColorGradingBuilder_toneMapper(_builder, toneMapperPtr);
    return this;
  }

  @override
  ColorGradingBuilder exposure(double exposure) {
    _checkNotBuilt();
    ColorGradingBuilder_exposure(_builder, exposure);
    return this;
  }

  @override
  ColorGradingBuilder nightAdaptation(double adaptation) {
    _checkNotBuilt();
    ColorGradingBuilder_nightAdaptation(_builder, adaptation);
    return this;
  }

  @override
  ColorGradingBuilder whiteBalance(double temperature, double tint) {
    _checkNotBuilt();
    ColorGradingBuilder_whiteBalance(_builder, temperature, tint);
    return this;
  }

  @override
  ColorGradingBuilder contrast(double contrast) {
    _checkNotBuilt();
    ColorGradingBuilder_contrast(_builder, contrast);
    return this;
  }

  @override
  ColorGradingBuilder vibrance(double vibrance) {
    _checkNotBuilt();
    ColorGradingBuilder_vibrance(_builder, vibrance);
    return this;
  }

  @override
  ColorGradingBuilder saturation(double saturation) {
    _checkNotBuilt();
    ColorGradingBuilder_saturation(_builder, saturation);
    return this;
  }

  @override
  ColorGradingBuilder channelMixer(
    Vector3 outRed,
    Vector3 outGreen,
    Vector3 outBlue,
  ) {
    _checkNotBuilt();
    ColorGradingBuilder_channelMixer(
      _builder,
      outRed.x,
      outRed.y,
      outRed.z,
      outGreen.x,
      outGreen.y,
      outGreen.z,
      outBlue.x,
      outBlue.y,
      outBlue.z,
    );
    return this;
  }

  @override
  ColorGradingBuilder shadowsMidtonesHighlights(
    Vector4 shadows,
    Vector4 midtones,
    Vector4 highlights,
    Vector4 ranges,
  ) {
    _checkNotBuilt();
    ColorGradingBuilder_shadowsMidtonesHighlights(
      _builder,
      shadows.x,
      shadows.y,
      shadows.z,
      shadows.w,
      midtones.x,
      midtones.y,
      midtones.z,
      midtones.w,
      highlights.x,
      highlights.y,
      highlights.z,
      highlights.w,
      ranges.x,
      ranges.y,
      ranges.z,
      ranges.w,
    );
    return this;
  }

  @override
  ColorGradingBuilder slopeOffsetPower(
    Vector3 slope,
    Vector3 offset,
    Vector3 power,
  ) {
    _checkNotBuilt();
    ColorGradingBuilder_slopeOffsetPower(
      _builder,
      slope.x,
      slope.y,
      slope.z,
      offset.x,
      offset.y,
      offset.z,
      power.x,
      power.y,
      power.z,
    );
    return this;
  }

  @override
  ColorGradingBuilder curves(
    Vector3 shadowGamma,
    Vector3 midPoint,
    Vector3 highlightScale,
  ) {
    _checkNotBuilt();
    ColorGradingBuilder_curves(
      _builder,
      shadowGamma.x,
      shadowGamma.y,
      shadowGamma.z,
      midPoint.x,
      midPoint.y,
      midPoint.z,
      highlightScale.x,
      highlightScale.y,
      highlightScale.z,
    );
    return this;
  }

  @override
  ColorGradingBuilder luminanceScaling(bool enabled) {
    _checkNotBuilt();
    ColorGradingBuilder_luminanceScaling(_builder, enabled);
    return this;
  }

  @override
  ColorGradingBuilder gamutMapping(bool enabled) {
    _checkNotBuilt();
    ColorGradingBuilder_gamutMapping(_builder, enabled);
    return this;
  }

  @override
  Future<ColorGrading> build() async {
    _checkNotBuilt();
    _built = true;
    final ptr = await withPointerCallback<TColorGrading>(
      (cb) => ColorGradingBuilder_buildRenderThread(
        _builder,
        FilamentApp.instance!.engine,
        cb,
      ),
    );
    await withVoidCallback(
      (requestId, cb) =>
          ColorGradingBuilder_destroyRenderThread(_builder, requestId, cb),
    );
    if (ptr == nullptr) {
      throw Exception('Failed to build ColorGrading');
    }
    return FFIColorGrading(ptr);
  }
}
