import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../viewer/src/ffi/src/thermion_dart.g.dart';

class DartResourceLoader {
  static final _assets = <int, Pointer>{};
  static void loadResource(Pointer<Char> uri, Pointer<ResourceBuffer> out) {
    try {
      var data = File(uri.cast<Utf8>().toDartString().replaceAll("file://", ""))
          .readAsBytesSync();
      var ptr = calloc<Uint8>(data.lengthInBytes);
      ptr.asTypedList(data.lengthInBytes).setRange(0, data.lengthInBytes, data);

      out.ref.data = ptr.cast<Void>();
      out.ref.size = data.lengthInBytes;
      out.ref.id = _assets.length;
      _assets[out.ref.id] = ptr;
    } catch (err) {
      print(err);
      out.ref.size = -1;
    }
  }

  static void freeResource(ResourceBuffer rb) {
    calloc.free(_assets[rb.id]!);
  }
}
