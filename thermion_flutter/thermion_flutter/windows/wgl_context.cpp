#include "wgl_context.h"

#ifdef WGL_USE_BACKING_WINDOW
#include "backing_window.h"
#endif

#include "flutter_texture_buffer.h"

namespace thermion_flutter {

// Add error checking function
void checkWGLError(const char* step, HDC hdc) {
    DWORD error = GetLastError();
    if (error != 0) {
        std::cout << "WGL Error at " << step << ": " << error << std::endl;
    }
    
    // Check if the DC is still valid
    if (!hdc || !wglGetCurrentDC()) {
        std::cout << "Invalid DC at " << step << std::endl;
    }
}

// Modified context creation with error checking
HGLRC createWGLContext(HDC whdc) {
  std::cout << "creating wgl context on HDC" << whdc << std::endl;
    PIXELFORMATDESCRIPTOR pfd = {
        sizeof(PIXELFORMATDESCRIPTOR),
        1,
        PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        PFD_TYPE_RGBA,
        32,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, // Depth buffer
        8,  // Stencil buffer - Added this
        0,
        PFD_MAIN_PLANE,
        0, 0, 0, 0
    };

    // Choose pixel format
    int pixelFormat = ChoosePixelFormat(whdc, &pfd);
    if (pixelFormat == 0) {
        checkWGLError("ChoosePixelFormat", whdc);
        return nullptr;
    }

    // Set pixel format
    if (!SetPixelFormat(whdc, pixelFormat, &pfd)) {
        checkWGLError("SetPixelFormat", whdc);
        return nullptr;
    }

    // Create temporary context
    HGLRC tempContext = wglCreateContext(whdc);
    if (!tempContext) {
        checkWGLError("wglCreateContext", whdc);
        return nullptr;
    }

    // Make temporary context current
    if (!wglMakeCurrent(whdc, tempContext)) {
        checkWGLError("wglMakeCurrent", whdc);
        wglDeleteContext(tempContext);
        return nullptr;
    }

    // Get modern context creation function
    PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribs =
        (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");
    
    if (!wglCreateContextAttribs) {
        std::cout << "Failed to get wglCreateContextAttribsARB" << std::endl;
        wglMakeCurrent(NULL, NULL);
        wglDeleteContext(tempContext);
        return nullptr;
    }

    // Try creating modern context with different versions
    HGLRC context = nullptr;
    for (int minor = 5; minor >= 1; minor--) {
        const int attribs[] = {
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, minor, 0
        };
        
        context = wglCreateContextAttribs(whdc, nullptr, attribs);
        if (context) break;
        checkWGLError("wglCreateContextAttribs", whdc);
    }

    // Clean up temporary context
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(tempContext);

    // Activate new context if created
    if (context && !wglMakeCurrent(whdc, context)) {
        checkWGLError("Final wglMakeCurrent", whdc);
        wglDeleteContext(context);
        std::cout << "Delete context" << std::endl;
        return nullptr;
    }
    wglMakeCurrent(NULL, NULL);

    return context;
}  
  

WGLContext::WGLContext(flutter::PluginRegistrarWindows *pluginRegistrar,
                       flutter::TextureRegistrar *textureRegistrar)
    : FlutterRenderContext(pluginRegistrar, textureRegistrar) {

#if !WGL_USE_BACKING_WINDOW
  auto hwnd = pluginRegistrar->GetView()->GetNativeWindow();

  HDC whdc = GetDC(hwnd);
  if (whdc == NULL) {
    std::cout << "No device context for temporary window" << std::endl;
    return;
  }

  std::cout << "No GL context exists, creating" << std::endl;

  _context = createWGLContext(whdc);

  std::cout << "Created context " << _context << std::endl;

#endif
    }

void WGLContext::ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
  #if WGL_USE_BACKING_WINDOW
  _backingWindow->Resize(width, height, left, top);
  #endif
}

void WGLContext::DestroyRenderingSurface(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  #if WGL_USE_BACKING_WINDOW
  _backingWindow->Destroy();
  _backingWindow = nullptr;
  #else
  
      //     if (!_active) {
      //         result->Success("Texture has already been detroyed, ignoring");
      //         return;
      //     }

      //     auto sh = std::make_shared<
      //         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
      //             std::move(result));

      //     _textureRegistrar->UnregisterTexture(
      //         _active->flutterTextureId, [=, sharedResult = std::move(sh)]() {
      //             this->_inactive = std::move(this->_active);
      //             auto unique = std::move(*(sharedResult.get()));
      //             unique->Success(flutter::EncodableValue(true));
      //             std::cout << "Unregistered/destroyed texture." << std::endl;
      //         });
      // }
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

  // std::cout << "created window size " << width << "x" << height << " at "  << left << "," << top << " with backing handle" << _backingWindow->GetHandle() << std::endl;
  std::vector<flutter::EncodableValue> resultList;
  resultList.push_back(flutter::EncodableValue()); // return null for Flutter texture ID
  resultList.push_back(flutter::EncodableValue()); // return null for hardware texture ID
  resultList.push_back(
      flutter::EncodableValue((int64_t)_backingWindow->GetHandle())); // return the HWND handle for the native window 
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

} // namespace thermion_flutter
