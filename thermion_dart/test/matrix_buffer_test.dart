import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';
import 'matrix_buffer_checks.dart';

Future<void> main() async {
  await TestHelper('matrix_buffers').setup();
  tearDownAll(() => FilamentApp.instance!.destroy());
  test('matrix buffers preserve values, snapshots and storage boundaries', checkMatrixBuffers);
}
