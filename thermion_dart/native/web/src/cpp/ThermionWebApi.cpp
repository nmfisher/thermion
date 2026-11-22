#include "ThermionWebApi.h"
#include "WebGLContext.hpp"
#include "rendering/WebJobThread.hpp"

#include <thread>
#include <mutex>
#include <future>
#include <iostream>
#include <string>
#include <vector>

#include <backend/Platform.h>
#include <backend/platforms/PlatformWebGL.h>
#if defined(THERMION_SUPPORTS_WEBGPU)
#include <backend/platforms/WebGPUPlatform.h>
#include <webgpu/webgpu_cpp.h>
#endif

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

namespace thermion {

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE createWebGLContextForCurrentJob() {
  const char* selector = WebJobThread::currentCanvasSelector();
  if (!selector) {
    std::cerr << "Web engine creation requires a WebJobThread job" << std::endl;
    return 0;
  }
  return Thermion_createGLContext(selector);
}

} // namespace thermion

namespace {

#if defined(THERMION_SUPPORTS_WEBGPU)
class ThermionWebGPUPlatform : public filament::backend::WebGPUPlatform {
public:
    // The canvas selector is resolved once, at platform creation (which
    // runs on the viewer's job thread), so multi-viewer setups render to
    // their own canvas instead of a hardcoded one. Mirrors the fallback
    // WebJobThread uses when no selector was configured.
    explicit ThermionWebGPUPlatform(const char* canvasSelector)
        : _canvasSelector(canvasSelector ? canvasSelector : "#thermion_canvas") {}

    wgpu::Extent2D getSurfaceExtent(void* /*nativeWindow*/) const override {
        int width = 0;
        int height = 0;
        emscripten_get_canvas_element_size(_canvasSelector.c_str(), &width, &height);
        return wgpu::Extent2D{
            .width = static_cast<uint32_t>(width),
            .height = static_cast<uint32_t>(height),
        };
    }

    wgpu::Surface createSurface(void* /*nativeWindow*/, uint64_t /*flags*/) override {
        wgpu::SurfaceDescriptorFromCanvasHTMLSelector canvasDesc{};
        canvasDesc.selector = _canvasSelector.c_str();
        wgpu::SurfaceDescriptor surfDesc{};
        surfDesc.nextInChain = &canvasDesc;
        return mInstance.CreateSurface(&surfDesc);
    }

protected:
    std::vector<wgpu::RequestAdapterOptions> getAdapterOptions() override {
        return { wgpu::RequestAdapterOptions{} };
    }

private:
    std::string _canvasSelector;
};
#endif // THERMION_SUPPORTS_WEBGPU

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
#ifdef THERMION_WEB_MAIN_THREAD
    attr.explicitSwapControl = EM_FALSE;
#else
    attr.explicitSwapControl = EM_TRUE;
#endif
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
      glClear(GL_COLOR_BUFFER_BIT);
    }
    std::cout << "Returning context" << std::endl;
    return _context;
  }

#if defined(THERMION_SUPPORTS_WEBGPU)
  EMSCRIPTEN_KEEPALIVE void *Thermion_createWebGPUPlatform() {
    // Honor the canvas selector configured for this viewer's job thread
    // (Engine_create on the web runs inside that thread's job), falling
    // back to the legacy default canvas.
    const char* canvasSelector = thermion::WebJobThread::currentCanvasSelector();
    if (!canvasSelector) {
      canvasSelector = "#thermion_canvas";
    }
    std::cout << "Creating WebGPU platform for canvas " << canvasSelector << std::endl;
    return static_cast<filament::backend::Platform *>(new ThermionWebGPUPlatform(canvasSelector));
  }
#endif

}
