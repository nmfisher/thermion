import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart' as bindings;
import 'package:thermion_dart/src/filament/src/interface/engine.dart';

void main() {
  test('public Backend covers every current generated backend and value', () {
    final generated = {
      'DEFAULT': bindings.TBackend.BACKEND_DEFAULT,
      'OPENGL': bindings.TBackend.BACKEND_OPENGL,
      'VULKAN': bindings.TBackend.BACKEND_VULKAN,
      'METAL': bindings.TBackend.BACKEND_METAL,
      'WEBGPU': bindings.TBackend.BACKEND_WEBGPU,
      'NOOP': bindings.TBackend.BACKEND_NOOP,
    };
    expect({for (final backend in Backend.values) backend.name: backend.value}, generated);
    for (final entry in generated.entries) {
      expect(Backend.fromValue(entry.value).name, entry.key);
    }
  });

  test('fromValue rejects values outside the generated enum', () {
    final values = Backend.values.map((backend) => backend.value).toSet();
    final unknown = values.reduce((a, b) => a > b ? a : b) + 1;
    expect(() => Backend.fromValue(unknown), throwsArgumentError);
  });
}
