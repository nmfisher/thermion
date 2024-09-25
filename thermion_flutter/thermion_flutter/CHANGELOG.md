## 0.2.0-dev.7.0

 - Update a dependency to the latest release.

## 0.2.0-dev.6.0

 - Update a dependency to the latest release.

## 0.2.0-dev.6.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.

## 0.2.0-dev.5.0

 - Update a dependency to the latest release.

## 0.2.0-dev.4.0

 - Update a dependency to the latest release.

## 0.2.0-dev.3.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.

## 0.2.0-dev.2.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.

## 0.2.0-dev.1.0

> Note: This release has breaking changes.

 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: highlight gizmo on hover.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.

## 0.1.1+13

 - Update a dependency to the latest release.

## 0.1.1+12

 - Update a dependency to the latest release.

## 0.1.1+11

 - Update a dependency to the latest release.

## 0.1.1+10

 - Update a dependency to the latest release.

## 0.1.1+9

 - Update a dependency to the latest release.

## 0.1.1+8

 - **DOCS**: update homepage links and minor documentation updates.

## 0.1.1+7

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.1.1-dev.0+7

 - **FIX**: add ResourceBuffer header directly to Windows build so I don't have to fiddle around getting the CMake path right.

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


