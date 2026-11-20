import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

// Run against a build that omits normal_color.
Future<void> main() async {
  await TestHelper('omitted_built_in_material').setup();

  test('an omitted material reports its pubspec key', () async {
    await expectLater(
      FilamentApp.instance!.createBuiltInMaterial(BuiltInMaterial.normalColor),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('materials.normal_color: true'))),
    );
  });
}
