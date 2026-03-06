#pragma once

#include <stdint.h>

#ifdef _WIN32
  #ifdef IS_DLL
    #define THERMION_EXPORT __declspec(dllimport)
  #else
    #define THERMION_EXPORT __declspec(dllexport)
  #endif
#else
  #define THERMION_EXPORT
#endif

extern "C" {

THERMION_EXPORT intptr_t create_thermion_window(int width, int height, int left, int top);
THERMION_EXPORT void update();
THERMION_EXPORT void cleanup();

}
