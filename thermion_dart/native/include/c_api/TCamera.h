#pragma once

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "ThermionDartApi.h"

enum Projection {
    Perspective,
    Orthographic
};

// Camera methods
EMSCRIPTEN_KEEPALIVE void set_camera_exposure(TCamera *camera, float aperture, float shutterSpeed, float sensitivity);
EMSCRIPTEN_KEEPALIVE void set_camera_model_matrix(TCamera *camera, double4x4 matrix);
EMSCRIPTEN_KEEPALIVE double4x4 get_camera_model_matrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 get_camera_view_matrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 get_camera_projection_matrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 get_camera_culling_projection_matrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE const double *const get_camera_frustum(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE void set_camera_projection_matrix(TCamera *camera, double4x4 matrix, double near, double far);
EMSCRIPTEN_KEEPALIVE void set_camera_projection_from_fov(TCamera *camera, double fovInDegrees, double aspect, double near, double far, bool horizontal);
EMSCRIPTEN_KEEPALIVE double get_camera_focal_length(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double Camera_getFocalLength(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double Camera_getNear(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double Camera_getCullingFar(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getViewMatrix(TCamera *const camera);
EMSCRIPTEN_KEEPALIVE double4x4 Camera_getModelMatrix(TCamera* camera);
EMSCRIPTEN_KEEPALIVE void Camera_lookAt(TCamera* camera, double3 eye, double3 focus, double3 up);

EMSCRIPTEN_KEEPALIVE double get_camera_near(TCamera *camera);
EMSCRIPTEN_KEEPALIVE double get_camera_culling_far(TCamera *camera);
EMSCRIPTEN_KEEPALIVE float get_camera_fov(TCamera *camera, bool horizontal);
EMSCRIPTEN_KEEPALIVE void set_camera_focus_distance(TCamera *camera, float focusDistance);

EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCulling(TCamera* camera, double4x4 projectionMatrix, double near, double far);
EMSCRIPTEN_KEEPALIVE void Camera_setModelMatrix(TCamera* camera, double4x4 modelMatrix);
EMSCRIPTEN_KEEPALIVE void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength);
EMSCRIPTEN_KEEPALIVE EntityId Camera_getEntity(TCamera* camera);
EMSCRIPTEN_KEEPALIVE void Camera_setProjection(TCamera *const tCamera, Projection projection, double left, double right,
            double bottom, double top,
            double near, double far);

#ifdef __cplusplus
}
}
#endif
