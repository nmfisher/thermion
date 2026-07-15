// ignore_for_file: unused_local_variable
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';
import 'src/test_io.dart' show isWeb;

void main() async {
  final testHelper = TestHelper("engine");
  await testHelper.setup();

  test('check max automatic instances', () async {
    // WebGL2's smaller guaranteed uniform-buffer size caps Filament's automatic
    // instances below desktop backends (Metal/Vulkan): 8 on web vs 64 natively.
    expect(FilamentApp.instance!.getMaxAutomaticInstances(), isWeb ? 8 : 64);
  });
}
