// Parse-only stand-in for Emscripten's <emscripten.h>, used by
// `dart run ffigen_js --config ffigen/web.yaml`.
//
// ffigen_js parses the C API headers with libclang; it does not compile them.
// The real header is only needed for two declarations that appear in the C API:
// EMSCRIPTEN_KEEPALIVE (an attribute macro, irrelevant to the ABI) and
// EMSCRIPTEN_WEBGL_CONTEXT_HANDLE (html5_webgl.h). Shipping these stubs keeps
// `make dart-bindings` working on machines without an Emscripten sysroot, so
// every exported C symbol is picked up by regeneration instead of being added
// to the generated file by hand.
#pragma once

#define EMSCRIPTEN_KEEPALIVE
