#pragma once

#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "APIExport.h"
#include "APIBoundaryTypes.h"

enum TProjection {
    Perspective,
    Orthographic
};
typedef enum TProjection TProjection;

// Camera methods
EMSCRIPTEN_KEEPALIVE void Camera_setExposure(TCamera *camera, float aperture, float shutterSpeed, float sensitivity);
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
EMSCRIPTEN_KEEPALIVE void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength);
EMSCRIPTEN_KEEPALIVE EntityId Camera_getEntity(TCamera* camera);
EMSCRIPTEN_KEEPALIVE void Camera_setProjection(TCamera *const tCamera, TProjection projection, double left, double right,
            double bottom, double top,
            double near, double far);

#ifdef __cplusplus
}
}
#endif
