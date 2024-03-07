#include "wgl_context.h"

#ifdef WGL_USE_BACKING_WINDOW
#include "backing_window.h"
#endif

#include "flutter_texture_buffer.h"

namespace flutter_filament {

WGLContext::WGLContext(flutter::PluginRegistrarWindows *pluginRegistrar,
                       flutter::TextureRegistrar *textureRegistrar)
    : FlutterRenderContext(pluginRegistrar, textureRegistrar) {
}

void WGLContext::ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
  #if WGL_USE_BACKING_WINDOW
  _backingWindow->Resize(width, height, left, top);
  #endif
}

void WGLContext::CreateRenderingSurface(
    uint32_t width, uint32_t height,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result, uint32_t left, uint32_t top) {

#if WGL_USE_BACKING_WINDOW
  if(!_backingWindow) {
    _backingWindow = std::make_unique<BackingWindow>(
        _pluginRegistrar, static_cast<int>(width), static_cast<int>(height), static_cast<int>(left), static_cast<int>(top));
  } else { 
    ResizeRenderingSurface(width, height, left, top);
  }
  std::vector<flutter::EncodableValue> resultList;
  resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
  resultList.push_back(
      flutter::EncodableValue((int64_t)_backingWindow->GetHandle()));
  resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
  resultList.push_back(flutter::EncodableValue((int64_t)_context));
  result->Success(resultList);
#else
  if(left != 0 || top != 0) {
    result->Error("ERROR",
                  "When WGL_USE_BACKING_WINDOW is false, rendering with WGL uses a Texture render target/Flutter widget and does not need a window offset.");
  } else if (_active.get()) {
    result->Error("ERROR",
                  "Texture already exists. You must call destroyTexture before "
                  "attempting to create a new one.");
    
  } else {
    auto active = std::make_unique<OpenGLTextureBuffer>(
        _pluginRegistrar, _textureRegistrar, std::move(result), width, height,
        _context);
    _active = std::move(active);
  }
#endif
}

void *WGLContext::GetSharedContext() { return (void *)_context; }

} // namespace flutter_filament
