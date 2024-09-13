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
    static filament::math::mat4 convert_double4x4_to_mat4(const double4x4& d_mat)
    {
        return filament::math::mat4{
            filament::math::float4{float(d_mat.col1[0]), float(d_mat.col1[1]), float(d_mat.col1[2]), float(d_mat.col1[3])},
            filament::math::float4{float(d_mat.col2[0]), float(d_mat.col2[1]), float(d_mat.col2[2]), float(d_mat.col2[3])},
            filament::math::float4{float(d_mat.col3[0]), float(d_mat.col3[1]), float(d_mat.col3[2]), float(d_mat.col3[3])},
            filament::math::float4{float(d_mat.col4[0]), float(d_mat.col4[1]), float(d_mat.col4[2]), float(d_mat.col4[3])}
        };
    }

    EMSCRIPTEN_KEEPALIVE const void *create_filament_viewer(const void *context, const void *const loader, void *const platform, const char *uberArchivePath)
    {
        const auto *loaderImpl = new ResourceLoaderWrapperImpl((ResourceLoaderWrapper *)loader);
        auto viewer = (const void *)new FilamentViewer(context, loaderImpl, platform, uberArchivePath);
        return viewer;
    }

    EMSCRIPTEN_KEEPALIVE void create_render_target(const void *const viewer, intptr_t texture, uint32_t width, uint32_t height)
    {
        ((FilamentViewer *)viewer)->createRenderTarget(texture, width, height);
    }

    EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer(const void *const viewer)
    {
        delete ((FilamentViewer *)viewer);
    }

    EMSCRIPTEN_KEEPALIVE void set_background_color(const void *const viewer, const float r, const float g, const float b, const float a)
    {
        ((FilamentViewer *)viewer)->setBackgroundColor(r, g, b, a);
    }

    EMSCRIPTEN_KEEPALIVE void clear_background_image(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->clearBackgroundImage();
    }

    EMSCRIPTEN_KEEPALIVE void set_background_image(const void *const viewer, const char *path, bool fillHeight)
    {
        ((FilamentViewer *)viewer)->setBackgroundImage(path, fillHeight);
    }

    EMSCRIPTEN_KEEPALIVE void set_background_image_position(const void *const viewer, float x, float y, bool clamp)
    {
        ((FilamentViewer *)viewer)->setBackgroundImagePosition(x, y, clamp);
    }

    EMSCRIPTEN_KEEPALIVE void set_tone_mapping(const void *const viewer, int toneMapping)
    {
        ((FilamentViewer *)viewer)->setToneMapping((ToneMapping)toneMapping);
    }

    EMSCRIPTEN_KEEPALIVE void set_bloom(const void *const viewer, float strength)
    {
        ((FilamentViewer *)viewer)->setBloom(strength);
    }

    EMSCRIPTEN_KEEPALIVE void load_skybox(const void *const viewer, const char *skyboxPath)
    {
        ((FilamentViewer *)viewer)->loadSkybox(skyboxPath);
    }

    EMSCRIPTEN_KEEPALIVE void create_ibl(const void *const viewer, float r, float g, float b, float intensity)
    {
        ((FilamentViewer *)viewer)->createIbl(r, g, b, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void load_ibl(const void *const viewer, const char *iblPath, float intensity)
    {
        ((FilamentViewer *)viewer)->loadIbl(iblPath, intensity);
    }

    EMSCRIPTEN_KEEPALIVE void rotate_ibl(const void *const viewer, float *rotationMatrix)
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

    EMSCRIPTEN_KEEPALIVE void remove_skybox(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->removeSkybox();
    }

    EMSCRIPTEN_KEEPALIVE void remove_ibl(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->removeIbl();
    }

    EMSCRIPTEN_KEEPALIVE EntityId add_light(
        const void *const viewer,
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

    EMSCRIPTEN_KEEPALIVE void set_light_position(const void *const viewer, int32_t entityId, float x, float y, float z)
    {
        ((FilamentViewer *)viewer)->setLightPosition(entityId, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void set_light_direction(const void *const viewer, int32_t entityId, float x, float y, float z)
    {
        ((FilamentViewer *)viewer)->setLightDirection(entityId, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void remove_light(const void *const viewer, int32_t entityId)
    {
        ((FilamentViewer *)viewer)->removeLight(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void clear_lights(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->clearLights();
    }

    EMSCRIPTEN_KEEPALIVE EntityId load_glb(void *sceneManager, const char *assetPath, int numInstances, bool keepData)
    {
        return ((SceneManager *)sceneManager)->loadGlb(assetPath, numInstances, keepData);
    }

    EMSCRIPTEN_KEEPALIVE EntityId load_glb_from_buffer(void *sceneManager, const void *const data, size_t length, bool keepData)
    {
        return ((SceneManager *)sceneManager)->loadGlbFromBuffer((const uint8_t *)data, length, keepData);
    }

    EMSCRIPTEN_KEEPALIVE EntityId create_instance(void *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->createInstance(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_instance_count(void *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->getInstanceCount(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void get_instances(void *sceneManager, EntityId entityId, EntityId *out)
    {
        return ((SceneManager *)sceneManager)->getInstances(entityId, out);
    }

    EMSCRIPTEN_KEEPALIVE EntityId load_gltf(void *sceneManager, const char *assetPath, const char *relativePath, bool keepData)
    {
        return ((SceneManager *)sceneManager)->loadGltf(assetPath, relativePath, keepData);
    }

    EMSCRIPTEN_KEEPALIVE void set_main_camera(const void *const viewer)
    {
        return ((FilamentViewer *)viewer)->setMainCamera();
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_main_camera(const void *const viewer)
    {
        return ((FilamentViewer *)viewer)->getMainCamera();
    }

    EMSCRIPTEN_KEEPALIVE bool set_camera(const void *const viewer, EntityId asset, const char *nodeName)
    {
        return ((FilamentViewer *)viewer)->setCamera(asset, nodeName);
    }

    EMSCRIPTEN_KEEPALIVE float get_camera_fov(CameraPtr* camera, bool horizontal)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        return cam->getFieldOfViewInDegrees(horizontal ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL);
    }

    EMSCRIPTEN_KEEPALIVE double get_camera_focal_length(CameraPtr* const camera) {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        return cam->getFocalLength();
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_projection_from_fov(CameraPtr* camera, double fovInDegrees, double aspect, double near, double far, bool horizontal)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);       
        cam->setProjection(fovInDegrees, aspect, near, far, horizontal ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL);
    }

    EMSCRIPTEN_KEEPALIVE CameraPtr* get_camera(const void *const viewer, EntityId entity) {
        auto filamentCamera = ((FilamentViewer*)viewer)->getCamera(entity);
        return reinterpret_cast<CameraPtr*>(filamentCamera);
    }

    double4x4 get_camera_model_matrix(CameraPtr* camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera*>(camera)->getModelMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_view_matrix(CameraPtr* camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera*>(camera)->getViewMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_projection_matrix(CameraPtr* camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera*>(camera)->getProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    double4x4 get_camera_culling_projection_matrix(CameraPtr* camera)
    {
        const auto &mat = reinterpret_cast<filament::Camera*>(camera)->getCullingProjectionMatrix();
        return convert_mat4_to_double4x4(mat);
    }

    void set_camera_projection_matrix(CameraPtr* camera, double4x4 matrix, double near, double far)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        const auto& mat = convert_double4x4_to_mat4(matrix);
        cam->setCustomProjection(mat, near, far);
    }

    void set_camera_lens_projection(CameraPtr* camera, double near, double far, double aspect, double focalLength)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        cam->setLensProjection(focalLength, aspect, near, far);
    }

    double get_camera_near(CameraPtr* camera)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        return cam->getNear();
    }

    double get_camera_culling_far(CameraPtr* camera)
    {
        auto cam = reinterpret_cast<filament::Camera*>(camera);
        return cam->getCullingFar();
    }

    const double *const get_camera_frustum(CameraPtr* camera)
    {
        
        const auto frustum = reinterpret_cast<filament::Camera*>(camera)->getFrustum();
        
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

    EMSCRIPTEN_KEEPALIVE void set_camera_manipulator_options(const void *const viewer, _ManipulatorMode mode, double orbitSpeedX, double orbitSpeedY, double zoomSpeed)
    {
        ((FilamentViewer *)viewer)->setCameraManipulatorOptions((filament::camutils::Mode)mode, orbitSpeedX, orbitSpeedY, zoomSpeed);
    }

    EMSCRIPTEN_KEEPALIVE void set_view_frustum_culling(const void *const viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setViewFrustumCulling(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_focus_distance(CameraPtr* camera, float distance)
    {
        auto * cam = reinterpret_cast<filament::Camera*>(camera);
        cam->setFocusDistance(distance);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_exposure(CameraPtr* camera, float aperture, float shutterSpeed, float sensitivity)
    {
        auto * cam = reinterpret_cast<filament::Camera*>(camera);
        cam->setExposure(aperture, shutterSpeed, sensitivity);
    }

    EMSCRIPTEN_KEEPALIVE void set_camera_model_matrix(CameraPtr* camera, double4x4 matrix)
    {
        auto * cam = reinterpret_cast<filament::Camera*>(camera);
        const filament::math::mat4& mat = convert_double4x4_to_mat4(matrix);
        cam->setModelMatrix(mat);
    }

    EMSCRIPTEN_KEEPALIVE void render(
        const void *const viewer,
        uint64_t frameTimeInNanos,
        void *pixelBuffer,
        void (*callback)(void *buf, size_t size, void *data),
        void *data)
    {
        ((FilamentViewer *)viewer)->render(frameTimeInNanos, pixelBuffer, callback, data);
    }

    EMSCRIPTEN_KEEPALIVE void capture(
        const void *const viewer,
        uint8_t *pixelBuffer,
        void (*callback)(void))
    {
        ((FilamentViewer *)viewer)->capture(pixelBuffer, callback);
    };

    EMSCRIPTEN_KEEPALIVE void set_frame_interval(
        const void *const viewer,
        float frameInterval)
    {
        ((FilamentViewer *)viewer)->setFrameInterval(frameInterval);
    }

    EMSCRIPTEN_KEEPALIVE void destroy_swap_chain(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->destroySwapChain();
    }

    EMSCRIPTEN_KEEPALIVE void create_swap_chain(const void *const viewer, const void *const window, uint32_t width, uint32_t height)
    {
        ((FilamentViewer *)viewer)->createSwapChain(window, width, height);
    }

    EMSCRIPTEN_KEEPALIVE void update_viewport(const void *const viewer, uint32_t width, uint32_t height)
    {
        return ((FilamentViewer *)viewer)->updateViewport(width, height);
    }

    EMSCRIPTEN_KEEPALIVE void scroll_update(const void *const viewer, float x, float y, float delta)
    {
        ((FilamentViewer *)viewer)->scrollUpdate(x, y, delta);
    }

    EMSCRIPTEN_KEEPALIVE void scroll_begin(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->scrollBegin();
    }

    EMSCRIPTEN_KEEPALIVE void scroll_end(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->scrollEnd();
    }

    EMSCRIPTEN_KEEPALIVE void grab_begin(const void *const viewer, float x, float y, bool pan)
    {
        ((FilamentViewer *)viewer)->grabBegin(x, y, pan);
    }

    EMSCRIPTEN_KEEPALIVE void grab_update(const void *const viewer, float x, float y)
    {
        ((FilamentViewer *)viewer)->grabUpdate(x, y);
    }

    EMSCRIPTEN_KEEPALIVE void grab_end(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->grabEnd();
    }

    EMSCRIPTEN_KEEPALIVE void *get_scene_manager(const void *const viewer)
    {
        return (void *)((FilamentViewer *)viewer)->getSceneManager();
    }

    EMSCRIPTEN_KEEPALIVE void apply_weights(
        void *sceneManager,
        EntityId asset,
        const char *const entityName,
        float *const weights,
        int count)
    {
        // ((SceneManager*)sceneManager)->setMorphTargetWeights(asset, entityName, weights, count);
    }

    EMSCRIPTEN_KEEPALIVE bool set_morph_target_weights(
        void *sceneManager,
        EntityId asset,
        const float *const weights,
        const int numWeights)
    {
        return ((SceneManager *)sceneManager)->setMorphTargetWeights(asset, weights, numWeights);
    }

    EMSCRIPTEN_KEEPALIVE bool set_morph_animation(
        void *sceneManager,
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

    EMSCRIPTEN_KEEPALIVE void clear_morph_animation(void *sceneManager, EntityId asset)
    {
        ((SceneManager *)sceneManager)->clearMorphAnimationBuffer(asset);
    }

    EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose(void *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->resetBones(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void add_bone_animation(
        void *sceneManager,
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

    EMSCRIPTEN_KEEPALIVE void set_post_processing(void *const viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setPostProcessing(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void set_shadows_enabled(void *const viewer, bool enabled)
    {
        ((FilamentViewer *)viewer)->setShadowsEnabled(enabled);
    }

    EMSCRIPTEN_KEEPALIVE void set_shadow_type(void *const viewer, int shadowType)
    {
        ((FilamentViewer *)viewer)->setShadowType((ShadowType)shadowType);
    }

    EMSCRIPTEN_KEEPALIVE void set_soft_shadow_options(void *const viewer, float penumbraScale, float penumbraRatioScale)
    {
        ((FilamentViewer *)viewer)->setSoftShadowOptions(penumbraScale, penumbraRatioScale);
    }

    EMSCRIPTEN_KEEPALIVE void set_antialiasing(void *const viewer, bool msaa, bool fxaa, bool taa)
    {
        ((FilamentViewer *)viewer)->setAntiAliasing(msaa, fxaa, taa);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_bone(void *sceneManager,
                                           EntityId entityId,
                                           int skinIndex,
                                           int boneIndex)
    {
        return ((SceneManager *)sceneManager)->getBone(entityId, skinIndex, boneIndex);
    }
    EMSCRIPTEN_KEEPALIVE void get_world_transform(void *sceneManager,
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

    EMSCRIPTEN_KEEPALIVE void get_local_transform(void *sceneManager,
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

    EMSCRIPTEN_KEEPALIVE void get_rest_local_transforms(void *sceneManager,
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

    EMSCRIPTEN_KEEPALIVE void get_inverse_bind_matrix(void *sceneManager,
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
        void *sceneManager,
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
        void *sceneManager,
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
        void *sceneManager,
        EntityId asset,
        int animationIndex,
        int animationFrame)
    {
        // ((SceneManager*)sceneManager)->setAnimationFrame(asset, animationIndex, animationFrame);
    }

    float get_animation_duration(void *sceneManager, EntityId asset, int animationIndex)
    {
        return ((SceneManager *)sceneManager)->getAnimationDuration(asset, animationIndex);
    }

    int get_animation_count(
        void *sceneManager,
        EntityId asset)
    {
        auto names = ((SceneManager *)sceneManager)->getAnimationNames(asset);
        return (int)names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_animation_name(
        void *sceneManager,
        EntityId asset,
        char *const outPtr,
        int index)
    {
        auto names = ((SceneManager *)sceneManager)->getAnimationNames(asset);
        std::string name = names->at(index);
        strcpy(outPtr, name.c_str());
    }

    EMSCRIPTEN_KEEPALIVE int get_bone_count(void *sceneManager, EntityId assetEntity, int skinIndex)
    {
        auto names = ((SceneManager *)sceneManager)->getBoneNames(assetEntity, skinIndex);
        return names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_bone_names(void *sceneManager, EntityId assetEntity, const char **out, int skinIndex)
    {
        auto names = ((SceneManager *)sceneManager)->getBoneNames(assetEntity, skinIndex);
        for (int i = 0; i < names->size(); i++)
        {
            auto name_c = names->at(i).c_str();
            memcpy((void *)out[i], name_c, strlen(name_c) + 1);
        }
    }

    EMSCRIPTEN_KEEPALIVE bool set_transform(void *sceneManager, EntityId entityId, const float *const transform)
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

    EMSCRIPTEN_KEEPALIVE bool update_bone_matrices(void *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->updateBoneMatrices(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_morph_target_name_count(void *sceneManager, EntityId assetEntity, EntityId childEntity)
    {
        auto names = ((SceneManager *)sceneManager)->getMorphTargetNames(assetEntity, childEntity);
        return (int)names->size();
    }

    EMSCRIPTEN_KEEPALIVE void get_morph_target_name(void *sceneManager, EntityId assetEntity, EntityId childEntity, char *const outPtr, int index)
    {
        auto names = ((SceneManager *)sceneManager)->getMorphTargetNames(assetEntity, childEntity);
        std::string name = names->at(index);
        strcpy(outPtr, name.c_str());
    }

    EMSCRIPTEN_KEEPALIVE void remove_entity(const void *const viewer, EntityId asset)
    {
        ((FilamentViewer *)viewer)->removeEntity(asset);
    }

    EMSCRIPTEN_KEEPALIVE void clear_entities(const void *const viewer)
    {
        ((FilamentViewer *)viewer)->clearEntities();
    }

    bool set_material_color(void *sceneManager, EntityId asset, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a)
    {
        return ((SceneManager *)sceneManager)->setMaterialColor(asset, meshName, materialIndex, r, g, b, a);
    }

    EMSCRIPTEN_KEEPALIVE void transform_to_unit_cube(void *sceneManager, EntityId asset)
    {
        ((SceneManager *)sceneManager)->transformToUnitCube(asset);
    }

    EMSCRIPTEN_KEEPALIVE void set_position(void *sceneManager, EntityId asset, float x, float y, float z)
    {
        ((SceneManager *)sceneManager)->setPosition(asset, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void set_rotation(void *sceneManager, EntityId asset, float rads, float x, float y, float z, float w)
    {
        ((SceneManager *)sceneManager)->setRotation(asset, rads, x, y, z, w);
    }

    EMSCRIPTEN_KEEPALIVE void set_scale(void *sceneManager, EntityId asset, float scale)
    {
        ((SceneManager *)sceneManager)->setScale(asset, scale);
    }

    EMSCRIPTEN_KEEPALIVE void queue_position_update(void *sceneManager, EntityId asset, float x, float y, float z, bool relative)
    {
        ((SceneManager *)sceneManager)->queuePositionUpdate(asset, x, y, z, relative);
    }

    EMSCRIPTEN_KEEPALIVE void queue_relative_position_update_world_axis(void *sceneManager, EntityId entity, float viewportX, float viewportY, float x, float y, float z)
    {
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateWorldAxis(entity, viewportX, viewportY, x, y, z);
    }

    EMSCRIPTEN_KEEPALIVE void queue_rotation_update(void *sceneManager, EntityId asset, float rads, float x, float y, float z, float w, bool relative)
    {
        ((SceneManager *)sceneManager)->queueRotationUpdate(asset, rads, x, y, z, w, relative);
    }

    EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(void *sceneManager, EntityId entity, float viewportX, float viewportY)
    {
        ((SceneManager *)sceneManager)->queueRelativePositionUpdateFromViewportVector(entity, viewportX, viewportY);
    }

    EMSCRIPTEN_KEEPALIVE void stop_animation(void *sceneManager, EntityId asset, int index)
    {
        ((SceneManager *)sceneManager)->stopAnimation(asset, index);
    }

    EMSCRIPTEN_KEEPALIVE int hide_mesh(void *sceneManager, EntityId asset, const char *meshName)
    {
        return ((SceneManager *)sceneManager)->hide(asset, meshName);
    }

    EMSCRIPTEN_KEEPALIVE int reveal_mesh(void *sceneManager, EntityId asset, const char *meshName)
    {
        return ((SceneManager *)sceneManager)->reveal(asset, meshName);
    }

    EMSCRIPTEN_KEEPALIVE void filament_pick(void *const viewer, int x, int y, void (*callback)(EntityId entityId, int x, int y))
    {
        ((FilamentViewer *)viewer)->pick(static_cast<uint32_t>(x), static_cast<uint32_t>(y), callback);
    }

    EMSCRIPTEN_KEEPALIVE const char *get_name_for_entity(void *const sceneManager, const EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->getNameForEntity(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int get_entity_count(void *const sceneManager, const EntityId target, bool renderableOnly)
    {
        return ((SceneManager *)sceneManager)->getEntityCount(target, renderableOnly);
    }

    EMSCRIPTEN_KEEPALIVE void get_entities(void *const sceneManager, const EntityId target, bool renderableOnly, EntityId *out)
    {
        ((SceneManager *)sceneManager)->getEntities(target, renderableOnly, out);
    }

    EMSCRIPTEN_KEEPALIVE const char *get_entity_name_at(void *const sceneManager, const EntityId target, int index, bool renderableOnly)
    {
        return ((SceneManager *)sceneManager)->getEntityNameAt(target, index, renderableOnly);
    }

    EMSCRIPTEN_KEEPALIVE void set_recording(void *const viewer, bool recording)
    {
        ((FilamentViewer *)viewer)->setRecording(recording);
    }

    EMSCRIPTEN_KEEPALIVE void set_recording_output_directory(void *const viewer, const char *outputDirectory)
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

    EMSCRIPTEN_KEEPALIVE void add_collision_component(void *const sceneManager, EntityId entityId, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform)
    {
        ((SceneManager *)sceneManager)->addCollisionComponent(entityId, onCollisionCallback, affectsCollidingTransform);
    }

    EMSCRIPTEN_KEEPALIVE void remove_collision_component(void *const sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeCollisionComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE bool add_animation_component(void *const sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->addAnimationComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void remove_animation_component(void *const sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeAnimationComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE EntityId create_geometry(void *const sceneManager, float *vertices, int numVertices, uint16_t *indices, int numIndices, int primitiveType, const char *materialPath)
    {
        return ((SceneManager *)sceneManager)->createGeometry(vertices, (uint32_t)numVertices, indices, numIndices, (filament::RenderableManager::PrimitiveType)primitiveType, materialPath);
    }

    EMSCRIPTEN_KEEPALIVE EntityId create_geometry_with_normals(void *const sceneManager, float *vertices, int numVertices, float *normals, int numNormals, uint16_t *indices, int numIndices, int primitiveType, const char *materialPath)
    {
        return ((SceneManager *)sceneManager)->createGeometryWithNormals(vertices, (uint32_t)numVertices, normals, (uint32_t)numNormals, indices, numIndices, (filament::RenderableManager::PrimitiveType)primitiveType, materialPath);
    }

    EMSCRIPTEN_KEEPALIVE EntityId find_child_entity_by_name(void *const sceneManager, const EntityId parent, const char *name)
    {
        auto entity = ((SceneManager *)sceneManager)->findChildEntityByName(parent, name);
        return utils::Entity::smuggle(entity);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_parent(void *const sceneManager, EntityId child)
    {
        return ((SceneManager *)sceneManager)->getParent(child);
    }

    EMSCRIPTEN_KEEPALIVE EntityId get_ancestor(void *const sceneManager, EntityId child)
    {
        return ((SceneManager *)sceneManager)->getAncestor(child);
    }

    EMSCRIPTEN_KEEPALIVE void set_parent(void *const sceneManager, EntityId child, EntityId parent, bool preserveScaling)
    {
        ((SceneManager *)sceneManager)->setParent(child, parent, preserveScaling);
    }

    EMSCRIPTEN_KEEPALIVE void test_collisions(void *const sceneManager, EntityId entity)
    {
        ((SceneManager *)sceneManager)->testCollisions(entity);
    }

    EMSCRIPTEN_KEEPALIVE void set_priority(void *const sceneManager, EntityId entity, int priority)
    {
        ((SceneManager *)sceneManager)->setPriority(entity, priority);
    }

    EMSCRIPTEN_KEEPALIVE void get_gizmo(void *const sceneManager, EntityId *out)
    {
        auto gizmo = ((SceneManager *)sceneManager)->gizmo;
        out[0] = Entity::smuggle(gizmo->x());
        out[1] = Entity::smuggle(gizmo->y());
        out[2] = Entity::smuggle(gizmo->z());
        out[3] = Entity::smuggle(gizmo->center());
    }

    EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(void *const sceneManager, EntityId entity)
    {
        return ((SceneManager *)sceneManager)->getBoundingBox(entity);
    }

    EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(void *const sceneManager, EntityId entity, float *minX, float *minY, float *maxX, float *maxY)
    {
        auto box = ((SceneManager *)sceneManager)->getBoundingBox(entity);
        *minX = box.minX;
        *minY = box.minY;
        *maxX = box.maxX;
        *maxY = box.maxY;
    }

    EMSCRIPTEN_KEEPALIVE void set_layer_enabled(void *const sceneManager, int layer, bool enabled)
    {
        ((SceneManager *)sceneManager)->setLayerEnabled(layer, enabled);
    }

    EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr)
    {
        free(ptr);
    }

    EMSCRIPTEN_KEEPALIVE void pick_gizmo(void *const sceneManager, int x, int y, void (*callback)(EntityId entityId, int x, int y))
    {
        ((SceneManager *)sceneManager)->gizmo->pick(x, y, callback);
    }

    EMSCRIPTEN_KEEPALIVE void set_gizmo_visibility(void *const sceneManager, bool visible)
    {
        ((SceneManager *)sceneManager)->gizmo->setVisibility(visible);
    }

    EMSCRIPTEN_KEEPALIVE void set_stencil_highlight(void *const sceneManager, EntityId entityId, float r, float g, float b)
    {
        ((SceneManager *)sceneManager)->setStencilHighlight(entityId, r, g, b);
    }

    EMSCRIPTEN_KEEPALIVE void remove_stencil_highlight(void *const sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->removeStencilHighlight(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void set_material_property_float(void *const sceneManager, EntityId entity, int materialIndex, const char* property, float value) {
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, value);
    }
    
    EMSCRIPTEN_KEEPALIVE void set_material_property_float4(void *const sceneManager, EntityId entity, int materialIndex, const char* property, float4 value) {
        filament::math::float4 filamentValue { value.x, value.y, value.z, value.w };
        
        ((SceneManager *)sceneManager)->setMaterialProperty(entity, materialIndex, property, filamentValue);
    }


}
