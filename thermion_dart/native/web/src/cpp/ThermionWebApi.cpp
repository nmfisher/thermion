#include "ThermionWebApi.h"

#include <thread>
#include <mutex>
#include <future>
#include <iostream>
#include <vector>

#include <backend/Platform.h>
#include <backend/platforms/PlatformWebGL.h>
#include <backend/platforms/WebGPUPlatform.h>
#include <webgpu/webgpu_cpp.h>

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

namespace {

class ThermionWebGPUPlatform : public filament::backend::WebGPUPlatform {
public:
    wgpu::Extent2D getSurfaceExtent(void* /*nativeWindow*/) const override {
        int width = 0;
        int height = 0;
        emscripten_get_canvas_element_size("#thermion_canvas", &width, &height);
        return wgpu::Extent2D{
            .width = static_cast<uint32_t>(width),
            .height = static_cast<uint32_t>(height),
        };
    }

    wgpu::Surface createSurface(void* /*nativeWindow*/, uint64_t /*flags*/) override {
        wgpu::SurfaceDescriptorFromCanvasHTMLSelector canvasDesc{};
        canvasDesc.selector = "#thermion_canvas";
        wgpu::SurfaceDescriptor surfDesc{};
        surfDesc.nextInChain = &canvasDesc;
        return mInstance.CreateSurface(&surfDesc);
    }

protected:
    std::vector<wgpu::RequestAdapterOptions> getAdapterOptions() override {
        return { wgpu::RequestAdapterOptions{} };
    }
};

} // namespace

extern "C"
{

  EMSCRIPTEN_KEEPALIVE void Thermion_setCanvasElementSize(const char *elementName, int width, int height) {
    if(emscripten_set_canvas_element_size(elementName, width, height) == EM_TRUE) {
      std::cerr << "Set canvas " << elementName << " to size " << width << "x" << height << std::endl;
    } else {
      std::cerr << "Failed to size for canvas " << elementName << std::endl;
    }
    
  }

  EMSCRIPTEN_KEEPALIVE void Thermion_destroyCanvas(const char *canvasSelector) {
    val document = val::global("document");
    val canvas = document.call<val>("querySelector", val(std::string(canvasSelector)));
    if (!canvas.isNull() && !canvas.isUndefined()) {
      canvas.call<void>("remove");
      std::cout << "Removed " << canvasSelector << " element" << std::endl;
    } else {
      std::cout << canvasSelector << " element not found" << std::endl;
    }
  }

  static EMSCRIPTEN_WEBGL_CONTEXT_HANDLE _context;

  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_getGLContext() {
    return _context;
  }

  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext(const char *canvasSelector) {

    std::cout << "Creating WebGL context for " << canvasSelector << std::endl;

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

    _context = emscripten_webgl_create_context(canvasSelector, &attr);

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

  EMSCRIPTEN_KEEPALIVE void *Thermion_createWebGPUPlatform() {
    std::cout << "Creating WebGPU platform." << std::endl;
    return static_cast<filament::backend::Platform *>(new ThermionWebGPUPlatform());
  }

}
