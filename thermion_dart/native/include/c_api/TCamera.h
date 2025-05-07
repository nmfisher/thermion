#pragma once

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
void Camera_setExposure(TCamera *camera, float aperture, float shutterSpeed, float sensitivity);
double4x4 Camera_getModelMatrix(TCamera *const camera);
double4x4 Camera_getViewMatrix(TCamera *const camera);
double4x4 Camera_getProjectionMatrix(TCamera *const camera);
double4x4 Camera_getCullingProjectionMatrix(TCamera *const camera);
void Camera_getFrustum(TCamera *camera, double* out);
void Camera_setProjectionMatrix(TCamera *camera, double *matrix, double near, double far);
void Camera_setProjectionFromFov(TCamera *camera, double fovInDegrees, double aspect, double near, double far, bool horizontal);
double Camera_getFocalLength(TCamera *const camera);
double4x4 Camera_getViewMatrix(TCamera *const camera);
double4x4 Camera_getModelMatrix(TCamera* camera);
void Camera_lookAt(TCamera* camera, double3 eye, double3 focus, double3 up);

double Camera_getNear(TCamera *camera);
double Camera_getCullingFar(TCamera *camera);
float Camera_getFov(TCamera *camera, bool horizontal);
double Camera_getFocusDistance(TCamera *camera);
void Camera_setFocusDistance(TCamera *camera, float focusDistance);

void Camera_setCustomProjectionWithCulling(
    TCamera* camera,
    double4x4 projectionMatrix,
    double near,
    double far
);
void Camera_setModelMatrix(TCamera* camera, double *tModelMatrix);
void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength);
EntityId Camera_getEntity(TCamera* camera);
void Camera_setProjection(TCamera *const tCamera, TProjection projection, double left, double right,
            double bottom, double top,
            double near, double far);

#ifdef __cplusplus
}
}
#endif
