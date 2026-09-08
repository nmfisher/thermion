#include "matrix_getters.h"
#include <string.h>

// Both functions copy the same 128 bytes. No matrix computation, allocation,
// conversion, or engine lookup is included in either path.
double4x4 MatrixBenchmark_getValue(const double4x4* matrices, unsigned int index) {
    return matrices[index];
}

void MatrixBenchmark_getInto(const double4x4* matrices, unsigned int index, double* output) {
    memcpy(output, &matrices[index], sizeof(double4x4));
}
