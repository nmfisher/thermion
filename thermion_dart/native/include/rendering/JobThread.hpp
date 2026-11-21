#pragma once

// Select one concrete implementation at compile time. The C API uses the same
// name without virtual dispatch or a separately allocated implementation object.
#ifdef __EMSCRIPTEN__
#include "rendering/WebJobThread.hpp"
namespace thermion { using JobThread = WebJobThread; }
#else
#include "rendering/NativeJobThread.hpp"
namespace thermion { using JobThread = NativeJobThread; }
#endif
