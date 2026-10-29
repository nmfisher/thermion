export 'src/heap_buffer_stub.dart'
    if (dart.library.io) 'src/heap_buffer_ffi.dart'
    if (dart.library.js_interop) 'src/heap_buffer_web.dart';
