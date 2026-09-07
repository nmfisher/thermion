#pragma once

#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#include "APIExport.h"

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "APIBoundaryTypes.h"

enum TProjection {
    Perspective,
    Orthographic
};
typedef enum TProjection TProjection;

// Camera methods
EMSCRIPTEN_KEEPALIVE void Camera_setExposure(TCamera *camera, float aperture, float shutterSpeed, float sensitivity);
EMSCRIPTEN_KEEPALIVE float Camera_getAperture(TCamera *camera);
EMSCRIPTEN_KEEPALIVE float Camera_getShutterSpeed(TCamera *camera);
EMSCRIPTEN_KEEPALIVE float Camera_getSensitivity(TCamera *camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getModelMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getViewMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getProjectionMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getCullingProjectionMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE void Camera_getFrustum(TCamera *camera, double* out);
EMSCRIPTEN_KEEPALIVE void Camera_setProjectionMatrix(TCamera *camera, double *matrix, double near, double far);
EMSCRIPTEN_KEEPALIVE void Camera_setProjectionFromFov(TCamera *camera, double fovInDegrees, double aspect, double near, double far, bool horizontal);
EMSCRIPTEN_KEEPALIVE double Camera_getFocalLength(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getViewMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getModelMatrix(TCamera* camera);
EMSCRIPTEN_KEEPALIVE void Camera_lookAt(TCamera* camera, double3 eye, double3 focus, double3 up);

EMSCRIPTEN_KEEPALIVE double Camera_getNear(TCamera *camera);
EMSCRIPTEN_KEEPALIVE double Camera_getCullingFar(TCamera *camera);
EMSCRIPTEN_KEEPALIVE float Camera_getFov(TCamera *camera, bool horizontal);
EMSCRIPTEN_KEEPALIVE double Camera_getFocusDistance(TCamera *camera);
EMSCRIPTEN_KEEPALIVE void Camera_setFocusDistance(TCamera *camera, float focusDistance);

EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCulling(
    TCamera* camera,
    double4x4 projectionMatrix,
    double near,
    double far
);
EMSCRIPTEN_KEEPALIVE void Camera_setModelMatrix(TCamera* camera, double *tModelMatrix);
// All buffers contain 16 column-major doubles, borrowed only during the call.
EMSCRIPTEN_KEEPALIVE void Camera_setModelMatrixNative(TCamera *camera, TNativeMatrix4 *matrix);
EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCullingNative(TCamera *camera, TNativeMatrix4 *matrix, double near, double far);
EMSCRIPTEN_KEEPALIVE void Camera_getModelMatrixNativeInto(TCamera *camera, TNativeMatrix4 *out);
EMSCRIPTEN_KEEPALIVE void Camera_getViewMatrixNativeInto(TCamera *camera, TNativeMatrix4 *out);
EMSCRIPTEN_KEEPALIVE void Camera_getProjectionMatrixNativeInto(TCamera *camera, TNativeMatrix4 *out);
EMSCRIPTEN_KEEPALIVE void Camera_getCullingProjectionMatrixNativeInto(TCamera *camera, TNativeMatrix4 *out);
EMSCRIPTEN_KEEPALIVE void Camera_setModelMatrixFromBuffer(TCamera *camera, const double *matrix16);
EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCullingFromBuffer(TCamera *camera, const double *matrix16, double near, double far);
EMSCRIPTEN_KEEPALIVE void Camera_getModelMatrixInto(TCamera *camera, double *out16);
EMSCRIPTEN_KEEPALIVE void Camera_getViewMatrixInto(TCamera *camera, double *out16);
EMSCRIPTEN_KEEPALIVE void Camera_getProjectionMatrixInto(TCamera *camera, double *out16);
EMSCRIPTEN_KEEPALIVE void Camera_getCullingProjectionMatrixInto(TCamera *camera, double *out16);
EMSCRIPTEN_KEEPALIVE void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength);
EMSCRIPTEN_KEEPALIVE EntityId Camera_getEntity(TCamera* camera);
EMSCRIPTEN_KEEPALIVE void Camera_setProjection(TCamera *const tCamera, TProjection projection, double left, double right,
            double bottom, double top,
            double near, double far);

#ifdef __cplusplus
}
}
#endif
