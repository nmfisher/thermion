import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:image_compare/image_compare.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      final dir = screenshotName.split("/")[0];
      final name = screenshotName.split("/")[1];
      final File golden = await File('integration_test/goldens/$dir/$name.png');

      if (!golden.existsSync()) {
        throw Exception(
            "Golden image ${golden.path} doesn't exist yet. Make sure you have run integraton_test_update_goldens.dart first");
      }

      var result = await compareImages(
          src1: screenshotBytes,
          src2: golden.readAsBytesSync(),
          algorithm: ChiSquareDistanceHistogram());

      print(result);

      // TODO - it would be preferable to use Flutter's GoldenFileComparator here, e.g.
      //
      // ```var comparator = LocalFileComparator(testImage.uri);
      // comparator.compare(imageBytes, golden)
      // comparator.getFailureFile(failure, golden, basedir)
      // var result = await comparator.compare(
      //     Uint8List.fromList(screenshotBytes), golden.uri);
      // if (!result.passed) {
      //   for (var key in result.diffs!.keys) {
      //     var byteData = await result.diffs![key]!.toByteData();
      //     File('integration_test/goldens/$dir/diffs/$name.png')
      //         .writeAsBytesSync(
      //             byteData!.buffer.asUint8List(byteData!.offsetInBytes));
      //   }
      //   return false;
      // }```
      // but this is only available via a Flutter shell which is currently unavailable (this script is run as a plain Dart file I guess).
      // let's revisit if/when this changes
      // see https://github.com/flutter/flutter/issues/51890 and https://github.com/flutter/flutter/issues/103222

      if (result > 0.005) {
        File('integration_test/goldens/$dir/diffs/$name.png')
            .writeAsBytesSync(screenshotBytes);
        return false;
      }

      return true;
    },
  );
}
