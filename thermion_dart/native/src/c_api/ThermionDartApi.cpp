#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#include <thread>
#include <functional>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

#include "filament/LightManager.h"
#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/ThermionDartApi.h"

    EMSCRIPTEN_KEEPALIVE TViewer *Viewer_create(const void *context, const void *const loader, void *const platform, const char *uberArchivePath)
    {
        const auto *loaderImpl = new ResourceLoaderWrapperImpl((ResourceLoaderWrapper *)loader);
        auto viewer = new FilamentViewer(context, loaderImpl, platform, uberArchivePath);
        return reinterpret_cast<TViewer *>(viewer);
    }

    EMSCRIPTEN_KEEPALIVE TEngine *Viewer_getEngine(TViewer *viewer)
    {
        auto *engine = reinterpret_cast<FilamentViewer *>(viewer)->getEngine();
        return reinterpret_cast<TEngine *>(engine);
    }

    EMSCRIPTEN_KEEPALIVE TRenderTarget *Viewer_createRenderTarget(TViewer *tViewer, intptr_t texture, uint32_t width, uint32_t height)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto renderTarget = viewer->createRenderTarget(texture, width, height);
        return reinterpret_cast<TRenderTarget *>(renderTarget);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_destroyRenderTarget(TViewer *tViewer, TRenderTarget *tRenderTarget)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto renderTarget = reinterpret_cast<RenderTarget *>(tRenderTarget);
        viewer->destroyRenderTarget(renderTarget);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_destroy(TViewer *viewer)
    {
        delete ((FilamentViewer *)viewer);
    }

    EMSCRIPTEN_KEEPALIVE void set_background_color(TViewer *viewer, const float r, const float g, const float b, const float a)
    {
        ((FilamentViewer *)viewer)->setBackgroundColor(r, g, b, a);
    }

    EMSCRIPTEN_KEEPALIVE void clear_background_image(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->clearBackgroundImage();
    }

    EMSCRIPTEN_KEEPALIVE void set_background_image(TViewer *viewer, const char *path, bool fillHeight)
    {
        ((FilamentViewer *)viewer)->setBackgroundImage(path, fillHeight, 100, 100);
    }

    EMSCRIPTEN_KEEPALIVE void set_background_image_position(TViewer *viewer, float x, float y, bool clamp)
    {
        ((FilamentViewer *)viewer)->setBackgroundImagePosition(x, y, clamp, 100, 100);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_loadSkybox(TViewer *viewer, const char *skyboxPath)
    {
        ((FilamentViewer *)viewer)->loadSkybox(skyboxPath);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_removeSkybox(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->removeSkybox();
    }

    EMSCRIPTEN_KEEPALIVE void create_ibl(TViewer *viewer, float r, float g, float b, float intensity)
    {
        ((FilamentViewer *)viewer)->createIbl(r, g, b, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_loadIbl(TViewer *viewer, const char *iblPath, float intensity)
    {
        ((FilamentViewer *)viewer)->loadIbl(iblPath, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_removeIbl(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->removeIbl();
    }

    EMSCRIPTEN_KEEPALIVE void rotate_ibl(TViewer *viewer, float *rotationMatrix)
    {
        math::mat3f matrix(rotationMatrix[0], rotationMatrix[1],
                           rotationMatrix[2],
                           rotationMatrix[3],
                           rotationMatrix[4],
                           rotationMatrix[5],
                           rotationMatrix[6],
                           rotationMatrix[7],
                           rotationMatrix[8]);

        ((FilamentViewer *)viewer)->rotateIbl(matrix);
    }

    EMSCRIPTEN_KEEPALIVE int get_instance_count(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->getInstanceCount(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void get_instances(TSceneManager *sceneManager, EntityId entityId, EntityId *out)
    {
        return ((SceneManager *)sceneManager)->getInstances(entityId, out);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_setMainCamera(TViewer *tViewer, TView *tView)
    {
        auto *viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto *view = reinterpret_cast<View *>(tView);
        viewer->setMainCamera(view);
    }

    EMSCRIPTEN_KEEPALIVE EntityId Viewer_getMainCamera(TViewer *viewer)
    {
        return ((FilamentViewer *)viewer)->getMainCamera();
    }

    EMSCRIPTEN_KEEPALIVE float get_camera_fov(TCamera *camera, bool horizontal)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getFieldOfViewInDegrees(horizontal ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL);
    }

    EMSCRIPTEN_KEEPALIVE double get_camera_focal_length(TCamera *const camera)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getFocalLength();
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_projection_from_fov(TCamera *camera, double fovInDegrees, double aspect, double near, double far, bool horizontal)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setProjection(fovInDegrees, aspect, near, far, horizontal ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL);
    }

    EMSCRIPTEN_KEEPALIVE TCamera *get_camera(TViewer *viewer, EntityId entity)
    {
        auto filamentCamera = ((FilamentViewer *)viewer)->getCamera(entity);
        return reinterpret_cast<TCamera *>(filamentCamera);
    }

    EMSCRIPTEN_KEEPALIVE double4x4 get_camera_model_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getModelMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    EMSCRIPTEN_KEEPALIVE double4x4 get_camera_view_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getViewMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    EMSCRIPTEN_KEEPALIVE double4x4 get_camera_projection_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    EMSCRIPTEN_KEEPALIVE double4x4 get_camera_culling_projection_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getCullingProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_projection_matrix(TCamera *camera, double4x4 matrix, double near, double far)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        const auto &mat = convert_double4x4_to_mat4(matrix);
        cam->setCustomProjection(mat, near, far);
    }

    EMSCRIPTEN_KEEPALIVE void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setLensProjection(focalLength, aspect, near, far);
    }

    EMSCRIPTEN_KEEPALIVE void Camera_setModelMatrix(TCamera *camera, double4x4 matrix)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setModelMatrix(convert_double4x4_to_mat4(matrix));
    }

    EMSCRIPTEN_KEEPALIVE double get_camera_near(TCamera *camera)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getNear();
    }

    EMSCRIPTEN_KEEPALIVE double get_camera_culling_far(TCamera *camera)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getCullingFar();
    }

    EMSCRIPTEN_KEEPALIVE const double *const get_camera_frustum(TCamera *camera)
    {

        const auto frustum = reinterpret_cast<filament::Camera *>(camera)->getFrustum();

        const math::float4 *planes = frustum.getNormalizedPlanes();
        double *array = (double *)calloc(24, sizeof(double));
        for (int i = 0; i < 6; i++)
        {
            auto plane = planes[i];
            array[i * 4] = double(plane.x);
            array[i * 4 + 1] = double(plane.y);
            array[i * 4 + 2] = double(plane.z);
            array[i * 4 + 3] = double(plane.w);
        }

        return array;
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_focus_distance(TCamera *camera, float distance)
    {
        auto *cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setFocusDistance(distance);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_exposure(TCamera *camera, float aperture, float shutterSpeed, float sensitivity)
    {
        auto *cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setExposure(aperture, shutterSpeed, sensitivity);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_model_matrix(TCamera *camera, double4x4 matrix)
    {
        auto *cam = reinterpret_cast<filament::Camera *>(camera);
        const filament::math::mat4 &mat = convert_double4x4_to_mat4(matrix);
        cam->setModelMatrix(mat);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_render(
        TViewer *tViewer)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        viewer->render(0);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_setViewRenderable(TViewer *tViewer, TSwapChain *tSwapChain, TView *tView, bool renderable)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
        auto *view = reinterpret_cast<View *>(tView);
        viewer->setRenderable(view, swapChain, renderable);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_capture(
        TViewer *tViewer,
        TView *tView,
        TSwapChain *tSwapChain,
        uint8_t *pixelBuffer,
        void (*callback)(void))
    {
#ifdef __EMSCRIPTEN__
        bool useFence = true;
#else
        bool useFence = false;
#endif
        auto swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto *view = reinterpret_cast<View *>(tView);
        viewer->capture(view, pixelBuffer, useFence, swapChain, callback);
    };

    EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTarget(
        TViewer *tViewer,
        TView *tView,
        TSwapChain *tSwapChain,
        TRenderTarget *tRenderTarget,
        uint8_t *pixelBuffer,
        void (*callback)(void))
    {
#ifdef __EMSCRIPTEN__
        bool useFence = true;
#else
        bool useFence = false;
#endif
        auto swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
        auto renderTarget = reinterpret_cast<RenderTarget *>(tRenderTarget);
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto *view = reinterpret_cast<View *>(tView);
        viewer->capture(view, pixelBuffer, useFence, swapChain, renderTarget, callback);
    };

    EMSCRIPTEN_KEEPALIVE void set_frame_interval(
        TViewer *viewer,
        float frameInterval)
    {
        ((FilamentViewer *)viewer)->setFrameInterval(frameInterval);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_destroySwapChain(TViewer *tViewer, TSwapChain *tSwapChain)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
        viewer->destroySwapChain(swapChain);
    }

    EMSCRIPTEN_KEEPALIVE TSwapChain *Viewer_createHeadlessSwapChain(TViewer *tViewer, uint32_t width, uint32_t height)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = viewer->createSwapChain(width, height);
        return reinterpret_cast<TSwapChain *>(swapChain);
    }

    EMSCRIPTEN_KEEPALIVE TSwapChain *Viewer_createSwapChain(TViewer *tViewer, const void *const window)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = viewer->createSwapChain(window);
        return reinterpret_cast<TSwapChain *>(swapChain);
    }

    EMSCRIPTEN_KEEPALIVE TSwapChain *Viewer_getSwapChainAt(TViewer *tViewer, int index)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = viewer->getSwapChainAt(index);
        return reinterpret_cast<TSwapChain *>(swapChain);
    }

    EMSCRIPTEN_KEEPALIVE TView *Viewer_createView(TViewer *tViewer)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto view = viewer->createView();
        return reinterpret_cast<TView *>(view);
    }

    EMSCRIPTEN_KEEPALIVE TView *Viewer_getViewAt(TViewer *tViewer, int32_t index)
    {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto view = viewer->getViewAt(index);
        return reinterpret_cast<TView *>(view);
    }

    EMSCRIPTEN_KEEPALIVE TSceneManager *Viewer_getSceneManager(TViewer *tViewer)
    {
        auto *viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto *sceneManager = viewer->getSceneManager();
        return reinterpret_cast<TSceneManager *>(sceneManager);
    }

    EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(TSceneManager *sceneManager, TView *tView, EntityId entity, float viewportX, float viewportY)
    {
        auto *view = reinterpret_cast<View *>(tView);
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateFromViewportVector(view, entity, viewportX, viewportY);
    }

    EMSCRIPTEN_KEEPALIVE void ios_dummy()
    {
        Log("Dummy called");
    }

    EMSCRIPTEN_KEEPALIVE void thermion_filament_free(void *ptr)
    {
        free(ptr);
    }

    EMSCRIPTEN_KEEPALIVE void add_collision_component(TSceneManager *sceneManager, EntityId entityId, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform)
    {
        ((SceneManager *)sceneManager)->addCollisionComponent(entityId, onCollisionCallback, affectsCollidingTransform);
    }

    EMSCRIPTEN_KEEPALIVE void remove_collision_component(TSceneManager *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeCollisionComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void test_collisions(TSceneManager *sceneManager, EntityId entity)
    {
        ((SceneManager *)sceneManager)->testCollisions(entity);
    }

    EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(TSceneManager *sceneManager, TView *tView, EntityId entity)
    {
        auto view = reinterpret_cast<View *>(tView);
        return ((SceneManager *)sceneManager)->getScreenSpaceBoundingBox(view, entity);
    }

    EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(TSceneManager *sceneManager, TView *tView, EntityId entity, float *minX, float *minY, float *maxX, float *maxY)
    {
        auto view = reinterpret_cast<View *>(tView);
        auto box = ((SceneManager *)sceneManager)->getScreenSpaceBoundingBox(view, entity);
        *minX = box.minX;
        *minY = box.minY;
        *maxX = box.maxX;
        *maxY = box.maxY;
    }

    EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr)
    {
        free(ptr);
    }

    EMSCRIPTEN_KEEPALIVE void unproject_texture(TViewer *viewer, EntityId entity, uint8_t *input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight)
    {
        ((FilamentViewer *)viewer)->unprojectTexture(entity, input, inputWidth, inputHeight, out, outWidth, outHeight);
    }

    EMSCRIPTEN_KEEPALIVE void *const create_texture(TSceneManager *sceneManager, uint8_t *data, size_t length)
    {
        return (void *const)((SceneManager *)sceneManager)->createTexture(data, length, "SOMETEXTURE");
    }

    EMSCRIPTEN_KEEPALIVE void apply_texture_to_material(TSceneManager *sceneManager, EntityId entity, void *const texture, const char *parameterName, int materialIndex)
    {
        ((SceneManager *)sceneManager)->applyTexture(entity, reinterpret_cast<Texture *>(texture), parameterName, materialIndex);
    }

    EMSCRIPTEN_KEEPALIVE void destroy_texture(TSceneManager *sceneManager, void *const texture)
    {
        ((SceneManager *)sceneManager)->destroyTexture(reinterpret_cast<Texture *>(texture));
    }

    EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *tEngine)
    {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto &transformManager = engine->getTransformManager();
        return reinterpret_cast<TTransformManager *>(&transformManager);
    }

    EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *tEngine)
    {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto &renderableManager = engine->getRenderableManager();
        return reinterpret_cast<TRenderableManager *>(&renderableManager);
    }

    EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *tEngine) {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto &lightManager = engine->getLightManager();
        return reinterpret_cast<TLightManager *>(&lightManager);
    }

    EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *tEngine, EntityId entityId)
    {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto entity = utils::Entity::import(entityId);
        if(entity.isNull()) {
            return std::nullptr_t();
        }
        auto *camera = engine->getCameraComponent(entity);
        return reinterpret_cast<TCamera *>(camera);
    }

    EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine *tEngine, EntityId entity, double4x4 transform)
    {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto &transformManager = engine->getTransformManager();

        auto transformInstance = transformManager.getInstance(utils::Entity::import(entity));
        if (!transformInstance.isValid())
        {
            Log("Transform instance not valid");
        }
        transformManager.setTransform(transformInstance, convert_double4x4_to_mat4(transform));
    }

    EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t* materialData, size_t length) {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto *material = Material::Builder()
                    .package(materialData, length)
                    .build(*engine);
        return reinterpret_cast<TMaterial*>(material);
    }

    EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial) { 
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto *material = reinterpret_cast<Material *>(tMaterial);
        engine->destroy(material);
    }
}
