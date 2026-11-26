#include "ThermionWebApi.h"
#include "WebGLContext.hpp"
#include "rendering/JobThread.hpp"
#include "rendering/WebJobThread.hpp"

#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <future>
#include <iostream>

#include <backend/Platform.h>
#include <backend/platforms/PlatformWebGL.h>
#include <filament/Engine.h>

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

// ---------------------------------------------------------------------------
// Hidden canvas backing an offscreen swapchain (Thermion_createOffscreenSwapChain).
// One canvas per viewer canvas, created on first use and reused by later
// swapchains.
// ---------------------------------------------------------------------------

// DOM id of the hidden canvas for a viewer canvas selector: the viewer's id
// (minus the leading '#') plus a fixed suffix, so JavaScript can also locate
// it directly. Selectors that are not a plain "#id" share one canvas.
static std::string offscreenCanvasId(const char *canvasSelector) {
  std::string id = (canvasSelector && canvasSelector[0] == '#') ? canvasSelector + 1 : "thermion_canvas";
  return id + "__thermion_offscreen";
}

// Creates the hidden canvas for [canvasSelector] unless it already exists.
// Returns false when the page has no document (e.g. running in a worker
// without DOM access), in which case offscreen swapchains are unavailable.
static bool ensureOffscreenCanvas(const char *canvasSelector) {
  val document = val::global("document");
  if (document.isUndefined() || document.isNull()) return false;
  val body = document["body"];
  if (body.isUndefined() || body.isNull()) return false;

  const std::string id = offscreenCanvasId(canvasSelector);
  val existing = document.call<val>("querySelector", val("#" + id));
  if (!existing.isNull() && !existing.isUndefined()) return true;

  val canvas = document.call<val>("createElement", val("canvas"));
  canvas.set("id", val(id));
  // Start at the viewer canvas' size; Filament reconfigures the surface
  // (and so resizes this canvas) whenever the viewer canvas changes size.
  if (canvasSelector) {
    val visible = document.call<val>("querySelector", val(std::string(canvasSelector)));
    if (!visible.isNull() && !visible.isUndefined()) {
      canvas.set("width", visible["width"]);
      canvas.set("height", visible["height"]);
    }
  }
  // Never visible: the browser skips presenting it, JavaScript composites
  // the frames itself.
  canvas["style"].set("display", val("none"));
  body.call<void>("appendChild", canvas);
  return true;
}

// Selector -> stable storage for the returned const char*, alive until the
// viewer canvas is destroyed.
static std::mutex offscreenSelectorsMutex;
static std::map<std::string, std::string> offscreenSelectors;

// Shared by the C API (the Dart getter and Thermion_createOffscreenSwapChain)
// so both always resolve the same hidden canvas for a viewer canvas.
const char *offscreenCanvasSelectorFor(const char *canvasSelector) {
  if (!thermion::ensureOffscreenCanvas(canvasSelector)) {
    std::cerr << "Offscreen swapchains need a document body to host their canvas" << std::endl;
    return nullptr;
  }
  std::lock_guard<std::mutex> lock(thermion::offscreenSelectorsMutex);
  // Operator[] keeps the stored string's address stable across calls.
  std::string &selector = thermion::offscreenSelectors[canvasSelector ? canvasSelector : ""];
  if (selector.empty()) {
    selector = "#" + thermion::offscreenCanvasId(canvasSelector);
  }
  return selector.c_str();
}

static void removeOffscreenCanvas(const char *canvasSelector) {
  {
    std::lock_guard<std::mutex> lock(offscreenSelectorsMutex);
    offscreenSelectors.erase(canvasSelector ? canvasSelector : "");
  }
  val document = val::global("document");
  if (document.isUndefined() || document.isNull()) return;
  val canvas = document.call<val>("querySelector", val("#" + offscreenCanvasId(canvasSelector)));
  if (!canvas.isNull() && !canvas.isUndefined()) {
    canvas.call<void>("remove");
  }
}

} // namespace thermion

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
    // The hidden canvas for offscreen swapchains belongs to this viewer
    // canvas; it must not outlive it.
    thermion::removeOffscreenCanvas(canvasSelector);

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

  EMSCRIPTEN_KEEPALIVE const char *Thermion_getOffscreenCanvasSelector(TJobThread *jobThread) {
    // Resolve the viewer canvas from the job thread's stored selector, the
    // same value Thermion_createWebGPUPlatform uses, so the getter always
    // matches the canvas createSurface renders offscreen frames into.
    auto *rt = reinterpret_cast<thermion::JobThread *>(jobThread);
    if (!rt) {
      std::cerr << "Thermion_getOffscreenCanvasSelector requires a job thread" << std::endl;
      return nullptr;
    }
    return thermion::offscreenCanvasSelectorFor(rt->canvasSelector());
  }

#if !defined(THERMION_SUPPORTS_WEBGPU)
  // WebGPU builds define this next to the platform (ThermionWebGPUPlatform.cpp).
  EMSCRIPTEN_KEEPALIVE uint32_t Thermion_exportWebGPUDevice(void) {
    return 0;
  }
#endif

#if defined(THERMION_SUPPORTS_WEBGPU)
  EMSCRIPTEN_KEEPALIVE TSwapChain *Thermion_createOffscreenSwapChain(TEngine *tEngine, uint64_t flags) {
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    if (!engine) {
      return nullptr;
    }
    // Same viewer-canvas resolution as Thermion_createWebGPUPlatform: the
    // selector of the job thread running this job, so the hidden canvas
    // belongs to this engine's own viewer canvas.
    const char *viewerSelector = thermion::WebJobThread::currentCanvasSelector();
    // offscreenCanvasSelectorFor reports (and returns nullptr for) a page
    // without a document body: an offscreen swapchain needs its hidden
    // canvas, so there is nothing to fall back to.
    const char *offscreenSelector = thermion::offscreenCanvasSelectorFor(
        viewerSelector ? viewerSelector : "#thermion_canvas");
    if (!offscreenSelector) {
      return nullptr;
    }
    // The hidden canvas is the swapchain's surface target: the WebGPU
    // platform takes a canvas selector through the native window handle.
    // flags reach Filament untouched (pure SWAP_CHAIN_CONFIG_* values).
    auto *swapChain = engine->createSwapChain(const_cast<char *>(offscreenSelector), flags);
    return reinterpret_cast<TSwapChain *>(swapChain);
  }

  EMSCRIPTEN_KEEPALIVE void Thermion_createOffscreenSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    auto *rt = reinterpret_cast<thermion::JobThread *>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *swapChain = Thermion_createOffscreenSwapChain(tEngine, flags);
          rt->dispatchCallback([=]() { onComplete(swapChain); });
        });
    auto fut = rt->addTask(lambda);
  }
#endif

}
