/// Loads a multi-format model (OBJ here) through assimp_dart and renders it
/// with thermion — the reference consumer-side glue between the two packages.
///
/// The assimp-backed implementation lives in load_model_assimp.dart and is
/// conditionally exported for native builds only: assimp_dart is a
/// native-only package (dart:ffi), and examples_lib must stay
/// web-compilable for the gallery. Web builds get the stub in
/// load_model_stub.dart.
export 'load_model_stub.dart' if (dart.library.io) 'load_model_assimp.dart';
