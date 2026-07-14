import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("camera");
  await testHelper.setup();

  test('create and destroy camera', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.createCamera();
      await camera.destroy();
    });
  });
}
