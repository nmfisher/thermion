#include "ThermionWebApi.h"

#include <thread>
#include <mutex>
#include <future>
#include <iostream>

#include <backend/Platform.h>
#include <backend/platforms/PlatformWebGL.h>

#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#include <emscripten/fetch.h>
#include <emscripten/console.h>
#include <emscripten/bind.h>

using emscripten::val;

extern "C"
{

  EMSCRIPTEN_KEEPALIVE void Thermion_resizeCanvas(int width, int height) {
    emscripten_set_canvas_element_size("#thermion_canvas", width, height);
  }

  EMSCRIPTEN_KEEPALIVE void Thermion_destroyCanvas() {
    val document = val::global("document");
    val canvas = document.call<val>("querySelector", val("#thermion_canvas"));
    if (!canvas.isNull() && !canvas.isUndefined()) {
      canvas.call<void>("remove");
      std::cout << "Removed #thermion_canvas element" << std::endl;
    } else {
      std::cout << "#thermion_canvas element not found" << std::endl;
    }
  }

  static EMSCRIPTEN_WEBGL_CONTEXT_HANDLE _context;

  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_getGLContext() {
    return _context;
  }

  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext() {
    
    std::cout << "Creating WebGL context." << std::endl;

    EmscriptenWebGLContextAttributes attr;
    
    emscripten_webgl_init_context_attributes(&attr);
    attr.alpha = EM_TRUE; 
    attr.depth = EM_TRUE;  
    attr.stencil = EM_TRUE; 
    attr.antialias = EM_FALSE; 
    attr.explicitSwapControl = EM_TRUE; 
    attr.preserveDrawingBuffer = EM_FALSE; 
    attr.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_DISALLOW; 
    attr.enableExtensionsByDefault = EM_TRUE;
    attr.renderViaOffscreenBackBuffer = EM_FALSE;
    attr.majorVersion = 2;
    
    _context = emscripten_webgl_create_context("#thermion_canvas", &attr);

    if(!_context) {
      std::cout << "Failed to create WebGL context" << std::endl;  
      return _context;
    }
    
    std::cout << "Created WebGL context " << attr.majorVersion << "." << attr.minorVersion << std::endl;

    auto success = emscripten_webgl_make_context_current(_context);
    if(success != EMSCRIPTEN_RESULT_SUCCESS) {
      std::cout << "Failed to make WebGL context current"<< std::endl;
    } else { 
      std::cout << "Made WebGL context current"<< std::endl;
      // try {
      //   glClearColor(0.0, 0.0, 1.0, 1.0);
      // } catch(...) {
      //   std::cout << "Caught err"<< std::endl;
      // }
      glClear(GL_COLOR_BUFFER_BIT);
    }
    std::cout << "Returning context" << std::endl;
    return _context;
  }

}
