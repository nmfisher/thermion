## 0.1.1+6

 - **DOCS**: update with links to playground.

## 0.1.1+5

 - Update a dependency to the latest release.

## 0.1.1+4

 - Update a dependency to the latest release.

## 0.1.1+3

 - Update a dependency to the latest release.

## 0.1.1+2

 - **FIX**: update Flutter example project to use new API.
 - **FIX**: add logging dependency to thermion_flutter.

## 0.1.1+1

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.
 - **FIX**: catch exception if gizmo unavailable in ThermionGestureDestectorDesktop.

## 0.1.0
* [ThermionFlutterPlugin] is now static and [dispose] has been removed. Call [createViewer] to obtain an instance of [ThermionViewer]. If you need to release all resources, call [dispose] on [ThermionViewer] 
* Fixed memory leaks

## 0.0.4
* First release of Dart-only package


