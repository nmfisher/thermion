// just for investigating crashes on GitHub actions
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  group("test", () {
    test("test", () {
      print("Creating test helper");
      final testHelper = TestHelper("dummy");
      expect(1, 1);
    });
  });
}
