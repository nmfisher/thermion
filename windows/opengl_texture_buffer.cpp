#include "opengl_texture_buffer.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <thread>

namespace polyvox_filament {

void _release_callback(void *releaseContext) {
  // ((OpenGLTextureBuffer*)releaseContext)->unlock();
}

OpenGLTextureBuffer::OpenGLTextureBuffer(
    flutter::PluginRegistrarWindows *pluginRegistrar,
    flutter::TextureRegistrar *textureRegistrar,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    uint32_t width, uint32_t height, HGLRC context,
    std::shared_ptr<std::mutex> renderMutex)
    : _pluginRegistrar(pluginRegistrar), _textureRegistrar(textureRegistrar),
      _width(width), _height(height), _context(context),
      _renderMutex(renderMutex) {

  HWND hwnd = _pluginRegistrar->GetView()->GetNativeWindow();

  HDC whdc = GetDC(hwnd);

  if (!_context || !wglMakeCurrent(whdc, _context)) {
    result->Error("ERROR", "Failed to switch OpenGL context in constructor.");
    return;
  }

  glGenTextures(1, &glTextureId);

  if (glTextureId == 0) {
    result->Error("ERROR", "Failed to generate texture, OpenGL err was %d",
                  glGetError());
    return;
  }

  glBindTexture(GL_TEXTURE_2D, glTextureId);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, _width, _height, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, 0);

  GLenum err = glGetError();

  if (err != GL_NO_ERROR) {
    result->Error("ERROR", "Failed to generate texture, GL error was %d", err);
    return;
  }
  wglMakeCurrent(NULL, NULL);

  pixelBuffer = std::make_unique<FlutterDesktopPixelBuffer>();
  pixelData.reset(new uint8_t[_width * _height * 4]);

  pixelBuffer->buffer = pixelData.get();
  pixelBuffer->width = size_t(_width);
  pixelBuffer->height = size_t(_height);
  pixelBuffer->release_callback = _release_callback;
  pixelBuffer->release_context = this;

  std::cout << "Created initial pixel data/buffer of size " << _width << "x"
            << _height << std::endl;

  texture =
      std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
          [=](size_t width,
              size_t height) -> const FlutterDesktopPixelBuffer * {

            if (width != this->_width || height != this->_height) {
              if(!this->logged) {
                std::cout << "Front-end widget expects " << width << "x" << height << " but this is " << this->_width << "x" << this->_height 
                          << std::endl;
                this->logged = true;
              }
              return nullptr; 
            }
            uint8_t *data = (uint8_t *)pixelData.get();

            if (!_context || !wglMakeCurrent(whdc, _context)) {
              std::cout << "Failed to switch OpenGL context in callback."
                        << std::endl;
            } else {
              // It seems there's at least 1 frame delay between resizing a
              // front-end widget and the layout operation being performed on
              // Windows. I haven't found a way to guarantee that we can resize
              // the OpenGL texture before the pixel buffer callback here. (If
              // you can find/suggest a way, please let me know). This means we
              // need to manually check that the requested size matches the
              // current size of our GL texture, and return an empty pixel
              // buffer if not.
              glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);

              GLenum err = glGetError();

              if (err != GL_NO_ERROR) {
                if (err == GL_INVALID_OPERATION) {
                  std::cout << "Invalid op" << std::endl;
                } else if (err == GL_INVALID_VALUE) {
                  std::cout << "Invalid value" << std::endl;
                } else if (err == GL_OUT_OF_MEMORY) {
                  std::cout << "Out of mem" << std::endl;
                } else if (err == GL_INVALID_ENUM) {
                  std::cout << "Invalid enum" << std::endl;
                } else {
                  std::cout << "Unknown error" << std::endl;
                }
              }
              wglMakeCurrent(NULL, NULL);
            }
            pixelBuffer->buffer = pixelData.get();
            return pixelBuffer.get();
          }));

  flutterTextureId = textureRegistrar->RegisterTexture(texture.get());
  std::cout << "Registered Flutter texture ID " << flutterTextureId
            << std::endl;
  std::vector<flutter::EncodableValue> resultList;
  resultList.push_back(flutter::EncodableValue(flutterTextureId));
  resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
  resultList.push_back(flutter::EncodableValue(glTextureId));
  result->Success(resultList);
}

OpenGLTextureBuffer::~OpenGLTextureBuffer() {}

} // namespace polyvox_filament