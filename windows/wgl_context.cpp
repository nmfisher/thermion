#include "wgl_context.h"

#ifdef WGL_USE_BACKING_WINDOW
#include "backing_window.h"
#endif

#include "flutter_texture_buffer.h"

namespace polyvox_filament {

WGLContext::WGLContext(flutter::PluginRegistrarWindows *pluginRegistrar,
                       flutter::TextureRegistrar *textureRegistrar)
    : _pluginRegistrar(pluginRegistrar), _textureRegistrar(textureRegistrar) {

  auto hwnd = pluginRegistrar->GetView()->GetNativeWindow();

  HDC whdc = GetDC(hwnd);
  if (whdc == NULL) {
    std::cout << "No device context for temporary window" << std::endl;
    return;
  }

  std::cout << "No GL context exists, creating" << std::endl;

  PIXELFORMATDESCRIPTOR pfd = {
      sizeof(PIXELFORMATDESCRIPTOR),
      1,
      PFD_DRAW_TO_BITMAP | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER, // Flags
      PFD_TYPE_RGBA, // The kind of framebuffer. RGBA or palette.
      32,            // Colordepth of the framebuffer.
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      32, // Number of bits for the depthbuffer
      0,  // Number of bits for the stencilbuffer
      0,  // Number of Aux buffers in the framebuffer.
      PFD_MAIN_PLANE,
      0,
      0,
      0,
      0};

  int pixelFormat = ChoosePixelFormat(whdc, &pfd);
  SetPixelFormat(whdc, pixelFormat, &pfd);

  // We need a tmp context to retrieve and call wglCreateContextAttribsARB.
  HGLRC tempContext = wglCreateContext(whdc);
  if (!wglMakeCurrent(whdc, tempContext)) {
    std::cout << "Failed to acquire temporary context" << std::endl;
    return;
  }

  GLenum err = glGetError();

  if (err != GL_NO_ERROR) {
    std::cout << "GL Error @ 455 %d" << std::endl;
    return;
  }

  PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribs = nullptr;

  wglCreateContextAttribs =
      (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress(
          "wglCreateContextAttribsARB");

  if (!wglCreateContextAttribs) {
    std::cout << "Failed to resolve wglCreateContextAttribsARB" << std::endl;
    return;
  }

  for (int minor = 5; minor >= 1; minor--) {
    std::vector<int> mAttribs = {WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                                 WGL_CONTEXT_MINOR_VERSION_ARB, minor, 0};
    _context = wglCreateContextAttribs(whdc, nullptr, mAttribs.data());
    if (_context) {
      break;
    }
  }

  wglMakeCurrent(NULL, NULL);
  wglDeleteContext(tempContext);

  if (!_context || !wglMakeCurrent(whdc, _context)) {
    std::cout << "Failed to create OpenGL context." << std::endl;
    return;
  }
}

void WGLContext::CreateTexture(
    uint32_t width, uint32_t height,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

#if WGL_USE_BACKING_WINDOW
  _backingWindow = std::make_unique<BackingWindow>(
      _pluginRegistrar, static_cast<int>(width), static_cast<int>(height));
  std::vector<flutter::EncodableValue> resultList;
  resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
  resultList.push_back(
      flutter::EncodableValue((int64_t)_backingWindow->GetHandle()));
  resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
  result->Success(resultList);
#else
  if (_active.get()) {
    result->Error("ERROR",
                  "Texture already exists. You must call destroyTexture before "
                  "attempting to create a new one.");
  } else {
    _active = std::make_unique<OpenGLTextureBuffer>(
        _pluginRegistrar, _textureRegistrar, std::move(result), width, height,
        _context);

    if (_active->flutterTextureId != -1) {
      std::vector<flutter::EncodableValue> resultList;
      resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
      resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
      resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
      result->Success(resultList);
    } else {
      result->Error("FOO", "ERROR", nullptr);
    }
  }
#endif
}

void *WGLContext::GetSharedContext() { return (void *)_context; }

} // namespace polyvox_filament
