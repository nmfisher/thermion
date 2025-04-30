import 'dart:io';

import 'package:thermion_dart/thermion_dart.dart';

Future<Uint8List> defaultResourceLoader(String path) {
    print("Loading file $path");
    return File(path).readAsBytes();
}