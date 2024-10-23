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

#include "ThermionDartApi.h"

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

    EMSCRIPTEN_KEEPALIVE void Viewer_pick(TViewer *tViewer, TView* tView, int x, int y, void (*callback)(EntityId entityId, int x, int y, TView *tView))
    {
        auto *viewer = reinterpret_cast<FilamentViewer*>(tViewer);
        auto *view = reinterpret_cast<View*>(tView);
        ((FilamentViewer *)viewer)->pick(view, static_cast<uint32_t>(x), static_cast<uint32_t>(y), reinterpret_cast<void (*)(EntityId entityId, int x, int y, View *view)>(callback));
    }

    EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer(TViewer *viewer)
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


    EMSCRIPTEN_KEEPALIVE void load_skybox(TViewer *viewer, const char *skyboxPath)
    {
        ((FilamentViewer *)viewer)->loadSkybox(skyboxPath);
    }

    EMSCRIPTEN_KEEPALIVE void create_ibl(TViewer *viewer, float r, float g, float b, float intensity)
    {
        ((FilamentViewer *)viewer)->createIbl(r, g, b, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_loadIbl(TViewer *viewer, const char *iblPath, float intensity)
    {
        ((FilamentViewer *)viewer)->loadIbl(iblPath, intensity);
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

    EMSCRIPTEN_KEEPALIVE void remove_skybox(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->removeSkybox();
    }

    EMSCRIPTEN_KEEPALIVE void remove_ibl(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->removeIbl();
    }

    EMSCRIPTEN_KEEPALIVE EntityId add_light(
        TViewer *viewer,
        uint8_t type,
        float colour,
        float intensity,
        float posX,
        float posY,
        float posZ,
        float dirX,
        float dirY,
        float dirZ,
        float falloffRadius,
        float spotLightConeInner,
        float spotLightConeOuter,
        float sunAngularRadius,
        float sunHaloSize,
        float sunHaloFallof,
        bool shadows)
    {
        return ((FilamentViewer *)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, falloffRadius, spotLightConeInner, spotLightConeOuter, sunAngularRadius, sunHaloSize, sunHaloFallof, shadows);
    }

    EMSCRIPTEN_KEEPALIVE void set_light_position(TViewer *viewer, int32_t entityId, float x, float y, float z)
    {
        ((FilamentViewer *)viewer)->setLightPosition(entityId, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void set_light_direction(TViewer *viewer, int32_t entityId, float x, float y, float z)
    {
        ((FilamentViewer *)viewer)->setLightDirection(entityId, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void remove_light(TViewer *viewer, int32_t entityId)
    {
        ((FilamentViewer *)viewer)->removeLight(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void clear_lights(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->clearLights();
    }

    EMSCRIPTEN_KEEPALIVE EntityId load_glb(TSceneManager *sceneManager, const char *assetPath, int numInstances, bool keepData)
    {
        return ((SceneManager *)sceneManager)->loadGlb(assetPath, numInstances, keepData);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneManager_loadGlbFromBuffer(TSceneManager *sceneManager, const uint8_t *const data, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync)
    {
        return ((SceneManager *)sceneManager)->loadGlbFromBuffer((const uint8_t *)data, length, 1, keepData, priority, layer);
    }

    EMSCRIPTEN_KEEPALIVE EntityId create_instance(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->createInstance(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_instance_count(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->getInstanceCount(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void get_instances(TSceneManager *sceneManager, EntityId entityId, EntityId *out)
    {
        return ((SceneManager *)sceneManager)->getInstances(entityId, out);
    }

    EMSCRIPTEN_KEEPALIVE EntityId load_gltf(TSceneManager *sceneManager, const char *assetPath, const char *relativePath, bool keepData)
    {
        return ((SceneManager *)sceneManager)->loadGltf(assetPath, relativePath, keepData);
    }

    EMSCRIPTEN_KEEPALIVE void Viewer_setMainCamera(TViewer *tViewer, TView *tView)
    {
        auto *viewer = reinterpret_cast<FilamentViewer*>(tViewer);
        auto *view = reinterpret_cast<View*>(tView);
        viewer->setMainCamera(view);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_main_camera(TViewer *viewer)
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

    EMSCRIPTEN_KEEPALIVE void Viewer_setViewRenderable(TViewer *tViewer, TSwapChain *tSwapChain, TView *tView, bool renderable) {
        auto viewer = reinterpret_cast<FilamentViewer *>(tViewer);
        auto swapChain = reinterpret_cast<SwapChain*>(tSwapChain);
        auto *view = reinterpret_cast<View*>(tView);
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
        auto *view = reinterpret_cast<View*>(tView);
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
        auto *view = reinterpret_cast<View*>(tView);
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

    EMSCRIPTEN_KEEPALIVE TSwapChain* Viewer_getSwapChainAt(TViewer *tViewer, int index) { 
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

    EMSCRIPTEN_KEEPALIVE void apply_weights(
        TSceneManager *sceneManager,
        EntityId asset,
        const char *const entityName,
        float *const weights,
        int count)
    {
        // ((SceneManager*)sceneManager)->setMorphTargetWeights(asset, entityName, weights, count);
    }

    EMSCRIPTEN_KEEPALIVE bool set_morph_target_weights(
        TSceneManager *sceneManager,
        EntityId asset,
        const float *const weights,
        const int numWeights)
    {
        return ((SceneManager *)sceneManager)->setMorphTargetWeights(asset, weights, numWeights);
    }

    EMSCRIPTEN_KEEPALIVE bool SceneManager_setMorphAnimation(
        TSceneManager *sceneManager,
        EntityId asset,
        const float *const morphData,
        const uint32_t *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        auto result = ((SceneManager *)sceneManager)->setMorphAnimationBuffer(asset, morphData, morphIndices, numMorphTargets, numFrames, frameLengthInMs);
        return result;
    }

    EMSCRIPTEN_KEEPALIVE void clear_morph_animation(TSceneManager *sceneManager, EntityId asset)
    {
        ((SceneManager *)sceneManager)->clearMorphAnimationBuffer(asset);
    }

    EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose(TSceneManager *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->resetBones(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void add_bone_animation(
        TSceneManager *sceneManager,
        EntityId asset,
        int skinIndex,
        int boneIndex,
        const float *const frameData,
        int numFrames,
        float frameLengthInMs,
        float fadeOutInSecs,
        float fadeInInSecs,
        float maxDelta)
    {
        ((SceneManager *)sceneManager)->addBoneAnimation(asset, skinIndex, boneIndex, frameData, numFrames, frameLengthInMs, fadeOutInSecs, fadeInInSecs, maxDelta);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_bone(TSceneManager *sceneManager,
                                           EntityId entityId,
                                           int skinIndex,
                                           int boneIndex)
    {
        return ((SceneManager *)sceneManager)->getBone(entityId, skinIndex, boneIndex);
    }
    EMSCRIPTEN_KEEPALIVE void get_world_transform(TSceneManager *sceneManager,
                                                  EntityId entityId, float *const out)
    {
        auto transform = ((SceneManager *)sceneManager)->getWorldTransform(entityId);
        out[0] = transform[0][0];
        out[1] = transform[0][1];
        out[2] = transform[0][2];
        out[3] = transform[0][3];
        out[4] = transform[1][0];
        out[5] = transform[1][1];
        out[6] = transform[1][2];
        out[7] = transform[1][3];
        out[8] = transform[2][0];
        out[9] = transform[2][1];
        out[10] = transform[2][2];
        out[11] = transform[2][3];
        out[12] = transform[3][0];
        out[13] = transform[3][1];
        out[14] = transform[3][2];
        out[15] = transform[3][3];
    }

    EMSCRIPTEN_KEEPALIVE void get_local_transform(TSceneManager *sceneManager,
                                                  EntityId entityId, float *const out)
    {
        auto transform = ((SceneManager *)sceneManager)->getLocalTransform(entityId);
        out[0] = transform[0][0];
        out[1] = transform[0][1];
        out[2] = transform[0][2];
        out[3] = transform[0][3];
        out[4] = transform[1][0];
        out[5] = transform[1][1];
        out[6] = transform[1][2];
        out[7] = transform[1][3];
        out[8] = transform[2][0];
        out[9] = transform[2][1];
        out[10] = transform[2][2];
        out[11] = transform[2][3];
        out[12] = transform[3][0];
        out[13] = transform[3][1];
        out[14] = transform[3][2];
        out[15] = transform[3][3];
    }

    EMSCRIPTEN_KEEPALIVE void get_rest_local_transforms(TSceneManager *sceneManager,
                                                        EntityId entityId, int skinIndex, float *const out, int numBones)
    {
        const auto transforms = ((SceneManager *)sceneManager)->getBoneRestTranforms(entityId, skinIndex);
        auto numTransforms = transforms->size();
        if (numTransforms != numBones)
        {
            Log("Error - %d bone transforms available but you only specified %d.", numTransforms, numBones);
            return;
        }
        for (int boneIndex = 0; boneIndex < numTransforms; boneIndex++)
        {
            const auto transform = transforms->at(boneIndex);
            for (int colNum = 0; colNum < 4; colNum++)
            {
                for (int rowNum = 0; rowNum < 4; rowNum++)
                {
                    out[(boneIndex * 16) + (colNum * 4) + rowNum] = transform[colNum][rowNum];
                }
            }
        }
    }

    EMSCRIPTEN_KEEPALIVE void get_inverse_bind_matrix(TSceneManager *sceneManager,
                                                      EntityId entityId, int skinIndex, int boneIndex, float *const out)
    {
        auto transform = ((SceneManager *)sceneManager)->getInverseBindMatrix(entityId, skinIndex, boneIndex);
        out[0] = transform[0][0];
        out[1] = transform[0][1];
        out[2] = transform[0][2];
        out[3] = transform[0][3];
        out[4] = transform[1][0];
        out[5] = transform[1][1];
        out[6] = transform[1][2];
        out[7] = transform[1][3];
        out[8] = transform[2][0];
        out[9] = transform[2][1];
        out[10] = transform[2][2];
        out[11] = transform[2][3];
        out[12] = transform[3][0];
        out[13] = transform[3][1];
        out[14] = transform[3][2];
        out[15] = transform[3][3];
    }

    EMSCRIPTEN_KEEPALIVE bool set_bone_transform(
        TSceneManager *sceneManager,
        EntityId entityId,
        int skinIndex,
        int boneIndex,
        const float *const transform)
    {
        auto matrix = math::mat4f(
            transform[0], transform[1], transform[2],
            transform[3],
            transform[4],
            transform[5],
            transform[6],
            transform[7],
            transform[8],
            transform[9],
            transform[10],
            transform[11],
            transform[12],
            transform[13],
            transform[14],
            transform[15]);
        return ((SceneManager *)sceneManager)->setBoneTransform(entityId, skinIndex, boneIndex, matrix);
    }

    EMSCRIPTEN_KEEPALIVE void play_animation(
        TSceneManager *sceneManager,
        EntityId asset,
        int index,
        bool loop,
        bool reverse,
        bool replaceActive,
        float crossfade,
        float startOffset)
    {
        ((SceneManager *)sceneManager)->playAnimation(asset, index, loop, reverse, replaceActive, crossfade, startOffset);
    }

    EMSCRIPTEN_KEEPALIVE void set_animation_frame(
        TSceneManager *sceneManager,
        EntityId asset,
        int animationIndex,
        int animationFrame)
    {
        // ((SceneManager*)sceneManager)->setAnimationFrame(asset, animationIndex, animationFrame);
    }

    float get_animation_duration(TSceneManager *sceneManager, EntityId asset, int animationIndex)
    {
        return ((SceneManager *)sceneManager)->getAnimationDuration(asset, animationIndex);
    }

    int get_animation_count(
        TSceneManager *sceneManager,
        EntityId asset)
    {
        auto names = ((SceneManager *)sceneManager)->getAnimationNames(asset);
        return (int)names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_animation_name(
        TSceneManager *sceneManager,
        EntityId asset,
        char *const outPtr,
        int index)
    {
        auto names = ((SceneManager *)sceneManager)->getAnimationNames(asset);
        std::string name = names->at(index);
        strcpy(outPtr, name.c_str());
    }

    EMSCRIPTEN_KEEPALIVE int get_bone_count(TSceneManager *sceneManager, EntityId assetEntity, int skinIndex)
    {
        auto names = ((SceneManager *)sceneManager)->getBoneNames(assetEntity, skinIndex);
        return names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_bone_names(TSceneManager *sceneManager, EntityId assetEntity, const char **out, int skinIndex)
    {
        auto names = ((SceneManager *)sceneManager)->getBoneNames(assetEntity, skinIndex);
        for (int i = 0; i < names->size(); i++)
        {
            auto name_c = names->at(i).c_str();
            memcpy((void *)out[i], name_c, strlen(name_c) + 1);
        }
    }

    EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_getCameraByName(TSceneManager *tSceneManager, EntityId entityId, const char* name) {
        auto *sceneManager = reinterpret_cast<SceneManager*>(tSceneManager);
        return nullptr;
    }


    EMSCRIPTEN_KEEPALIVE bool SceneManager_setTransform(TSceneManager *sceneManager, EntityId entityId, const double *const transform)
    {
        auto matrix = math::mat4(
            transform[0], transform[1], transform[2],
            transform[3],
            transform[4],
            transform[5],
            transform[6],
            transform[7],
            transform[8],
            transform[9],
            transform[10],
            transform[11],
            transform[12],
            transform[13],
            transform[14],
            transform[15]);
        return ((SceneManager *)sceneManager)->setTransform(entityId, matrix);
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_queueTransformUpdates(TSceneManager *tSceneManager, EntityId *entities, const double *const transforms, int numEntities)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);

        std::vector<math::mat4> matrices(
            numEntities);
        for (int i = 0; i < numEntities; i++)
        {
            matrices[i] = math::mat4(
                transforms[i * 16], transforms[i * 16 + 1], transforms[i * 16 + 2],
                transforms[i * 16 + 3],
                transforms[i * 16 + 4],
                transforms[i * 16 + 5],
                transforms[i * 16 + 6],
                transforms[i * 16 + 7],
                transforms[i * 16 + 8],
                transforms[i * 16 + 9],
                transforms[i * 16 + 10],
                transforms[i * 16 + 11],
                transforms[i * 16 + 12],
                transforms[i * 16 + 13],
                transforms[i * 16 + 14],
                transforms[i * 16 + 15]);
        }
        sceneManager->queueTransformUpdates(entities, matrices.data(), numEntities);
    }

    EMSCRIPTEN_KEEPALIVE bool update_bone_matrices(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->updateBoneMatrices(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_morph_target_name_count(TSceneManager *sceneManager, EntityId assetEntity, EntityId childEntity)
    {
        auto names = ((SceneManager *)sceneManager)->getMorphTargetNames(assetEntity, childEntity);
        return (int)names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_morph_target_name(TSceneManager *sceneManager, EntityId assetEntity, EntityId childEntity, char *const outPtr, int index)
    {
        auto names = ((SceneManager *)sceneManager)->getMorphTargetNames(assetEntity, childEntity);
        std::string name = names->at(index);
        strcpy(outPtr, name.c_str());
    }

    EMSCRIPTEN_KEEPALIVE void remove_entity(TViewer *viewer, EntityId asset)
    {
        ((FilamentViewer *)viewer)->removeEntity(asset);
    }

    EMSCRIPTEN_KEEPALIVE void clear_entities(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->clearEntities();
    }

    bool set_material_color(TSceneManager *sceneManager, EntityId asset, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a)
    {
        return ((SceneManager *)sceneManager)->setMaterialColor(asset, meshName, materialIndex, r, g, b, a);
    }

    EMSCRIPTEN_KEEPALIVE void transform_to_unit_cube(TSceneManager *sceneManager, EntityId asset)
    {
        ((SceneManager *)sceneManager)->transformToUnitCube(asset);
    }

    EMSCRIPTEN_KEEPALIVE void set_position(TSceneManager *sceneManager, EntityId asset, float x, float y, float z)
    {
        ((SceneManager *)sceneManager)->setPosition(asset, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void set_rotation(TSceneManager *sceneManager, EntityId asset, float rads, float x, float y, float z, float w)
    {
        ((SceneManager *)sceneManager)->setRotation(asset, rads, x, y, z, w);
    }

    EMSCRIPTEN_KEEPALIVE void set_scale(TSceneManager *sceneManager, EntityId asset, float scale)
    {
        ((SceneManager *)sceneManager)->setScale(asset, scale);
    }

    EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(TSceneManager *sceneManager, TView *tView, EntityId entity, float viewportX, float viewportY)
    {
        auto *view = reinterpret_cast<View*>(tView);
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateFromViewportVector(view, entity, viewportX, viewportY);
    }

    EMSCRIPTEN_KEEPALIVE void stop_animation(TSceneManager *sceneManager, EntityId asset, int index)
    {
        ((SceneManager *)sceneManager)->stopAnimation(asset, index);
    }

    EMSCRIPTEN_KEEPALIVE int hide_mesh(TSceneManager *sceneManager, EntityId asset, const char *meshName)
    {
        return ((SceneManager *)sceneManager)->hide(asset, meshName);
    }

    EMSCRIPTEN_KEEPALIVE int reveal_mesh(TSceneManager *sceneManager, EntityId asset, const char *meshName)
    {
        return ((SceneManager *)sceneManager)->reveal(asset, meshName);
    }

    EMSCRIPTEN_KEEPALIVE const char *get_name_for_entity(TSceneManager *sceneManager, const EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->getNameForEntity(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_entity_count(TSceneManager *sceneManager, const EntityId target, bool renderableOnly)
    {
        return ((SceneManager *)sceneManager)->getEntityCount(target, renderableOnly);
    }

    EMSCRIPTEN_KEEPALIVE void get_entities(TSceneManager *sceneManager, const EntityId target, bool renderableOnly, EntityId *out)
    {
        ((SceneManager *)sceneManager)->getEntities(target, renderableOnly, out);
    }

    EMSCRIPTEN_KEEPALIVE const char *get_entity_name_at(TSceneManager *sceneManager, const EntityId target, int index, bool renderableOnly)
    {
        return ((SceneManager *)sceneManager)->getEntityNameAt(target, index, renderableOnly);
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

    EMSCRIPTEN_KEEPALIVE bool add_animation_component(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->addAnimationComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void remove_animation_component(TSceneManager *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeAnimationComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneManager_createGeometry(
        TSceneManager *sceneManager,
        float *vertices,
        int numVertices,
        float *normals,
        int numNormals,
        float *uvs,
        int numUvs,
        uint16_t *indices,
        int numIndices,
        int primitiveType,
        TMaterialInstance *materialInstance,
        bool keepData)
    {
        return ((SceneManager *)sceneManager)->createGeometry(vertices, (uint32_t)numVertices, normals, (uint32_t)numNormals, uvs, numUvs, indices, numIndices, (filament::RenderableManager::PrimitiveType)primitiveType, reinterpret_cast<MaterialInstance *>(materialInstance), keepData);
    }

    EMSCRIPTEN_KEEPALIVE EntityId find_child_entity_by_name(TSceneManager *sceneManager, const EntityId parent, const char *name)
    {
        auto entity = ((SceneManager *)sceneManager)->findChildEntityByName(parent, name);
        return utils::Entity::smuggle(entity);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_parent(TSceneManager *sceneManager, EntityId child)
    {
        return ((SceneManager *)sceneManager)->getParent(child);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_ancestor(TSceneManager *sceneManager, EntityId child)
    {
        return ((SceneManager *)sceneManager)->getAncestor(child);
    }

    EMSCRIPTEN_KEEPALIVE void set_parent(TSceneManager *sceneManager, EntityId child, EntityId parent, bool preserveScaling)
    {
        ((SceneManager *)sceneManager)->setParent(child, parent, preserveScaling);
    }

    EMSCRIPTEN_KEEPALIVE void test_collisions(TSceneManager *sceneManager, EntityId entity)
    {
        ((SceneManager *)sceneManager)->testCollisions(entity);
    }

    EMSCRIPTEN_KEEPALIVE void set_priority(TSceneManager *sceneManager, EntityId entity, int priority)
    {
        ((SceneManager *)sceneManager)->setPriority(entity, priority);
    }

    
    EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(TSceneManager *sceneManager, TView *tView, EntityId entity)
    {
        auto view = reinterpret_cast<View*>(tView);
        return ((SceneManager *)sceneManager)->getBoundingBox(view, entity);
    }

    EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(TSceneManager *sceneManager, TView *tView, EntityId entity, float *minX, float *minY, float *maxX, float *maxY)
    {
        auto view = reinterpret_cast<View*>(tView);
        auto box = ((SceneManager *)sceneManager)->getBoundingBox(view, entity);
        *minX = box.minX;
        *minY = box.minY;
        *maxX = box.maxX;
        *maxY = box.maxY;
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_setVisibilityLayer(TSceneManager *tSceneManager, EntityId entity, int layer)
    {
        auto *sceneManager = reinterpret_cast<SceneManager*>(tSceneManager);
        sceneManager->setVisibilityLayer(entity, layer);
    }

    EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr)
    {
        free(ptr);
    }

    EMSCRIPTEN_KEEPALIVE void set_stencil_highlight(TSceneManager *sceneManager, EntityId entityId, float r, float g, float b)
    {
        ((SceneManager *)sceneManager)->setStencilHighlight(entityId, r, g, b);
    }

    EMSCRIPTEN_KEEPALIVE void remove_stencil_highlight(TSceneManager *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeStencilHighlight(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_float(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, float value)
    {
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, value);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialInstance *get_material_instance_at(TSceneManager *sceneManager, EntityId entity, int materialIndex)
    {
        auto instance = ((SceneManager *)sceneManager)->getMaterialInstanceAt(entity, materialIndex);
        return reinterpret_cast<TMaterialInstance *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_int(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, int32_t value)
    {
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, value);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_float4(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, double4 value)
    {
        filament::math::float4 filamentValue;
        filamentValue.x = static_cast<float>(value.x);
        filamentValue.y = static_cast<float>(value.y);
        filamentValue.z = static_cast<float>(value.z);
        filamentValue.w = static_cast<float>(value.w);
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, filamentValue);
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

    EMSCRIPTEN_KEEPALIVE TMaterialInstance *create_material_instance(TSceneManager *sceneManager, TMaterialKey materialConfig)
    {

        filament::gltfio::MaterialKey config;
        memset(&config, 0, sizeof(MaterialKey));

        // Set and log each field
        config.unlit = materialConfig.unlit;
        config.doubleSided = materialConfig.doubleSided;
        config.useSpecularGlossiness = materialConfig.useSpecularGlossiness;
        config.alphaMode = static_cast<filament::gltfio::AlphaMode>(materialConfig.alphaMode);
        config.hasBaseColorTexture = materialConfig.hasBaseColorTexture;
        config.hasClearCoat = materialConfig.hasClearCoat;
        config.hasClearCoatNormalTexture = materialConfig.hasClearCoatNormalTexture;
        config.hasClearCoatRoughnessTexture = materialConfig.hasClearCoatRoughnessTexture;
        config.hasEmissiveTexture = materialConfig.hasEmissiveTexture;
        config.hasIOR = materialConfig.hasIOR;
        config.hasMetallicRoughnessTexture = materialConfig.hasMetallicRoughnessTexture;
        config.hasNormalTexture = materialConfig.hasNormalTexture;
        config.hasOcclusionTexture = materialConfig.hasOcclusionTexture;
        config.hasSheen = materialConfig.hasSheen;
        config.hasSheenColorTexture = materialConfig.hasSheenColorTexture;
        config.hasSheenRoughnessTexture = materialConfig.hasSheenRoughnessTexture;
        config.hasTextureTransforms = materialConfig.hasTextureTransforms;
        config.hasTransmission = materialConfig.hasTransmission;
        config.hasTransmissionTexture = materialConfig.hasTransmissionTexture;
        config.hasVolume = materialConfig.hasVolume;
        config.hasVolumeThicknessTexture = materialConfig.hasVolumeThicknessTexture;
        config.baseColorUV = materialConfig.baseColorUV;
        config.hasVertexColors = materialConfig.hasVertexColors;
        auto materialInstance = ((SceneManager *)sceneManager)->createUbershaderMaterialInstance(config);
        return reinterpret_cast<TMaterialInstance *>(materialInstance);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitMaterialInstance(TSceneManager *sceneManager)
    {
        auto *instance = ((SceneManager *)sceneManager)->createUnlitMaterialInstance();
        return reinterpret_cast<TMaterialInstance *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE void destroy_material_instance(TSceneManager *sceneManager, TMaterialInstance *instance)
    {
        ((SceneManager *)sceneManager)->destroy(reinterpret_cast<MaterialInstance *>(instance));
    }

    EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled)
    {
        reinterpret_cast<MaterialInstance *>(materialInstance)->setDepthWrite(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled)
    {
        reinterpret_cast<MaterialInstance *>(materialInstance)->setDepthCulling(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *propertyName, double x, double y)
    {
        filament::math::float2 data{static_cast<float>(x), static_cast<float>(y)};
        reinterpret_cast<MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
    }


    EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *tEngine, EntityId entityId)
    {
        auto *engine = reinterpret_cast<Engine *>(tEngine);
        auto *camera = engine->getCameraComponent(utils::Entity::import(entityId));
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

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_createCamera(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return reinterpret_cast<TCamera *>(sceneManager->createCamera());
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager *tSceneManager, TCamera *tCamera)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *camera = reinterpret_cast<Camera *>(tCamera);
        sceneManager->destroyCamera(camera);
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneManager_getCameraCount(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return sceneManager->getCameraCount();
    }

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_getCameraAt(TSceneManager *tSceneManager, size_t index)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *camera = sceneManager->getCameraAt(index);
        return reinterpret_cast<TCamera *>(camera);
    }


}
