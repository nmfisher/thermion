#pragma once

#include <math/mat4.h>
#include <memory>
#include "c_api/APIBoundaryTypes.h"

namespace thermion {
// The opaque handle owns a real mat4. Queue submissions copy only the shared
// ownership handle, never the matrix values.
using NativeMatrixOwner = std::shared_ptr<filament::math::mat4>;
inline NativeMatrixOwner& nativeMatrixOwner(TNativeMatrix4* matrix) {
    return *reinterpret_cast<NativeMatrixOwner*>(matrix);
}
inline filament::math::mat4& nativeMatrix(TNativeMatrix4* matrix) {
    return *nativeMatrixOwner(matrix);
}
}
