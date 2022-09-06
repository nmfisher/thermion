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

#include "SceneAssetLoader.hpp"
#include "SceneAsset.hpp"
#include "SceneResources.hpp"

using namespace std;
using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;
using namespace camutils;


namespace polyvox {
    class FilamentViewer {
        public:
            FilamentViewer(void* layer, LoadResource loadResource, FreeResource freeResource);
            ~FilamentViewer();

            void loadSkybox(const char* const skyboxUri);
            void removeSkybox();

            void loadIbl(const char* const iblUri);
            void removeIbl();
            
            SceneAsset* loadGlb(const char* const uri);
            SceneAsset* loadGltf(const char* const uri, const char* relativeResourcePath);
            void removeAsset(SceneAsset* asset);
            // removes all add assets from the current scene
            void clearAssets();

            void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
            void render(uint64_t frameTimeInNanos);
            void setFrameInterval(float interval);
            
            bool setFirstCamera(SceneAsset* asset);
            bool setCamera(SceneAsset* asset, const char* nodeName);
            void destroySwapChain();
            void createSwapChain(void* surface);

            Renderer* getRenderer();

            void setBackgroundImage(const char* resourcePath);
            void setBackgroundImagePosition(float x, float y);

            void setCameraPosition(float x, float y, float z);
            void setCameraRotation(float rads, float x, float y, float z);
            void setCameraFocalLength(float fl);
            void setCameraFocusDistance(float focusDistance);

            void grabBegin(float x, float y, bool pan);
            void grabUpdate(float x, float y);
            void grabEnd();
            void scrollBegin();
            void scrollUpdate(float x, float y, float delta);
            void scrollEnd();

            int32_t addLight(LightManager::Type t, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
            void removeLight(int32_t entityId);
            void clearLights();

        private:
            void createImageRenderable();
            void loadResources(std::string relativeResourcePath);
            void cleanup();
            
            void* _layer;

            Manipulator<float>* _manipulator = nullptr;
            math::mat4f _cameraPosition;
            math::mat4f _cameraRotation;

            LoadResource _loadResource;
            FreeResource _freeResource;
      
            Scene* _scene;
            View* _view;  
            Engine* _engine;
            
            // a default camera that we add to every scene
            Camera* _mainCamera;

            Renderer* _renderer;
    
            SwapChain* _swapChain = nullptr;

            vector<SceneAsset*> _assets;

            AssetLoader* _assetLoader;
            SceneAssetLoader* _sceneAssetLoader;
            NameComponentManager* _ncm;
            std::mutex mtx; // mutex to ensure thread safety when removing assets

            vector<Entity> _lights;
            Texture* _skyboxTexture;
            Skybox* _skybox;
            Texture* _iblTexture;
            IndirectLight* _indirectLight;

            MaterialProvider* _materialProvider;

            gltfio::ResourceLoader* _resourceLoader = nullptr;
            gltfio::TextureProvider* _stbDecoder = nullptr;
            bool _recomputeAabb = false;

            bool _actualSize = false;     
            
            float _cameraFocalLength = 28.0f;
            float _cameraFocusDistance = 0.0f;

            // these flags relate to the textured quad we use for rendering unlit background images
            uint32_t _imageHeight = 0;
            uint32_t _imageWidth = 0;
            mat4f _imageScale;
            Texture* _imageTexture = nullptr;
            Entity* _imageEntity = nullptr;
            VertexBuffer* _imageVb = nullptr;
            IndexBuffer* _imageIb = nullptr;
            Material* _imageMaterial = nullptr;
            TextureSampler _imageSampler;
            ColorGrading *colorGrading = nullptr;

            void _createManipulator();
            uint32_t _lastFrameTimeInNanos;
    };


}

            

