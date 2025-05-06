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
#include <emscripten/console.h>
#include <emscripten/bind.h>

using emscripten::val;

extern "C"
{
  
  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext() {
    
    std::cout << "Creating WebGL context." << std::endl;

    EmscriptenWebGLContextAttributes attr;
    
    emscripten_webgl_init_context_attributes(&attr);
    attr.alpha = EM_TRUE; 
    attr.depth = EM_TRUE;  
    attr.stencil = EM_TRUE; 
    attr.antialias = EM_FALSE; 
    attr.explicitSwapControl = EM_FALSE; 
    attr.preserveDrawingBuffer = EM_FALSE; 
    attr.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_DISALLOW; 
    attr.enableExtensionsByDefault = EM_TRUE;
    attr.renderViaOffscreenBackBuffer = EM_FALSE;
    attr.majorVersion = 2;
    
    auto context = emscripten_webgl_create_context("#thermion_canvas", &attr);
    
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
    }
    std::cout << "Returning context" << std::endl;
    return context;
  }

  emscripten::val emscripten_make_uint8_buffer(int ptr, int length) {
    uint8_t *buffer = (uint8_t*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }

  emscripten::val emscripten_make_int16_buffer(int ptr, int length) {
    int16_t *buffer = (int16_t*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }

  emscripten::val emscripten_make_uint16_buffer(int ptr, int length) {
    uint16_t *buffer = (uint16_t*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }

  emscripten::val emscripten_make_int32_buffer(int ptr, int length) {
    int32_t *buffer = (int32_t*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }

  emscripten::val emscripten_make_f32_buffer(int ptr, int length) {
    float *buffer = (float*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }

  emscripten::val emscripten_make_f64_buffer(int ptr, int length) {
    double *buffer = (double*)ptr;
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    emscripten_console_logf("offset %d", v["byteOffset"].as<int>());
    return v;
  }


  intptr_t emscripten_get_byte_offset(emscripten::val v) {
    return v["byteOffset"].as<int>();
  }

EMSCRIPTEN_BINDINGS(module) {
  emscripten::function("_emscripten_make_uint8_buffer", &emscripten_make_uint8_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_make_uint16_buffer", &emscripten_make_uint16_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_make_int16_buffer", &emscripten_make_int16_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_make_int32_buffer", &emscripten_make_int32_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_make_f32_buffer", &emscripten_make_f32_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_make_f64_buffer", &emscripten_make_f64_buffer, emscripten::allow_raw_pointers());
  emscripten::function("_emscripten_get_byte_offset", &emscripten_get_byte_offset, emscripten::allow_raw_pointers());
}
  
}
