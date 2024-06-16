import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      final dir = screenshotName.split("/")[0];
      final name = screenshotName.split("/")[1];
      final File image = await File('integration_test/goldens/$dir/$name.png')
          .create(recursive: true);

      image.writeAsBytesSync(screenshotBytes);

      return true;
    },
  );
}
