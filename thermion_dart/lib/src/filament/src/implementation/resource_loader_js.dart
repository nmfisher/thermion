import 'package:thermion_dart/thermion_dart.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<Uint8List> defaultResourceLoader(String path) async {
  if (path.startsWith("file://")) {
    throw Exception("Unsupported URI : $path");
  }

  final response = await http.get(Uri.parse(path));
  return response.bodyBytes;
}

Uri resolveWebResourceUri(String path) => Uri.parse(web.document.baseURI).resolve(path);
