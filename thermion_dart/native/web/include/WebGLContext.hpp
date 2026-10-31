#pragma once

#include <emscripten/html5_webgl.h>

namespace thermion {

// Creates a context for the executing web job. Returns zero outside a job.
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE createWebGLContextForCurrentJob();

} // namespace thermion
