import 'ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ToneMapper
class FFIToneMapper extends ToneMapper {
  final Pointer<TToneMapper> _pointer;
  final Pointer<TJobThread> _jobThreadHandle;
  bool _disposed = false;

  FFIToneMapper._(this._pointer, this._jobThreadHandle);

  @override
  Pointer<TToneMapper> getNativeHandle() => _pointer;

  static Future<ToneMapper> linear(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createLinearJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> aces(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> acesLegacy(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESLegacyJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> filmic(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createFilmicJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> pbrNeutral(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createPBRNeutralJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> agx(FilamentApp app, {AgxLook look = AgxLook.none}) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) =>
          ToneMapper_createAGXWithLookJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, look.index, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> generic(
    FilamentApp app, {
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createGenericJobThread(
        (app as FFIFilamentApp).jobThreadHandle,
        app.engine,
        contrast,
        midGrayIn,
        midGrayOut,
        hdrMax,
        cb,
      ),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  static Future<ToneMapper> displayRange(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createDisplayRangeJobThread((app as FFIFilamentApp).jobThreadHandle, app.engine, cb),
    );
    return FFIToneMapper._(pointer, (app as FFIFilamentApp).jobThreadHandle);
  }

  @override
  Future dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await withVoidCallback((requestId, cb) {
      ToneMapper_destroyJobThread(_jobThreadHandle, _pointer, requestId, cb);
    });
  }
}
