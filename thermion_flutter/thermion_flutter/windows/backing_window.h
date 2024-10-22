#ifndef _BACKING_WINDOW_H
#define _BACKING_WINDOW_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace thermion_flutter {

class BackingWindow {
    public:
    BackingWindow(
        flutter::PluginRegistrarWindows *pluginRegistrar,
        int width, 
        int height,
        int left,
        int top);
    HWND GetHandle();
    void Resize(int width, int height, int left, int top);
    void Destroy();
    private:
        HWND _windowHandle;
        HWND _flutterRootWindow;
        HWND _flutterViewWindow;
        uint32_t _width = 0;
        uint32_t _height = 0;
        uint32_t _left = 0;
        uint32_t _top = 0;
};

}
#endif 