import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel = MethodChannel('holovox_filament');

  TestWidgetsFlutterBinding.ensureInitialized();

  test('getPlatformVersion', () async {});
}
