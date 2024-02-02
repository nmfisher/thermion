#pragma once

#include <filament/Camera.h>
#include <filament/Frustum.h>
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>
#include <filament/View.h>
#include <filament/LightManager.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include <camutils/Manipulator.h>

#include <utils/NameComponentManager.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <fstream>
#include <iostream>
#include <string>
#include <chrono>

#include "AssetManager.hpp"
#include "ThreadPool.hpp"

using namespace std;
using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace camutils;

typedef int32_t EntityId;

namespace polyvox
{


    enum ToneMapping
    {
        ACES,
        FILMIC,
        LINEAR
    };

    class FilamentViewer
    {
    public:
        FilamentViewer(const void *context, const ResourceLoaderWrapper *const resourceLoaderWrapper, void *const platform = nullptr, const char *uberArchivePath = nullptr);
        ~FilamentViewer();

        void setToneMapping(ToneMapping toneMapping);
        void setBloom(float strength);
        void loadSkybox(const char *const skyboxUri);
        void removeSkybox();

        void loadIbl(const char *const iblUri, float intensity);
        void removeIbl();
        void rotateIbl(const math::mat3f & matrix);


        void removeAsset(EntityId asset);
        void clearAssets();

        void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
        void render(
            uint64_t frameTimeInNanos,
            void *pixelBuffer,
            void (*callback)(void *buf, size_t size, void *data),
            void *data);
        void setFrameInterval(float interval);

        bool setCamera(EntityId asset, const char *nodeName);

        void createSwapChain(const void *surface, uint32_t width, uint32_t height);
        void destroySwapChain();

        void createRenderTarget(intptr_t textureId, uint32_t width, uint32_t height);

        Renderer *getRenderer();

        void setBackgroundColor(const float r, const float g, const float b, const float a);
        void setBackgroundImage(const char *resourcePath, bool fillHeight);
        void clearBackgroundImage();
        void setBackgroundImagePosition(float x, float y, bool clamp);
        

        // Camera methods
        void moveCameraToAsset(EntityId entityId);
        void setViewFrustumCulling(bool enabled);
        void setCameraExposure(float aperture, float shutterSpeed, float sensitivity);
        void setCameraPosition(float x, float y, float z);
        void setCameraRotation(float rads, float x, float y, float z);
        const math::mat4 getCameraModelMatrix();
        const math::mat4 getCameraViewMatrix();
        const math::mat4 getCameraProjectionMatrix();
        const math::mat4 getCameraCullingProjectionMatrix();
        const filament::Frustum getCameraFrustum();
        void setCameraModelMatrix(const float *const matrix);
        void setCameraProjectionMatrix(const double *const matrix, double near, double far);
        void setCameraFocalLength(float focalLength);
        void setCameraCulling(double near, double far);
        double getCameraCullingNear();
        double getCameraCullingFar();
        void setCameraFocusDistance(float focusDistance);
        void setCameraManipulatorOptions(filament::camutils::Mode mode, double orbitSpeedX, double orbitSpeedY, double zoomSpeed);
        void grabBegin(float x, float y, bool pan);
        void grabUpdate(float x, float y);
        void grabEnd();
        void scrollBegin();
        void scrollUpdate(float x, float y, float delta);
        void scrollEnd();
        void pick(uint32_t x, uint32_t y, EntityId *entityId);
        
        EntityId addLight(LightManager::Type t, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
        void removeLight(EntityId entityId);
        void clearLights();
        void setPostProcessing(bool enabled);

        void setRecording(bool recording);
        void setRecordingOutputDirectory(const char* path);


        AssetManager *const getAssetManager()
        {
            return (AssetManager *const)_assetManager;
        }

    private:
        const ResourceLoaderWrapper *const _resourceLoaderWrapper;

        Scene *_scene = nullptr;
        View *_view = nullptr;
        Engine *_engine = nullptr;
        flutter_filament::ThreadPool* _tp = nullptr;
        Renderer *_renderer = nullptr;
        RenderTarget *_rt = nullptr;
        Texture *_rtColor = nullptr;
        Texture *_rtDepth = nullptr;

        SwapChain *_swapChain = nullptr;

        AssetManager *_assetManager = nullptr;

        NameComponentManager *_ncm = nullptr;

        std::mutex mtx; // mutex to ensure thread safety when removing assets

        vector<utils::Entity> _lights;
        Texture *_skyboxTexture = nullptr;
        Skybox *_skybox = nullptr;
        Texture *_iblTexture = nullptr;
        IndirectLight *_indirectLight = nullptr;
        bool _recomputeAabb = false;
        bool _actualSize = false;

        float _frameInterval = 1000.0 / 60.0;

        // Camera properties
        Camera *_mainCamera = nullptr; // the default camera added to every scene. If you want the *active* camera, access via View. 
        float _cameraFocalLength = 28.0f;
        float _cameraFocusDistance = 0.0f;
        Manipulator<double> *_manipulator = nullptr;
        filament::camutils::Mode _manipulatorMode = filament::camutils::Mode::ORBIT;
        double _orbitSpeedX = 0.01;
        double _orbitSpeedY = 0.01;
        double _zoomSpeed = 0.01;
        math::mat4f _cameraPosition;
        math::mat4f _cameraRotation;
        void _createManipulator();
        double _near = 0.05;  
        double _far = 1000.0; 

        ColorGrading *colorGrading = nullptr;

        // background image properties
        uint32_t _imageHeight = 0;
        uint32_t _imageWidth = 0;
        mat4f _imageScale;
        Texture *_imageTexture = nullptr;
        utils::Entity *_imageEntity = nullptr;
        VertexBuffer *_imageVb = nullptr;
        IndexBuffer *_imageIb = nullptr;
        Material *_imageMaterial = nullptr;
        TextureSampler _imageSampler;
        void loadKtx2Texture(string path, ResourceBuffer data);
        void loadKtxTexture(string path, ResourceBuffer data);
        void loadPngTexture(string path, ResourceBuffer data);
        void loadTextureFromPath(string path);
        void savePng(void* data, size_t size, int frameNumber);
    
        time_point_t _startTime = std::chrono::high_resolution_clock::now();

        bool _recording = false; 
        std::string _recordingOutputDirectory = std::string("/tmp");
        std::mutex _recordingMutex;
    };

    struct FrameCallbackData { 
        FilamentViewer* viewer;
        uint32_t frameNumber;
    };

}
