## 0.3.2

 - Bump "thermion_flutter" to `0.3.2`.

## 0.3.1

 - **FIX**: addDestroySwapchain argument to createViewer() (true by default). This is only used on iOS/macOS where a single swapchain is shared between all render targets.
 - **DOCS**: fix typo in link.
 - **DOCS**: remove code from thermion_flutter README.md and point to docs/repository example instead.

## 0.3.0

 - Bump "thermion_flutter" to `0.3.0`.

## 0.3.0

> Note: This release has breaking changes.

 - **REFACTOR**: rename ThermionFlutterTexture->PlatformTextureDescriptor.
 - **FIX**: rename msPerFrame property.
 - **FEAT**: add FocusNode to ThermionListenerWidget.
 - **FEAT**: use new createTextureAndBindToView in ThermionTextureWidget.
 - **BREAKING** **REFACTOR**: move light methods from FilamentViewer to SceneManager/TLightManager and rename clearLights/clearAssets to destroyLights/destroyAssets.
 - **BREAKING** **FEAT**: remove superseded ThermionWindows widget.
 - **BREAKING** **FEAT**: rename thermion_flutter_ffi package to thermion_flutter_method_channel.

## 0.2.1-dev.20.0

 - Bump "thermion_flutter" to `0.2.1-dev.20.0`.

## 0.2.1-dev.19.0

 - Update a dependency to the latest release.

## 0.2.1-dev.18.0

 - **FIX**: fix windows import header.

## 0.2.1-dev.17

 - **FIX**: multiply coordinates by pixelRatio for scale events.
 - **FIX**: multiply coordinates by pixelRatio for scale events.

## 0.2.1-dev.16

 - Update a dependency to the latest release.

## 0.2.1-dev.15

 - **FIX**: multiply coordinates by pixelRatio for scale events.

## 0.2.1-dev.14

 - Update a dependency to the latest release.

## 0.2.1-dev.13

 - Update a dependency to the latest release.

## 0.2.1-dev.12

 - **FIX**: (flutter) (windows) remove deleted source file from Windows CMakeLists.

## 0.2.1-dev.11

 - Update a dependency to the latest release.

## 0.2.1-dev.10

> Note: This release has breaking changes.

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: highlight gizmo on hover.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: expose velocity, rotation and timestamp for scale events in listener. accept rotationSensitivity/zoomSensitivity for FixedOrbitRotateInputHandlerDelegate.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.

## 0.2.1-dev.9

> Note: This release has breaking changes.

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: highlight gizmo on hover.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: highlight gizmo on hover.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: use imported texture on iOS.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.

## 0.2.1-dev.8

 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.

## 0.2.1-dev.7

 - Update a dependency to the latest release.

## 0.2.1-dev.6

 - Update a dependency to the latest release.

## 0.2.1-dev.5

 - Update a dependency to the latest release.

## 0.2.1-dev.4

 - Update a dependency to the latest release.

## 0.2.1-dev.3

 - Update a dependency to the latest release.

## 0.2.1-dev.2

 - Update a dependency to the latest release.

## 0.2.1-dev.1

 - Update a dependency to the latest release.

## 0.2.1-dev.0

 - Update a dependency to the latest release.

## 0.2.1-dev.0.0.0

 - y

## 0.2.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.2.0-dev.8.0.0

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.

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


