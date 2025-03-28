import 'package:test/test.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/viewer.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("app");
  

  test('destroy app', () async {
    await testHelper.setup();
    final viewer = await testHelper.createViewer();
    await viewer.dispose();
    await FilamentApp.instance!.destroy();
    await testHelper.setup();

  });
}
