import 'package:thermion_dart/src/bindings/src/js_interop.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart' show FilamentApp, Backend;
import '../../../test/matrix_buffer_checks.dart';

Future<void> main() async {
  try {
    await (globalContext['__thermionReady'] as JSPromise).toDart;
    NativeLibrary.initBindings('thermion_dart');
    await FFIFilamentApp.create(
      canvasSelector: '#test_canvas',
      config: FFIFilamentConfig(
        backend: Backend.OPENGL,
        loadResource: (_) async => throw StateError('Unexpected resource load'),
      ),
    );
    await checkMatrixBuffers();
    final benchmark = await benchmarkMatrixBuffers();
    await FilamentApp.instance!.destroy();
    globalContext['testResult'] = 'PASS: matrix buffer browser regressions\n$benchmark'.toJS;
  } catch (error, stack) {
    globalContext['testResult'] = 'FAIL: $error\n$stack'.toJS;
  }
}
