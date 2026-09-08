import 'package:test/test.dart';
import '../tool/generate_matrix_typed_data.dart';

const fixture = '''
import 'dart:ffi' as ffi;
@ffi.Native<ffi.Void Function(ffi.Pointer<Manager>, ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Double)>>)>(isLeaf: true)
external void TransformManager_submit(ffi.Pointer<Manager> manager, int entity, ffi.Pointer<ffi.Double> matrix16, ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Double)>> callback);
@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Double>)>(isLeaf: true)
external void Camera_read(ffi.Pointer<ffi.Double> out16);
@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Double>)>(isLeaf: true)
external void unrelated(ffi.Pointer<ffi.Double> values, int import\$);
''';

void main() {
  test('derives argument types and order including nested callback types', () {
    final result = generateMatrixTypedDataWrappers(fixture);
    expect(result, contains('typed_data.Float64List matrix16'));
    expect(result, contains('ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Double)>> callback'));
    expect(result, contains('TransformManager_submit(manager, entity, matrix16.address, callback);'));
    expect(result, contains('Camera_read(out16.address);'));
    expect(result, contains('matrix16.length != 16'));
    expect(result, contains('out16.length != 16'));
    expect(result, isNot(contains('unrelatedTypedData')));
    // Only ffigen's original native declarations are present.
    expect('@ffi.Native'.allMatches(result).length, 3);
  });

  test('regeneration is idempotent', () {
    final once = generateMatrixTypedDataWrappers(fixture);
    expect(generateMatrixTypedDataWrappers(once), once);
  });

  test('rejects non-leaf borrowing and changed buffer element types', () {
    expect(
      () => generateMatrixTypedDataWrappers(fixture.replaceFirst('isLeaf: true', 'isLeaf: false')),
      throwsStateError,
    );
    expect(
      () => generateMatrixTypedDataWrappers(fixture.replaceAll('ffi.Double> matrix16', 'ffi.Float> matrix16')),
      throwsStateError,
    );
  });

  test('fails if generator output no longer contains matrix buffer declarations', () {
    expect(() => generateMatrixTypedDataWrappers("import 'dart:ffi' as ffi;"), throwsStateError);
  });
}
