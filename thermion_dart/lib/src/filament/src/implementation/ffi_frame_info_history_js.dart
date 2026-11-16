import 'package:thermion_dart/thermion_dart.dart';

/// Web stub for [FilamentApp.getFrameInfoHistory].
///
/// The web bindings keep TFrameInfo opaque because its fields are 64-bit
/// integers, so the records cannot be read on web. This stub keeps the
/// package web-compilable and fails with a clear message instead.
Future<List<FrameTimingInfo>> getFrameInfoHistory(
  Pointer<TJobThread> jobThread,
  Pointer<TRenderer> renderer,
  int count,
) async {
  throw UnsupportedError(
    'getFrameInfoHistory requires a native build; frame timing is not exposed through the web bindings',
  );
}
