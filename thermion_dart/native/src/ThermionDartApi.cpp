#ifdef _WIN32
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")
#endif

#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

using namespace thermion_filament;

extern "C"
{

#include "ThermionDartApi.h"

    // Helper function to convert filament::math::mat4 to double4x4
    static double4x4 convert_mat4_to_double4x4(const filament::math::mat4 &mat)
    {
        return double4x4{
            {mat[0][0], mat[0][1], mat[0][2], mat[0][3]},
            {mat[1][0], mat[1][1], mat[1][2], mat[1][3]},
            {mat[2][0], mat[2][1], mat[2][2], mat[2][3]},
            {mat[3][0], mat[3][1], mat[3][2], mat[3][3]},
        };
    }

    // Helper function to convert double4x4 to filament::math::mat4
    static filament::math::mat4 convert_double4x4_to_mat4(const double4x4 &d_mat)
    {
        return filament::math::mat4{
            filament::math::float4{float(d_mat.col1[0]), float(d_mat.col1[1]), float(d_mat.col1[2]), float(d_mat.col1[3])},
            filament::math::float4{float(d_mat.col2[0]), float(d_mat.col2[1]), float(d_mat.col2[2]), float(d_mat.col2[3])},
            filament::math::float4{float(d_mat.col3[0]), float(d_mat.col3[1]), float(d_mat.col3[2]), float(d_mat.col3[3])},
            filament::math::float4{float(d_mat.col4[0]), float(d_mat.col4[1]), float(d_mat.col4[2]), float(d_mat.col4[3])}};
    }

    EMSCRIPTEN_KEEPALIVE TViewer *create_filament_viewer(const void *context, const void *const loader, void *const platform, const char *uberArchivePath)
    {
        const auto *loaderImpl = new ResourceLoaderWrapperImpl((ResourceLoaderWrapper *)loader);
        auto viewer = new FilamentViewer(context, loaderImpl, platform, uberArchivePath);
        return reinterpret_cast<TViewer*>(viewer);
    }

    EMSCRIPTEN_KEEPALIVE TEngine *Viewer_getEngine(TViewer* viewer) { 
        auto* engine = reinterpret_cast<FilamentViewer*>(viewer)->getEngine();
        return reinterpret_cast<TEngine*>(engine);
    }

    EMSCRIPTEN_KEEPALIVE void create_render_target(TViewer *viewer, intptr_t texture, uint32_t width, uint32_t height)
    {
        ((FilamentViewer *)viewer)->createRenderTarget(texture, width, height);
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
        ((FilamentViewer *)viewer)->setBackgroundImage(path, fillHeight);
    }

    EMSCRIPTEN_KEEPALIVE void set_background_image_position(TViewer *viewer, float x, float y, bool clamp)
    {
        ((FilamentViewer *)viewer)->setBackgroundImagePosition(x, y, clamp);
    }

    EMSCRIPTEN_KEEPALIVE void set_tone_mapping(TViewer *viewer, int toneMapping)
    {
        ((FilamentViewer *)viewer)->setToneMapping((ToneMapping)toneMapping);
    }

    EMSCRIPTEN_KEEPALIVE void set_bloom(TViewer *viewer, float strength)
    {
        ((FilamentViewer *)viewer)->setBloom(strength);
    }

    EMSCRIPTEN_KEEPALIVE void load_skybox(TViewer *viewer, const char *skyboxPath)
    {
        ((FilamentViewer *)viewer)->loadSkybox(skyboxPath);
    }

    EMSCRIPTEN_KEEPALIVE void create_ibl(TViewer *viewer, float r, float g, float b, float intensity)
    {
        ((FilamentViewer *)viewer)->createIbl(r, g, b, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void load_ibl(TViewer *viewer, const char *iblPath, float intensity)
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

    EMSCRIPTEN_KEEPALIVE EntityId load_glb_from_buffer(TSceneManager *sceneManager, const void *const data, size_t length, bool keepData, int priority, int layer)
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

    EMSCRIPTEN_KEEPALIVE void set_main_camera(TViewer *viewer)
    {
        return ((FilamentViewer *)viewer)->setMainCamera();
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_main_camera(TViewer *viewer)
    {
        return ((FilamentViewer *)viewer)->getMainCamera();
    }

    EMSCRIPTEN_KEEPALIVE bool set_camera(TViewer *viewer, EntityId asset, const char *nodeName)
    {
        return ((FilamentViewer *)viewer)->setCamera(asset, nodeName);
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

    double4x4 get_camera_model_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getModelMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_view_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getViewMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_projection_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_culling_projection_matrix(TCamera *camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera *>(camera)->getCullingProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    void set_camera_projection_matrix(TCamera *camera, double4x4 matrix, double near, double far)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        const auto &mat = convert_double4x4_to_mat4(matrix);
        cam->setCustomProjection(mat, near, far);
    }

    void Camera_setLensProjection(TCamera *camera, double near, double far, double aspect, double focalLength)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setLensProjection(focalLength, aspect, near, far);
    }

    void Camera_setModelMatrix(TCamera *camera, double4x4 matrix)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        cam->setModelMatrix(convert_double4x4_to_mat4(matrix));
    }

    double get_camera_near(TCamera *camera)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getNear();
    }

    double get_camera_culling_far(TCamera *camera)
    {
        auto cam = reinterpret_cast<filament::Camera *>(camera);
        return cam->getCullingFar();
    }

    const double *const get_camera_frustum(TCamera *camera)
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

    EMSCRIPTEN_KEEPALIVE void set_camera_manipulator_options(TViewer *viewer, _ManipulatorMode mode, double orbitSpeedX, double orbitSpeedY, double zoomSpeed)
    {
        ((FilamentViewer *)viewer)->setCameraManipulatorOptions((filament::camutils::Mode)mode, orbitSpeedX, orbitSpeedY, zoomSpeed);
    }

    EMSCRIPTEN_KEEPALIVE void set_view_frustum_culling(TViewer *viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setViewFrustumCulling(enabled);
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

    EMSCRIPTEN_KEEPALIVE bool render(
        TViewer *viewer,
        uint64_t frameTimeInNanos,
        void *pixelBuffer,
        void (*callback)(void *buf, size_t size, void *data),
        void *data)
    {
    return ((FilamentViewer *)viewer)->render(frameTimeInNanos, pixelBuffer, callback, data);
    }

    EMSCRIPTEN_KEEPALIVE void capture(
        TViewer *viewer,
        uint8_t *pixelBuffer,
        void (*callback)(void))
    {
#ifdef __EMSCRIPTEN__
        bool useFence = true;
#else
        bool useFence = false;
#endif
        ((FilamentViewer *)viewer)->capture(pixelBuffer, useFence, callback);
    };

    EMSCRIPTEN_KEEPALIVE void set_frame_interval(
        TViewer *viewer,
        float frameInterval)
    {
        ((FilamentViewer *)viewer)->setFrameInterval(frameInterval);
    }

    EMSCRIPTEN_KEEPALIVE void destroy_swap_chain(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->destroySwapChain();
    }

    EMSCRIPTEN_KEEPALIVE void create_swap_chain(TViewer *viewer, const void *const window, uint32_t width, uint32_t height)
    {
        ((FilamentViewer *)viewer)->createSwapChain(window, width, height);
    }

    EMSCRIPTEN_KEEPALIVE void update_viewport(TViewer *viewer, uint32_t width, uint32_t height)
    {
        return ((FilamentViewer *)viewer)->updateViewport(width, height);
    }

    EMSCRIPTEN_KEEPALIVE void scroll_update(TViewer *viewer, float x, float y, float delta)
    {
        ((FilamentViewer *)viewer)->scrollUpdate(x, y, delta);
    }

    EMSCRIPTEN_KEEPALIVE void scroll_begin(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->scrollBegin();
    }

    EMSCRIPTEN_KEEPALIVE void scroll_end(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->scrollEnd();
    }

    EMSCRIPTEN_KEEPALIVE void grab_begin(TViewer *viewer, float x, float y, bool pan)
    {
        ((FilamentViewer *)viewer)->grabBegin(x, y, pan);
    }

    EMSCRIPTEN_KEEPALIVE void grab_update(TViewer *viewer, float x, float y)
    {
        ((FilamentViewer *)viewer)->grabUpdate(x, y);
    }

    EMSCRIPTEN_KEEPALIVE void grab_end(TViewer *viewer)
    {
        ((FilamentViewer *)viewer)->grabEnd();
    }

    EMSCRIPTEN_KEEPALIVE TSceneManager* Viewer_getSceneManager(TViewer *tViewer)
    {
        auto * viewer = reinterpret_cast<FilamentViewer*>(tViewer);
        auto * sceneManager = viewer->getSceneManager();
        return reinterpret_cast<TSceneManager*>(sceneManager);
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

    EMSCRIPTEN_KEEPALIVE bool set_morph_animation(
        TSceneManager *sceneManager,
        EntityId asset,
        const float *const morphData,
        const int *const morphIndices,
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

    EMSCRIPTEN_KEEPALIVE void set_post_processing(TViewer *viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setPostProcessing(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void set_shadows_enabled(TViewer *viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setShadowsEnabled(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void set_shadow_type(TViewer *viewer, int shadowType)
    {
        ((FilamentViewer *)viewer)->setShadowType((ShadowType)shadowType);
    }

    EMSCRIPTEN_KEEPALIVE void set_soft_shadow_options(TViewer *viewer, float penumbraScale, float penumbraRatioScale)
    {
        ((FilamentViewer *)viewer)->setSoftShadowOptions(penumbraScale, penumbraRatioScale);
    }

    EMSCRIPTEN_KEEPALIVE void set_antialiasing(TViewer *viewer, bool msaa, bool fxaa, bool taa)
    {
        ((FilamentViewer *)viewer)->setAntiAliasing(msaa, fxaa, taa);
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

    EMSCRIPTEN_KEEPALIVE bool set_transform(TSceneManager *sceneManager, EntityId entityId, const float *const transform)
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
        return ((SceneManager *)sceneManager)->setTransform(entityId, matrix);
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

    EMSCRIPTEN_KEEPALIVE void queue_position_update(TSceneManager *sceneManager, EntityId asset, float x, float y, float z, bool relative)
    {
        ((SceneManager *)sceneManager)->queuePositionUpdate(asset, x, y, z, relative);
    }

    EMSCRIPTEN_KEEPALIVE void queue_relative_position_update_world_axis(TSceneManager *sceneManager, EntityId entity, float viewportX, float viewportY, float x, float y, float z)
    {
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateWorldAxis(entity, viewportX, viewportY, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void queue_rotation_update(TSceneManager *sceneManager, EntityId asset, float rads, float x, float y, float z, float w, bool relative)
    {
        ((SceneManager *)sceneManager)->queueRotationUpdate(asset, rads, x, y, z, w, relative);
    }

    EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(TSceneManager *sceneManager, EntityId entity, float viewportX, float viewportY)
    {
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateFromViewportVector(entity, viewportX, viewportY);
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

    EMSCRIPTEN_KEEPALIVE void filament_pick(TViewer *viewer, int x, int y, void (*callback)(EntityId entityId, int x, int y))
    {
        ((FilamentViewer *)viewer)->pick(static_cast<uint32_t>(x), static_cast<uint32_t>(y), callback);
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

    EMSCRIPTEN_KEEPALIVE void set_recording(TViewer *viewer, bool recording)
    {
        ((FilamentViewer *)viewer)->setRecording(recording);
    }

    EMSCRIPTEN_KEEPALIVE void set_recording_output_directory(TViewer *viewer, const char *outputDirectory)
    {
        ((FilamentViewer *)viewer)->setRecordingOutputDirectory(outputDirectory);
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

    EMSCRIPTEN_KEEPALIVE EntityId create_geometry(
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

    EMSCRIPTEN_KEEPALIVE void get_gizmo(TSceneManager *sceneManager, EntityId *out)
    {
        auto gizmo = ((SceneManager *)sceneManager)->gizmo;
        out[0] = Entity::smuggle(gizmo->x());
        out[1] = Entity::smuggle(gizmo->y());
        out[2] = Entity::smuggle(gizmo->z());
        out[3] = Entity::smuggle(gizmo->center());
    }

    EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(TSceneManager *sceneManager, EntityId entity)
    {
        return ((SceneManager *)sceneManager)->getBoundingBox(entity);
    }

    EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(TSceneManager *sceneManager, EntityId entity, float *minX, float *minY, float *maxX, float *maxY)
    {
        auto box = ((SceneManager *)sceneManager)->getBoundingBox(entity);
        *minX = box.minX;
        *minY = box.minY;
        *maxX = box.maxX;
        *maxY = box.maxY;
    }

    EMSCRIPTEN_KEEPALIVE void set_visibility_layer(TSceneManager *sceneManager, EntityId entity, int layer) {
        ((SceneManager*)sceneManager)->setVisibilityLayer(entity, layer);
    }


    EMSCRIPTEN_KEEPALIVE void set_layer_visibility(TSceneManager *sceneManager, int layer, bool visible)
    {
        ((SceneManager *)sceneManager)->setLayerVisibility((SceneManager::LAYERS)layer, visible);
    }

    EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr)
    {
        free(ptr);
    }

    EMSCRIPTEN_KEEPALIVE void pick_gizmo(TSceneManager *sceneManager, int x, int y, void (*callback)(EntityId entityId, int x, int y))
    {
        ((SceneManager *)sceneManager)->gizmo->pick(x, y, callback);
    }

    EMSCRIPTEN_KEEPALIVE void set_gizmo_visibility(TSceneManager *sceneManager, bool visible)
    {
        ((SceneManager *)sceneManager)->gizmo->setVisibility(visible);
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

    EMSCRIPTEN_KEEPALIVE TMaterialInstance* get_material_instance_at(TSceneManager *sceneManager, EntityId entity, int materialIndex) {
        auto instance = ((SceneManager *)sceneManager)->getMaterialInstanceAt(entity, materialIndex);
        return reinterpret_cast<TMaterialInstance*>(instance);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_int(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, int32_t value)
    {
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, value);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_float4(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, double4 value)
    {        
        filament::math::float4 filamentValue;
        filamentValue.x = static_cast<float32_t>(value.x);
        filamentValue.y = static_cast<float32_t>(value.y);
        filamentValue.z = static_cast<float32_t>(value.z);
        filamentValue.w = static_cast<float32_t>(value.w);
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, filamentValue);
    }

    EMSCRIPTEN_KEEPALIVE void unproject_texture(TViewer *viewer, EntityId entity, uint8_t* input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight)
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


 EMSCRIPTEN_KEEPALIVE TMaterialInstance* create_material_instance(TSceneManager *sceneManager, TMaterialKey materialConfig)
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
    return reinterpret_cast<TMaterialInstance*>(materialInstance);
}

EMSCRIPTEN_KEEPALIVE TMaterialInstance *create_unlit_material_instance(TSceneManager *sceneManager) { 
    auto * instance = ((SceneManager*)sceneManager)->createUnlitMaterialInstance();
    return reinterpret_cast<TMaterialInstance*>(instance);
}

EMSCRIPTEN_KEEPALIVE void destroy_material_instance(TSceneManager *sceneManager, TMaterialInstance *instance) {
    ((SceneManager *)sceneManager)->destroy(reinterpret_cast<MaterialInstance*>(instance));
}

EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance* materialInstance, bool enabled) {
    reinterpret_cast<MaterialInstance*>(materialInstance)->setDepthWrite(enabled);
}
EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance* materialInstance, bool enabled) {
    reinterpret_cast<MaterialInstance*>(materialInstance)->setDepthCulling(enabled);
}

EMSCRIPTEN_KEEPALIVE void Camera_setCustomProjectionWithCulling(TCamera* tCamera, double4x4 projectionMatrix, double near, double far) {
    auto * camera = reinterpret_cast<Camera*>(tCamera);
    camera->setCustomProjection(convert_double4x4_to_mat4(projectionMatrix), near, far);
}

EMSCRIPTEN_KEEPALIVE double4x4 Camera_getModelMatrix(TCamera* tCamera) {
    auto * camera = reinterpret_cast<Camera*>(tCamera);
    return convert_mat4_to_double4x4(camera->getModelMatrix());
}

EMSCRIPTEN_KEEPALIVE EntityId Camera_getEntity(TCamera* tCamera) {
    auto * camera = reinterpret_cast<Camera*>(tCamera);
    return Entity::smuggle(camera->getEntity());
}

EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine* tEngine, EntityId entityId) {
    auto * engine = reinterpret_cast<Engine*>(tEngine);
    auto * camera = engine->getCameraComponent(utils::Entity::import(entityId));
    return reinterpret_cast<TCamera*>(camera);
}

EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine* tEngine, EntityId entity, double4x4 transform) {
    auto * engine = reinterpret_cast<Engine*>(tEngine);
    auto& transformManager = engine->getTransformManager();
    
    auto transformInstance = transformManager.getInstance(utils::Entity::import(entity));
    if(!transformInstance.isValid()) {
        Log("Transform instance not valid");
    }
    transformManager.setTransform(transformInstance, convert_double4x4_to_mat4(transform));
}

EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_createCamera(TSceneManager* tSceneManager) {
    auto * sceneManager = reinterpret_cast<SceneManager*>(tSceneManager);    
    return reinterpret_cast<TCamera*>(sceneManager->createCamera());
}

EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager* tSceneManager, TCamera* tCamera) {
    auto * sceneManager = reinterpret_cast<SceneManager*>(tSceneManager);    
    auto * camera = reinterpret_cast<Camera*>(tCamera);
    sceneManager->destroyCamera(camera);
}

EMSCRIPTEN_KEEPALIVE void SceneManager_setCamera(TSceneManager* tSceneManager, TCamera* tCamera) {
    auto * sceneManager = reinterpret_cast<SceneManager*>(tSceneManager);    
    auto * camera = reinterpret_cast<Camera*>(tCamera);
    sceneManager->setCamera(camera);
}
}
