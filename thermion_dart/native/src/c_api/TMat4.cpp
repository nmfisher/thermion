#include "c_api/TMat4.h"
#include <math/mat4.h>

extern "C" {
EMSCRIPTEN_KEEPALIVE TMat4* Mat4_create() {
    return reinterpret_cast<TMat4*>(new filament::math::mat4());
}
EMSCRIPTEN_KEEPALIVE double* Mat4_getData(TMat4* matrix) {
    return &(*reinterpret_cast<filament::math::mat4*>(matrix))[0][0];
}
EMSCRIPTEN_KEEPALIVE void Mat4_destroy(TMat4* matrix) {
    delete reinterpret_cast<filament::math::mat4*>(matrix);
}
}
