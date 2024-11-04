#pragma once

#ifndef _OPENGL_TEXTURE_BUFFER_H 
#define _OPENGL_TEXTURE_BUFFER_H

#include <mutex>

#include <flutter/texture_registrar.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include "GL/GL.h"
#include "GL/GLu.h"
#include "GL/wglext.h"

#include <Windows.h>
#include <wrl.h>

#include "flutter_texture_buffer.h"

typedef uint32_t GLuint;

namespace thermion_flutter {

class OpenGLTextureBuffer : public FlutterTextureBuffer {
  public:
    OpenGLTextureBuffer(
        flutter::PluginRegistrarWindows* pluginRegistrar,
        flutter::TextureRegistrar* textureRegistrar,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
        uint32_t width,
        uint32_t height,
        HGLRC context);
    
    ~OpenGLTextureBuffer();
    GLuint glTextureId = 0;
    std::unique_ptr<FlutterDesktopPixelBuffer> pixelBuffer;
    std::unique_ptr<uint8_t> pixelData;
    std::unique_ptr<flutter::TextureVariant> texture;
  
  private:
    flutter::PluginRegistrarWindows* _pluginRegistrar;
    flutter::TextureRegistrar* _textureRegistrar;
    uint32_t _width = 0;
    uint32_t _height = 0;
    HGLRC _context = NULL;
    bool logged = false;
};

}
#endif // _OPENGL_TEXTURE_BUFFER_H 