import 'dart:io';

import 'package:thermion_dart/src/filament/src/interface/built_in_material.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main(List<String> args) {
  if (args.isNotEmpty && args.length != 2) {
    throw ArgumentError('Usage: configure_material_tests.dart [target_os backend]');
  }

  final pubspec = File('pubspec.yaml');
  final editor = YamlEditor(pubspec.readAsStringSync());
  const defines = ['hooks', 'user_defines', 'thermion_dart'];
  const materials = [...defines, 'materials'];

  for (var length = 1; length <= materials.length; length++) {
    _ensureMap(editor, materials.take(length).toList());
  }
  editor.update([...defines, 'mode'], 'debug');
  for (final material in BuiltInMaterial.values) {
    editor.update([...materials, material.key], true);
  }
  if (args.isNotEmpty) {
    final backends = [...materials, 'backends'];
    _ensureMap(editor, backends);
    editor.update([...backends, args[0]], args[1]);
  }

  pubspec.writeAsStringSync(editor.toString());
}

void _ensureMap(YamlEditor editor, List<String> path) {
  final value = editor.parseAt(path, orElse: () => wrapAsYamlNode(null)).value;
  if (value == null) {
    editor.update(path, <String, Object?>{});
  } else if (value is! Map) {
    throw FormatException('Expected a YAML map at ${path.join('.')}.');
  }
}
