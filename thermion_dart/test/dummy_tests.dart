// just for investigating crashes on GitHub actions
import 'package:test/test.dart';

void main() async {
  group("test", () {
    test("test", () {
      expect(1, 1);
    });
  });
}
