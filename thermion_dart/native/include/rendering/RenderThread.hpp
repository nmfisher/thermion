#pragma once

// Select one concrete implementation at compile time. The C API uses the same
// name without virtual dispatch or a separately allocated implementation object.
#ifdef __EMSCRIPTEN__
#include "rendering/WebRenderThread.hpp"
namespace thermion { using RenderThread = WebRenderThread; }
#else
#include "rendering/NativeRenderThread.hpp"
namespace thermion { using RenderThread = NativeRenderThread; }
#endif
