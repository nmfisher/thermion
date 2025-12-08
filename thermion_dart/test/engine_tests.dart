// ignore_for_file: unused_local_variable
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("engine");
  await testHelper.setup();

  test('check max automatic instances', () async {
    expect(FilamentApp.instance!.getMaxAutomaticInstances(), 64);
  });
}
