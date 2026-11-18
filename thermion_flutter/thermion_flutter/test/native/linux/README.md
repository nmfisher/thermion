# Linux plugin lifecycle harness

Host-side tests for the texture ownership logic in
[`linux/thermion_flutter_plugin.cc`](../../../linux/thermion_flutter_plugin.cc) and
[`linux/egl_texture.cc`](../../../linux/egl_texture.cc).

The plugin sources are compiled **unmodified** against stub headers
(`stubs/`) backed by fakes (`fakes/`) for the Flutter Linux embedder, EGL/GL
and the OpenGL/Vulkan producers. The tests drive the plugin the way the
engine does: method-channel calls on the platform thread, `populate()` on a
separate raster thread through a raw registrar lookup, and deferred responses
through the GLib main loop.

The fakes record what the plugin does and flag misuse, e.g.:

- a GL call with no current context, or a texture deleted from the wrong
  share group;
- an EGLImage destroyed twice, or a dma-buf fd closed while it is being
  imported;
- producer surfaces freed while their textures are still registered;
- leaked GL textures, EGLImages, EGL contexts, producer surfaces or fds.

Only GLib/GObject is required, so the harness runs on hosted CI without a GPU
or display server, and on macOS (`brew install glib`).

```sh
cmake -S . -B build -G Ninja -DTHERMION_SANITIZER=address   # or thread, none
cmake --build build
ctest --test-dir build --output-on-failure
```

Each test case is registered as its own ctest so that a sanitizer abort in one
case does not hide the others. A failing case prints the recorded event log.
Run a single case with `build/linux_plugin_lifecycle_test <name>`.

To check another copy of the plugin (for example, to confirm that a new test
fails without its fix), point `THERMION_PLUGIN_SOURCE_DIR` at that `linux/`
directory.

The harness does not cover real driver behaviour (dma-buf import, GBM,
Vulkan export, synchronization). Those still need the display-server smoke
tests on real hardware.
