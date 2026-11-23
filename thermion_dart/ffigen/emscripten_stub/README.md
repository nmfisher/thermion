# Parse-only headers for `ffigen_js`

`ffigen/web.yaml` parses the C API with libclang using the
`wasm32-unknown-emscripten` target. That target has no system headers on a
normal development machine, and Clang's own resource headers are *hosted*:
`stdint.h` falls through to `/usr/include/stdint.h` (glibc), which either
fails to parse or makes ffigen_js fall back to `int` for every fixed-width
type. The generated bindings then differ from the checked-in ones and new
exports have to be added by hand.

These headers stand in for the few Emscripten/freestanding headers the C API
includes:

| File | Declares |
| --- | --- |
| `emscripten.h` | `EMSCRIPTEN_KEEPALIVE` (an attribute macro; irrelevant to the ABI) |
| `emscripten/html5_webgl.h` | `EMSCRIPTEN_WEBGL_CONTEXT_HANDLE` (typedef of `int`) |
| `stdint.h` | the exact-width integer typedefs for the wasm32 ABI |
| `stddef.h` | `size_t` and friends, so ffigen emits the `size_t` alias |
| `stdbool.h` | `bool`/`true`/`false` (kept for completeness) |

They are used for parsing only — nothing here is compiled into
`libthermion_dart`. `ffigen/web.yaml` adds `-Iffigen/emscripten_stub` (and
`-Inative/include`, because the c_api headers include each other as
`"c_api/..."`); both paths are relative to the process working directory, so
run ffigen_js from `thermion_dart/`, as `make dart-bindings` does.

A real Emscripten sysroot can still be used by passing
`FFIGEN_JS_COMPILER_OPTS="--sysroot=... -I..."` to `make dart-bindings`; the
command-line compiler options replace the config's `compiler-opts` entries.
