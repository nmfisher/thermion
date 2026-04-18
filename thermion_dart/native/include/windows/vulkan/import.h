#ifdef THERMION_WIN32_KHR_BUILD
#define DLL_EXPORT __declspec(dllimport)
#else
#define DLL_EXPORT __declspec(dllexport)
#endif