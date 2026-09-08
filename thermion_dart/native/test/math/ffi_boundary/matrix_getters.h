#pragma once

// Use the production struct layout, without linking Filament or Thermion.
#include "../../../include/c_api/APIBoundaryTypes.h"

EMSCRIPTEN_KEEPALIVE double4x4 MatrixBenchmark_getValue(
    const double4x4* matrices, unsigned int index);
EMSCRIPTEN_KEEPALIVE void MatrixBenchmark_getInto(
    const double4x4* matrices, unsigned int index, double* output);
