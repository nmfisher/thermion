#pragma once

#include <filament/Camera.h>
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

using namespace std;
using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace camutils;

typedef int32_t EntityId;

namespace polyvox {

    enum ToneMapping {
        ACES, FILMIC, LINEAR
    };
    
    class FilamentViewer {
        public:
            FilamentViewer(const void* context, const ResourceLoaderWrapper* const resourceLoaderWrapper);
            ~FilamentViewer();

            void setToneMapping(ToneMapping toneMapping);
            void loadSkybox(const char* const skyboxUri);
            void removeSkybox();

            void loadIbl(const char* const iblUri, float intensity);
            void removeIbl();
            
            void removeAsset(EntityId asset);
            // removes all add assets from the current scene
            void clearAssets();

            void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
            void render(uint64_t frameTimeInNanos);
            void setFrameInterval(float interval);
            
            bool setCamera(EntityId asset, const char* nodeName);
            
            void createSwapChain(const void* surface, uint32_t width, uint32_t height);
            void destroySwapChain();

            void createRenderTarget(uint32_t glTextureId, uint32_t width,uint32_t height);

            Renderer* getRenderer();

            void setBackgroundColor(const float r, const float g, const float b, const float a);
            void setBackgroundImage(const char* resourcePath);
            void clearBackgroundImage();
            void setBackgroundImagePosition(float x, float y, bool clamp);
            void setCameraExposure(float aperture, float shutterSpeed, float sensitivity);
            void setCameraPosition(float x, float y, float z);
            void setCameraRotation(float rads, float x, float y, float z);
            void setCameraModelMatrix(const float* const matrix);
            void setCameraFocalLength(float fl);
            void setCameraFocusDistance(float focusDistance);

            void grabBegin(float x, float y, bool pan);
            void grabUpdate(float x, float y);
            void grabEnd();
            void scrollBegin();
            void scrollUpdate(float x, float y, float delta);
            void scrollEnd();

            int32_t addLight(LightManager::Type t, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
            void removeLight(EntityId entityId);
            void clearLights();

            AssetManager* const getAssetManager() {
                return (AssetManager* const) _assetManager;
            }

        private:
            void createImageRenderable();
            void loadResources(std::string relativeResourcePath);
            void cleanup();            

            bool _panning = false;
            float _startX;
            float _startY;
            math::mat4f _cameraPosition;
            math::mat4f _cameraRotation;

            const ResourceLoaderWrapper* const _resourceLoaderWrapper;
      
            Scene* _scene;
            View* _view;  
            Engine* _engine;
            
            // a default camera that we add to every scene
            Camera* _mainCamera;

            Renderer* _renderer;
            RenderTarget* _rt;
            Texture* _rtColor;
            Texture* _rtDepth;
    
            SwapChain* _swapChain = nullptr;

            AssetManager* _assetManager = nullptr;
            
            NameComponentManager* _ncm = nullptr;
            
            std::mutex mtx; // mutex to ensure thread safety when removing assets

            vector<utils::Entity> _lights;
            Texture* _skyboxTexture = nullptr;
            Skybox* _skybox = nullptr;
            Texture* _iblTexture = nullptr;
            IndirectLight* _indirectLight = nullptr;

            bool _recomputeAabb = false;

            bool _actualSize = false;     
            
            float _cameraFocalLength = 28.0f;
            float _cameraFocusDistance = 0.0f;

            ColorGrading *colorGrading = nullptr;

            // background image properties
            uint32_t _imageHeight = 0;
            uint32_t _imageWidth = 0;
            mat4f _imageScale;
            Texture* _imageTexture = nullptr;
            utils::Entity* _imageEntity = nullptr;
            VertexBuffer* _imageVb = nullptr;
            IndexBuffer* _imageIb = nullptr;
            Material* _imageMaterial = nullptr;
            TextureSampler _imageSampler;
            void loadKtx2Texture(string path, ResourceBuffer data);
            void loadKtxTexture(string path, ResourceBuffer data);
            void loadPngTexture(string path, ResourceBuffer data);
            void loadTextureFromPath(string path);
            
            
            void _createManipulator();
            uint32_t _lastFrameTimeInNanos;
    };


}

            

