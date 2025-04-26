#include "ThermionWebApi.h"

#include <thread>
#include <mutex>
#include <future>
#include <iostream>

#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#include <emscripten/fetch.h>

using emscripten::val;

extern "C"
{
  
  // 
  // Since are using -sMAIN_MODULE with -sPTHREAD_POOL_SIZE=1, main will be called when the first worker is spawned
  //
  
  // EMSCRIPTEN_KEEPALIVE int main() {
  //   std::cout << "WEBAPI MAIN " << std::endl;
  //   return 0;
  // }

  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext() {
    
    std::cout << "Creating WebGL context." << std::endl;

    EmscriptenWebGLContextAttributes attr;
    
    emscripten_webgl_init_context_attributes(&attr);
    attr.alpha = EM_TRUE;
    attr.depth = EM_TRUE;
    attr.stencil = EM_FALSE;
    attr.antialias = EM_FALSE;
    attr.explicitSwapControl = EM_FALSE;
    attr.preserveDrawingBuffer = EM_TRUE;
    attr.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_DISALLOW;
    attr.enableExtensionsByDefault = EM_TRUE;
    attr.renderViaOffscreenBackBuffer = EM_FALSE;
    attr.majorVersion = 2;
    
    auto context = emscripten_webgl_create_context("#canvas", &attr);
    
    std::cout << "Created WebGL context " << attr.majorVersion << "." << attr.minorVersion << std::endl;

    auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)context);
    if(success != EMSCRIPTEN_RESULT_SUCCESS) {
      std::cout << "Failed to make WebGL context current"<< std::endl;
    } else { 
      std::cout << "Made WebGL context current"<< std::endl;
      try {
        glClearColor(0.0, 0.0, 1.0, 1.0);
      } catch(...) {
        std::cout << "Caught err"<< std::endl;
      }
      glClear(GL_COLOR_BUFFER_BIT);
      emscripten_webgl_commit_frame();
    }
    std::cout << "Returning context" << std::endl;
    return context;
  }

  int _lastResourceId = 0;
  
}