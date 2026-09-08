import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';
import 'matrix_buffer_checks.dart';
import 'native_matrix_lifetime_checks.dart';

Future<void> main() async {
  await TestHelper('matrix_buffers').setup();
  tearDownAll(() => FilamentApp.instance!.destroy());
  test('native allocation balance, failed initialization and pending uses', checkNativeMatrixLifetimes);
  test('shared native matrices and caller-owned queued storage', checkNativeMatrices);
  test('matrix buffers preserve values, snapshots and storage boundaries', checkMatrixBuffers);
}
