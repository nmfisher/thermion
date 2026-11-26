/// Raw JS `GPUDevice` export from the engine.
///
/// The conditional export keeps `thermion_dart_web.dart` compilable on the
/// VM (which has no `dart:js_interop`): the io variant reports unavailable,
/// the web variant (compiled only under dart2js/dart2wasm) calls the engine.
export 'webgpu_device_io.dart' if (dart.library.js_interop) 'webgpu_device_web.dart';
