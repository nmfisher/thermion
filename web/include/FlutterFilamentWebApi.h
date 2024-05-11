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


FLUTTER_PLUGIN_EXPORT void flutter_filament_web_load_resource_callback(void* data, int32_t length, void* context);
FLUTTER_PLUGIN_EXPORT char flutter_filament_web_get(char* ptr, int32_t offset);
FLUTTER_PLUGIN_EXPORT float flutter_filament_web_get_float(float* ptr, int32_t offset);    
FLUTTER_PLUGIN_EXPORT double flutter_filament_web_get_double(double* ptr, int32_t offset);
FLUTTER_PLUGIN_EXPORT void* flutter_filament_web_get_pointer(void** ptr, int32_t offset);

FLUTTER_PLUGIN_EXPORT void flutter_filament_web_set(char* ptr, int32_t offset, int32_t val);
FLUTTER_PLUGIN_EXPORT void flutter_filament_web_set_float(float* ptr, int32_t offset, float val);
FLUTTER_PLUGIN_EXPORT void flutter_filament_web_set_double(double* ptr, int32_t offset, double val);
FLUTTER_PLUGIN_EXPORT void flutter_filament_web_set_pointer(void** ptr, int32_t offset, void* val);

FLUTTER_PLUGIN_EXPORT int32_t flutter_filament_web_get_int32(int32_t* ptr, int32_t offset);
FLUTTER_PLUGIN_EXPORT void flutter_filament_web_set_int32(int32_t* ptr, int32_t offset, int32_t value);
FLUTTER_PLUGIN_EXPORT long flutter_filament_web_get_address(void** out);
FLUTTER_PLUGIN_EXPORT void* flutter_filament_web_allocate(int32_t size);
FLUTTER_PLUGIN_EXPORT void flutter_filament_web_free(void* ptr);
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE flutter_filament_web_create_gl_context();
FLUTTER_PLUGIN_EXPORT void* flutter_filament_web_get_resource_loader_wrapper();

#ifdef __cplusplus
}
#endif

#endif