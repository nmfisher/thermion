#ifdef THERMION_WIN32_KHR_BUILD
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif