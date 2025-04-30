import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';

Future<Uint8List> defaultResourceLoader(String path) {
    if(path.startsWith("file://")) {
      throw Exception("Unsupported URI : $path");
    }
    return File(path).readAsBytes();
}