import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// FFI implementation of ColorGrading
class FFIColorGrading extends ColorGrading {
  final Pointer<TColorGrading> pointer;
  bool _disposed = false;

  final FFIFilamentApp _app;

  FFIColorGrading(this.pointer, this._app);

  // Shared-ownership bookkeeping (Filament allows one ColorGrading to be
  // attached to multiple views). The native grading is destroyed when the
  // last attached view detaches; a dispose() that happens while views are
  // still attached is deferred until then.
  static final Map<Pointer<TColorGrading>, int> _viewCounts = {};
  static final Set<Pointer<TColorGrading>> _disposeDeferred = {};

  /// Internal. Records that a view attached [pointer]; the first attach
  /// registers it for shared ownership.
  static void viewAttached(Pointer<TColorGrading> pointer) {
    _viewCounts[pointer] = (_viewCounts[pointer] ?? 0) + 1;
  }

  /// Internal. Records that a view detached from [pointer]. Returns true
  /// when that was the last attached view and the caller must destroy the
  /// native grading (Filament requires the dissociating set/clear/destroy
  /// to have happened first).
  static bool viewDetached(Pointer<TColorGrading> pointer) {
    final count = (_viewCounts[pointer] ?? 0) - 1;
    if (count > 0) {
      _viewCounts[pointer] = count;
      return false;
    }
    _viewCounts.remove(pointer);
    _disposeDeferred.remove(pointer);
    return true;
  }

  @override
  Pointer<TColorGrading> getNativeHandle() => pointer;

  @override
  Future dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if ((_viewCounts[pointer] ?? 0) > 0) {
      // Still attached to at least one view: destroying now would leave
      // those views with a dangling pointer. Defer - the last view to
      // detach destroys it.
      _disposeDeferred.add(pointer);
      return;
    }
    _viewCounts.remove(pointer);
    _disposeDeferred.remove(pointer);
    await withVoidCallback(
      (requestId, cb) => Engine_destroyColorGradingRenderThread(_app.engine, pointer, requestId, cb),
    );
  }
}

/// FFI implementation of ColorGradingBuilder
class FFIColorGradingBuilder extends ColorGradingBuilder {
  final Pointer<TColorGradingBuilder> _builder;
  final FFIFilamentApp _app;
  bool _disposed = false;

  FFIColorGradingBuilder(this._builder, this._app);

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Builder has been disposed');
    }
  }

  @override
  ColorGradingBuilder quality(QualityLevel level) {
    _checkNotDisposed();
    ColorGradingBuilder_quality(_builder, level.index);
    return this;
  }

  @override
  ColorGradingBuilder format(LutFormat format) {
    _checkNotDisposed();
    ColorGradingBuilder_format(_builder, format.index);
    return this;
  }

  @override
  ColorGradingBuilder dimensions(int dim) {
    _checkNotDisposed();
    ColorGradingBuilder_dimensions(_builder, dim);
    return this;
  }

  @override
  ColorGradingBuilder toneMapper(ToneMapper mapper) {
    _checkNotDisposed();
    // Extract the native pointer from the ToneMapper object
    final Pointer<TToneMapper> toneMapperPtr = mapper.getNativeHandle();
    ColorGradingBuilder_toneMapper(_builder, toneMapperPtr);
    return this;
  }

  @override
  ColorGradingBuilder exposure(double exposure) {
    _checkNotDisposed();
    ColorGradingBuilder_exposure(_builder, exposure);
    return this;
  }

  @override
  ColorGradingBuilder nightAdaptation(double adaptation) {
    _checkNotDisposed();
    ColorGradingBuilder_nightAdaptation(_builder, adaptation);
    return this;
  }

  @override
  ColorGradingBuilder whiteBalance(double temperature, double tint) {
    _checkNotDisposed();
    ColorGradingBuilder_whiteBalance(_builder, temperature, tint);
    return this;
  }

  @override
  ColorGradingBuilder contrast(double contrast) {
    _checkNotDisposed();
    ColorGradingBuilder_contrast(_builder, contrast);
    return this;
  }

  @override
  ColorGradingBuilder vibrance(double vibrance) {
    _checkNotDisposed();
    ColorGradingBuilder_vibrance(_builder, vibrance);
    return this;
  }

  @override
  ColorGradingBuilder saturation(double saturation) {
    _checkNotDisposed();
    ColorGradingBuilder_saturation(_builder, saturation);
    return this;
  }

  @override
  ColorGradingBuilder channelMixer(Vector3 outRed, Vector3 outGreen, Vector3 outBlue) {
    _checkNotDisposed();
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
  ColorGradingBuilder shadowsMidtonesHighlights(Vector4 shadows, Vector4 midtones, Vector4 highlights, Vector4 ranges) {
    _checkNotDisposed();
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
  ColorGradingBuilder slopeOffsetPower(Vector3 slope, Vector3 offset, Vector3 power) {
    _checkNotDisposed();
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
  ColorGradingBuilder curves(Vector3 shadowGamma, Vector3 midPoint, Vector3 highlightScale) {
    _checkNotDisposed();
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
    _checkNotDisposed();
    ColorGradingBuilder_luminanceScaling(_builder, enabled);
    return this;
  }

  @override
  ColorGradingBuilder gamutMapping(bool enabled) {
    _checkNotDisposed();
    ColorGradingBuilder_gamutMapping(_builder, enabled);
    return this;
  }

  @override
  Future<ColorGrading> build() async {
    _checkNotDisposed();
    final ptr = await withPointerCallback<TColorGrading>(
      (cb) => ColorGradingBuilder_buildRenderThread(_builder, _app.engine, cb),
    );
    if (ptr == nullptr) {
      throw Exception('Failed to build ColorGrading');
    }
    return FFIColorGrading(ptr, _app);
  }

  @override
  Future dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await withVoidCallback((requestId, cb) => ColorGradingBuilder_destroyRenderThread(_builder, requestId, cb));
  }
}
