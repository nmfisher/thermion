#include <filament/View.h>
#include <filament/Viewport.h>
#include <filament/Engine.h>
#include <filament/ToneMapper.h>
#include <filament/ColorGrading.h>
#include <filament/Camera.h>
#include <utils/Entity.h>

#include "c_api/ThermionDartApi.h"
#include "c_api/TCamera.h"
#include "Log.hpp"
#include "MathUtils.hpp"


#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;

#endif
                
        EMSCRIPTEN_KEEPALIVE void Camera_lookAt(TCamera *tCamera, double3 eye, double3 focus, double3 up) {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            camera->lookAt(
                filament::math::float3 { static_cast<float>(eye.x), static_cast<float>(eye.y), static_cast<float>(eye.z) },
                filament::math::float3 { static_cast<float>(focus.x), static_cast<float>(focus.y), static_cast<float>(focus.z) },
                filament::math::float3 { static_cast<float>(up.x), static_cast<float>(up.y), static_cast<float>(up.z) }
            );
        }

        EMSCRIPTEN_KEEPALIVE void Camera_getFrustum(TCamera *tCamera, double *out) {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            auto &frustum = camera->getFrustum();
            auto planes = frustum.getPlanes();
            for(int i = 0; i < 6; i++) {
                for(int j = 0; j < 4; j++) {
                    out[(i*4) + j] = planes[i][j];
                }
            }
        }

        EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCulling(TCamera *tCamera, double4x4 projectionMatrix, double near, double far)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            camera->setCustomProjection(convert_double4x4_to_mat4(projectionMatrix), near, far);
        }

        EMSCRIPTEN_KEEPALIVE double4x4 Camera_getModelMatrix(TCamera *tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return convert_mat4_to_double4x4(camera->getModelMatrix());
        }

        EMSCRIPTEN_KEEPALIVE double4x4 Camera_getViewMatrix(TCamera *const tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return convert_mat4_to_double4x4(camera->getViewMatrix());
        }

        EMSCRIPTEN_KEEPALIVE EntityId Camera_getEntity(TCamera *tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return utils::Entity::smuggle(camera->getEntity());
        }

        EMSCRIPTEN_KEEPALIVE double Camera_getFocalLength(TCamera *const tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return camera->getFocalLength() * 1000.0;
        }

        EMSCRIPTEN_KEEPALIVE double Camera_getNear(TCamera *const tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return camera->getNear();
        }

        EMSCRIPTEN_KEEPALIVE double Camera_getCullingFar(TCamera *const tCamera)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            return camera->getCullingFar();
        }

        EMSCRIPTEN_KEEPALIVE void Camera_setProjection(TCamera *const tCamera, Projection projection, double left, double right,
                                                       double bottom, double top,
                                                       double near, double far)
        {
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            filament::Camera::Projection filamentProjection;
            switch(projection) {
                case Projection::Orthographic:
                    filamentProjection = filament::Camera::Projection::ORTHO; 
                case Projection::Perspective:
                    filamentProjection = filament::Camera::Projection::PERSPECTIVE; 
            }
            camera->setProjection(filamentProjection, left, right, bottom, top, near, far);
        }

#ifdef __cplusplus
    }
}
#endif
