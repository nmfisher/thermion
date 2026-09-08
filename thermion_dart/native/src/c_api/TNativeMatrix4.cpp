#include "c_api/TNativeMatrix4.h"
#include <math/mat4.h>

extern "C" {
EMSCRIPTEN_KEEPALIVE TNativeMatrix4* NativeMatrix4_create() {
    return reinterpret_cast<TNativeMatrix4*>(new filament::math::mat4());
}
EMSCRIPTEN_KEEPALIVE double* NativeMatrix4_getData(TNativeMatrix4* matrix) {
    return &(*reinterpret_cast<filament::math::mat4*>(matrix))[0][0];
}
EMSCRIPTEN_KEEPALIVE void NativeMatrix4_destroy(TNativeMatrix4* matrix) {
    delete reinterpret_cast<filament::math::mat4*>(matrix);
}
}
