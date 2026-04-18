#pragma once

#ifdef IS_DLL
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif

extern "C" {

intptr_t create_thermion_window(int width, int height, int left, int top);
void update();

}