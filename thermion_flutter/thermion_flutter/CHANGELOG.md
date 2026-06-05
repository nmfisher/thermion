## 0.4.0

> Note: This release has breaking changes.

 - **REFACTOR**: (Windows) use render target/imported Vulkan texture (#109).
 - **REFACTOR**: add Dart RenderManager class.
 - **REFACTOR**: merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
 - **REFACTOR**: merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
 - **REFACTOR**: change construction logic for ThermionListenerWidget inside ViewerWidget to avoid recreating the rendering surface simply when the manipulator type changes.
 - **REFACTOR**: remove destroyed as public property from PlatformTextureDescriptor (implementations should store/check this internally when markTextuerFrameAvailable is called.
 - **REFACTOR**: move Swift/ObjC interop lib/headers from thermion_dart to thermion_flutter. In theory we can use these on macOS to create/import external textures as render targets in Dart applications. In practice, this requires the Flutter SDK (for objective_c) so it's not actually very practical. We previously used these to test external texture render targets; now that we run tests mostly on Linux, this is no longer used (render targets are created, but bound to textures created by Filament). However this may be useful to revisit in future so we will preserve the files in thermion_flutter.
 - **REFACTOR**: various changes needed to support HighlightOverlayManager on web.
 - **REFACTOR**: rename and consolidate Metal Texture creation classes on macOS/iOS.
 - **REFACTOR**: (flutter) allow returning null SwapChain (for Android) when plugin is first initialized.
 - **REFACTOR**: remove enableHighlights from ThermionWidget.
 - **REFACTOR**: use platform-specific vsync to schedule frames, rather than Flutter's SchedulerBinding. The latter renders a Flutter frame on every request, which isn't necessarily needed - often we just need the Thermion/Filament surface to update independently. (#112).
 - **REFACTOR**: implementing highlight overlays with Flutter widgets showed bad performance. (#111).
 - **REFACTOR**: remove redundant method channel calls to getDriverPlatform and getSharedContext on macOS/iOS.
 - **REFACTOR**: (flutter) migrate overlay implementation to use stacked widgets, each with a render target. Only macOS, iOS and Windows supported in this commit. (#110).
 - **FIX**: throw separate errors for frozen properties in ViewerWidget.
 - **FIX**: (windows) fix multi-viewer runtime hang (UI-thread Blit + FFI callback orphan) (#172).
 - **FIX**: set local _texture reference to null in ThermionWidget before destroying.
 - **FIX**: resolve thermion_dart include paths from package_config.json in Flutter plugin CMake.
 - **FIX**: fix broken RenderManager merge for ThermionFlutterPluginImpl.
 - **FIX**: in debug mode, the vsync frame scheduler will crash when hot restarting (because the Dart callback no longer exists). To fix this, in debug mode we use a Dart Send/ReceivePort to communicate the frame callback. In release mode, the raw function pointer is used. Only applicable to macos, ios, Android and Windows.
 - **FIX**: add missing #include "Log.hpp" in Linux Flutter plugin files.
 - **FIX**: restore 60fps web rendering (#150).
 - **FIX**: remove enableHighlights arg from ThermionWidget.
 - **FIX**: gate thermion_flutter hook on buildAssetTypes, not buildCodeAssets.
 - **FIX**: search from build dir, not source dir, for package_config.json.
 - **FIX**: fix FrameCallback imports.
 - **FIX**: add missing Darwin frame scheduler.
 - **FIX**: resolve thermion_dart include paths via package_config.json.
 - **FIX**(windows): eliminate black frame flash on resize.
 - **FIX**(windows): eliminate texture jank on resize.
 - **FIX**(windows): prevent VkImage double-free on texture resize.
 - **FIX**: use walk-up search for package_config.json instead of hardcoded depth.
 - **FIX**: hide VoidCallback to stop export/import conflicts with Flutter.
 - **FIX**: windows used different vulkan devices.
 - **FIX**: revert FilterQuality for TextureWidget to none.
 - **FIX**: pass destroySwapChain flag through and tweak logging.
 - **FIX**: reinstate rendering with multiple swapchains. I'm not sure if we can create a hardware texture rendertarget on the GLES backend for Android (though this should be possible on Vulkan), so to implement overlays we need to allow multiple swapchains.
 - **FEAT**: add VirtualGameController widget.
 - **FEAT**: add pauseFrameScheduler/resumeFrameScheduler (#142).
 - **FEAT**: auto-download web artifacts from thermion_dart build hook.
 - **FEAT**: update ThermionListenerWidget to support shiftLeft/shiftRight keys and track pressed buttons internally (to correctly identify the button for a mouseUp event).
 - **BREAKING** **REFACTOR**: replace register/unregiser/updateRenderOrder on FilamentApp with a single method setRenderOrder.
 - **BREAKING** **REFACTOR**: \.
 - **BREAKING** **REFACTOR**: (flutter) use ObjC FFI for Swift interop to create textures.
 - **BREAKING** **REFACTOR**: replace register/unregiser/updateRenderOrder on FilamentApp with a single method setRenderOrder.
 - **BREAKING** **FEAT**: remove directLightType, add directLight argument to ViewerWidget.

## 0.3.4

 - Bump "thermion_flutter" to `0.3.4`.

## 0.3.3+2

 - Update a dependency to the latest release.

## 0.3.3+1

 - **FIX**: add 16kb page size flags for Android builds and pin the ndkVersion for thermion_flutter to 28.2.13676358.

## 0.3.3

 - Bump "thermion_flutter" to `0.3.3`.

## 0.3.3-pre

 - **DOCS**: replace thermion_flutter README with symlink to thermion_dart README.

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


