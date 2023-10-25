#ifndef _BACKING_WINDOW_H
#define _BACKING_WINDOW_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace polyvox_filament {

class BackingWindow {
    public:
    BackingWindow(
        flutter::PluginRegistrarWindows *pluginRegistrar,
        int initialWidth, 
        int initialHeight);
    HWND GetHandle();
    private:
        HWND _windowHandle;
        HWND _flutterRootWindow;
}

}
#endif 