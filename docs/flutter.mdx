# Rendering/plugin architecture

This is an overview of how the rendering surface is constructed, and how the Flutter plugin communicates with the Filament renderer. If you are looking to extend the plugin or add (and hopefully contribute back upstream) additional features, start here.

## Rendering surface

|Platform|Type|
|---|---|
|Windows|HWND beneath transparency (OpenGL), glTexture render target + Flutter Texture widget (GLES/ANGLE), glTexture render target + Flutter Texture widget (GLES/ANGLE)|
|Android|SurfaceTexture render target + Flutter Texture widget|
|iOS|CVPixelBuffer surface (Metal) + Flutter Texture widget|
|MacOS|CVMetalTexture render target (Metal) + Flutter Texture widget|

On most platforms, we create Filament with a headless swapchain, then render into a (hardware accelerated) texture that Flutter imports into its own widget hierarchy via a Texture widget. This allows the Filament viewport to be transformed/composed completely within the Flutter hierarchy (i.e. you could rotate/scale/translate the ThermionWidget in Flutter if you wanted, or insert other widgets above/below).

Due to performance issues on Windows, we choose a different default approach where Filament renders into its own window, which is then composed with the Flutter window via the system compositor. This only works on Windows 10.

Using this approach, you will not be able to add a Flutter widget behind the Filament viewport, or transform the viewport itself from within Flutter.

You can fall-back to the Texture/render target approach by setting `WGL_USE_BACKING_WINDOW` to `false` in `CMakeLists.txt` for Windows. 

However, I don't currently have capacity to maintain this pathway so it will probably be broken on any given day.

If you want to try the fallback, you have two options for a rendering backend. With `USE_ANGLE` set to `true` in `CMakeLists.txt`, we will use the ANGLE backend (which translates GLES calls to D3D). This provides end-to-end GPU texture support, however there are some odd rendering artifacts with some of the Filament shaders (and in fact will crash with some dynamic lights).

`USE_ANGLE` set to `false` will use the OpenGL backend, but requires copying the contents of the texture from the GPU to CPU on every frame. This is not optimal for performance.

### Why not Platform Views?

Initially, performance of Platform Views was inferior to Texture widgets (and in any case, weren't supported on Windows/Linux). I suspect this is still the case (though that might be worth revisiting).

However, I am now thinking it would be better to lean towards the current Windows model (where the Flutter app is composited over a Filament viewport running in a separate window or view). I suspect that the overwhelming use case is a Flutter UI sitting on top of a Filament viewport, and that very few people will need to insert widgets beneath the viewport (or transform the viewport from within Flutter, excluding resizes or mobile orientation changes which can be handled independently). Deferring to the system compositor should deliver far better performance, at the cost of slightly more complexity in the setting up the app harness.  

## Flutter <-> Platform <-> FFI

TODO