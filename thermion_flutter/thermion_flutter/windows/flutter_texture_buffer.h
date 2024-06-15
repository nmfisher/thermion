#ifndef _FLUTTER_TEXTURE_BUFFER_H
#define _FLUTTER_TEXTURE_BUFFER_H

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>


namespace thermion_filament {

    class FlutterTextureBuffer {
    public:
        int64_t flutterTextureId = -1;
    };
}

#endif