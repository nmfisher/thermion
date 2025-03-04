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

#include "ResourceBuffer.hpp"
#include "scene/SceneManager.hpp"
#include "ThreadPool.hpp"

namespace thermion
{

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;

    using namespace std::chrono;
    using namespace gltfio;
    using namespace camutils;

    class FilamentViewer
    {

        typedef int32_t EntityId;

    public:
        FilamentViewer(const void *context, const ResourceLoaderWrapperImpl *const resourceLoaderWrapper, void *const platform = nullptr, const char *uberArchivePath = nullptr);
        ~FilamentViewer();

        View* createView();
        View* getViewAt(int index);

        void loadSkybox(const char *const skyboxUri);
        void removeSkybox();

        void loadIbl(const char *const iblUri, float intensity);
        void removeIbl();
        void rotateIbl(const math::mat3f &matrix);
        void createIbl(float r, float g, float b, float intensity);

        void render(
            uint64_t frameTimeInNanos
        );
        void setFrameInterval(float interval);

        void setMainCamera(View *view);
        EntityId getMainCamera();
        Camera* getCamera(EntityId entity);
        
        float getCameraFov(bool horizontal);
        void setCameraFov(double fovDegrees, bool horizontal);

        SwapChain* createSwapChain(const void *surface);
        SwapChain* createSwapChain(uint32_t width, uint32_t height);
        void destroySwapChain(SwapChain* swapChain);

        RenderTarget* createRenderTarget(intptr_t textureId, uint32_t width, uint32_t height);
        void destroyRenderTarget(RenderTarget* renderTarget);

        Renderer *getRenderer();

        std::map<SwapChain*, std::vector<View*>> _renderable;
        
        void setRenderable(View* view, SwapChain* swapChain, bool renderable);

        void setBackgroundColor(const float r, const float g, const float b, const float a);
        void setBackgroundImage(const char *resourcePath, bool fillHeight, uint32_t width, uint32_t height);
        void clearBackgroundImage();
        void setBackgroundImagePosition(float x, float y, bool clamp, uint32_t width, uint32_t height);
        
        Engine* getEngine() { 
            return _engine;
        }

        

        void capture(View* view, uint8_t *out, bool useFence, SwapChain* swapChain, void (*onComplete)());
        void capture(View* view, uint8_t *out, bool useFence, SwapChain* swapChain, RenderTarget* renderTarget, void (*onComplete)());

        SceneManager *const getSceneManager()
        {
            return (SceneManager *const)_sceneManager;
        }

        SwapChain* getSwapChainAt(int index) {
            if(index < _swapChains.size()) {
                return _swapChains[index];
            }
            Log("Error: index %d is greater than available swapchains", index);
            return nullptr;
        }

    private:
        const ResourceLoaderWrapperImpl *const _resourceLoaderWrapper;
        Scene *_scene = nullptr;
        Engine *_engine = nullptr;
        thermion::ThreadPool *_tp = nullptr;
        Renderer *_renderer = nullptr;
        SceneManager *_sceneManager = nullptr;
        std::vector<RenderTarget*> _renderTargets;
        std::vector<SwapChain*> _swapChains;
        std::vector<View*> _views;

        std::mutex _renderMutex; // mutex to ensure thread safety when removing assets

        Texture *_skyboxTexture = nullptr;
        Skybox *_skybox = nullptr;
        Texture *_iblTexture = nullptr;
        IndirectLight *_indirectLight = nullptr;

        float _frameInterval = 1000.0 / 60.0;

        // Camera properties
        Camera *_mainCamera = nullptr; // the default camera added to every scene. If you want the *active* camera, access via View.
        
        // background image properties
        uint32_t _imageHeight = 0;
        uint32_t _imageWidth = 0;
        filament::math::mat4f _imageScale;
        Texture *_imageTexture = nullptr;
        Texture *_dummyImageTexture = nullptr;
        utils::Entity _imageEntity;
        VertexBuffer *_imageVb = nullptr;
        IndexBuffer *_imageIb = nullptr;
        Material *_imageMaterial = nullptr;
        TextureSampler _imageSampler;
        void loadKtx2Texture(std::string path, ResourceBuffer data);
        void loadKtxTexture(std::string path, ResourceBuffer data);
        void loadPngTexture(std::string path, ResourceBuffer data);
        void loadTextureFromPath(std::string path);
        void savePng(void *data, size_t size, int frameNumber);
        void createBackgroundImage();

        
        time_point_t _fpsCounterStartTime = std::chrono::high_resolution_clock::now();


        std::mutex _imageMutex;
        double _cumulativeAnimationUpdateTime = 0;
        int _frameCount = 0;
        int _skippedFrames = 0;
    };

    struct FrameCallbackData
    {
        FilamentViewer *viewer;
        uint32_t frameNumber;
    };

}
