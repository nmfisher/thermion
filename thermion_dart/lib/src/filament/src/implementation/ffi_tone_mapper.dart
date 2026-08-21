import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of ToneMapper
class FFIToneMapper extends ToneMapper {
  final Pointer<TToneMapper> _pointer;
  bool _disposed = false;

  FFIToneMapper._(this._pointer);

  @override
  Pointer<TToneMapper> getNativeHandle() => _pointer;

  static Future<ToneMapper> linear(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createLinearRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> aces(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createACESRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> acesLegacy(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createACESLegacyRenderThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> filmic(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>((cb) => ToneMapper_createFilmicRenderThread(app.engine, cb));
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> pbrNeutral(FilamentApp app) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createPBRNeutralRenderThread(app.engine, cb),
    );
    return FFIToneMapper._(pointer);
  }

  static Future<ToneMapper> agx(FilamentApp app, {AgxLook look = AgxLook.none}) async {
    final pointer = await withPointerCallback<TToneMapper>(
      (cb) => ToneMapper_createAGXWithLookRenderThread(app.engine, look.index, cb),
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
      (cb) => ToneMapper_createGenericRenderThread(app.engine, contrast, midGrayIn, midGrayOut, hdrMax, cb),
    );
    return FFIToneMapper._(pointer);
  }

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
