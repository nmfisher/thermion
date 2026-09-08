import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'src/test_io.dart';
import 'matrix_buffer_checks.dart';

Future<void> main() async {
  await initTestBindings();
  await FFIFilamentApp.create(
    config: FFIFilamentConfig(backend: defaultTestBackend, loadResource: loadResourceBytes),
  );
  try {
    print(await benchmarkMatrixBuffers());
  } finally {
    await FilamentApp.instance!.destroy();
  }
}
