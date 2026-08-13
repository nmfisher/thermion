/// Test-only access to the platform binding's KTX2 staging diagnostic.
export 'package:thermion_dart/src/bindings/src/ffi.dart'
    if (dart.library.js_interop) 'package:thermion_dart/src/bindings/src/js_interop.dart'
    show debugKtx2StagedInputBytes;
