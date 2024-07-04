## 0.1.1+5

 - Bump "thermion_dart" to `0.1.1+5`.

## 0.1.1+4

 - **FIX**: defer creating image entity/material/etc until actually requested.

## 0.1.1+3

 - **FIX**: bump ffigen dependency version & regenerate bindings (and revert to ffi.Int rather than ffi.Int32).
 - **DOCS**: update homepage links and minor documentation updates.

## 0.1.1+2

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.1.1-dev.0+2

 - **FIX**: revert to std::thread (pthreads not easily available on Windows).
 - **FIX**: on Windows, pass static libs via -l rather than custom linkWith property so build.dart stays compatible between published & custom versions.

## 0.1.1+1

 - **DOCS**: update with links to playground.

## 0.1.1

 - Bump "thermion_dart" to `0.1.1`.

## 0.1.0+4

 - **FIX**: add dummy asset to build.dart on Linux builds so we can use the package on a Linux host.

## 0.1.0+3

 - **FIX**: exit build.dart early on Linux builds so we can use the package on a Linux host.

## 0.1.0+2

 - **REFACTOR**: rearrange some stubs/imports for easier web WASM deployment.

## 0.1.0+1

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.
 - **FIX**: use preserveDrawingBuffer=true on web.

## 0.0.1
* First release of Dart-only package
