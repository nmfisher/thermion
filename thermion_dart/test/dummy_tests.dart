// just for investigating crashes on GitHub actions
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  group("test", () {
    test("test", () async {
      print("Creating test helper");
      final testHelper = TestHelper("dummy");
      var viewer = await testHelper.createViewer();

      expect(1, 1);
    });
  });
}
