#ifndef _FLUTTER_FILAMENT_WEB_RESOURCE_LOADER_H
#define _FLUTTER_FILAMENT_WEB_RESOURCE_LOADER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default"))) 

#ifdef __cplusplus
extern "C" {
#endif

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE ThermionWeb_createGlContext();
FLUTTER_PLUGIN_EXPORT void* ThermionWeb_getResourceLoaderWrapper();

#ifdef __cplusplus
}
#endif

#endif