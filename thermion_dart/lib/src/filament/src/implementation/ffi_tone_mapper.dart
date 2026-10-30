import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ToneMapper
class FFIToneMapper extends ToneMapper {
  final Pointer<TToneMapper> _pointer;
  bool _disposed = false;

  FFIToneMapper._(this._pointer);

  @override
  Pointer<TToneMapper> getNativeHandle() => _pointer;

  static Future<ToneMapper> linear(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createLinearJobThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> aces(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createACESJobThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> acesLegacy(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESLegacyJobThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> filmic(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createFilmicJobThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> pbrNeutral(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createPBRNeutralJobThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> agx(FilamentApp app, {AgxLook look = AgxLook.none}) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createAGXWithLookJobThread(app.engine, look.index, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> generic(
    FilamentApp app, {
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createGenericJobThread(app.engine, contrast, midGrayIn, midGrayOut, hdrMax, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> displayRange(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createDisplayRangeJobThread(app.engine, cb),
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
      ToneMapper_destroyJobThread(_pointer, requestId, cb);
    });
  }
}
