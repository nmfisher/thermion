/// Cross-platform IO surface for the test harness.
///
/// The test suite was written against `dart:io` (File/Directory/Platform),
/// which does not exist on web. This shim mirrors the pattern already used by
/// `lib/.../resource_loader.dart`: a conditional export that resolves to the
/// native implementation on the VM and the web implementation under dart2js /
/// dart2wasm.
export 'test_io_native.dart'
    if (dart.library.io) 'test_io_native.dart'
    if (dart.library.js_interop) 'test_io_web.dart';
