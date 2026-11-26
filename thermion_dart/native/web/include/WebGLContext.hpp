#pragma once

#include <emscripten/html5_webgl.h>

namespace thermion {

// Creates a context for the executing web job. Returns zero outside a job.
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE createWebGLContextForCurrentJob();

// Selector ("#id") of the hidden canvas backing offscreen swapchains
// (Thermion_createOffscreenSwapChain) for the viewer canvas
// [canvasSelector], creating the canvas on first use. Shared by
// Thermion_getOffscreenCanvasSelector and Thermion_createOffscreenSwapChain
// so both resolve the same canvas. Null without a document.
const char *offscreenCanvasSelectorFor(const char *canvasSelector);

} // namespace thermion
