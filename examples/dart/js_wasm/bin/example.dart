import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'package:thermion_dart/src/bindings/bindings.dart';

void main(List<String> arguments) async {
  NativeLibrary.initBindings("thermion_dart");

  final Pointer<TCamera> camera;

  final context = Thermion_createGLContext();
  
final engine = await withPointerCallback<TEngine>(
      (cb) => Engine_createRenderThread(TBackend.BACKEND_DEFAULT.value, nullptr, Pointer<Void>(context), 0, true, cb));
}
