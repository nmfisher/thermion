#pragma once

#ifdef _WIN32
#ifdef IS_DLL
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif

#include <cstdint>
#include <iostream>
#include <Windows.h>

namespace thermion {

///
/// Instantiating a ThermionWindow creates a HWND that can be passed 
/// to Filament to create a swapchain.
///
///
class ThermionWindow {
    public:
    ThermionWindow(
        int width, 
        int height, 
        int left,
        int top);
    HWND GetHandle();
    void Resize(int width, int height, int left, int top);
    private:
        HWND _windowHandle;
        uint32_t _width = 0;
        uint32_t _height = 0;
        uint32_t _left = 0;
        uint32_t _top = 0;
};

static ThermionWindow* _window;

extern "C" { 
    EMSCRIPTEN_KEEPALIVE intptr_t create_thermion_window(int width, int height, int left, int top) { 
        _window = new ThermionWindow(width, height, left, top);
        return (intptr_t)_window->GetHandle();
    }

    EMSCRIPTEN_KEEPALIVE void update() {     
        MSG msg;
        if(GetMessage(&msg, NULL, 0, 0))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        } 
    }
}   

}
#endif 