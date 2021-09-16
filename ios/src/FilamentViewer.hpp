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

using namespace std;
using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;
using namespace camutils;


namespace mimetic {

    struct ResourceBuffer {
        ResourceBuffer(const void* data, const uint32_t size) : data(data), size(size) {};
        const void* data;
        const uint64_t size;
    };

    using LoadResource = std::function<ResourceBuffer(const char* uri)>;
    using FreeResource = std::function<void * (void *mem, size_t s, void *)>;

    class FilamentViewer {
        public:
            FilamentViewer(void* layer, LoadResource loadResource, FreeResource freeResource);
            ~FilamentViewer();
            void loadGltf(const char* const uri, const char* relativeResourcePath);
            void loadSkybox(const char* const skyboxUri, const char* const iblUri);
            void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
            void render();
            Manipulator<float>* manipulator;
        private:
            void loadResources(std::string relativeResourcePath);
            void transformToUnitCube();
            void cleanup();
            void* _layer;
            
            LoadResource _loadResource;
            FreeResource _freeResource;

            std::chrono::high_resolution_clock::time_point startTime;
            
            Scene* _scene;
            View* _view;  
            Engine* _engine;
            Camera* _mainCamera;
            Renderer* _renderer;
    
            SwapChain* _swapChain;

            Animator* _animator;

            AssetLoader* _assetLoader;
            FilamentAsset* _asset = nullptr;
            NameComponentManager* _ncm;

            Entity _sun;
            Texture* _skyboxTexture;
            Skybox* _skybox;
            Texture* _iblTexture;
            IndirectLight* _indirectLight;

            MaterialProvider* _materialProvider;

            gltfio::ResourceLoader* _resourceLoader = nullptr;
            bool _recomputeAabb = false;

            bool _actualSize = false;     
            
            float _cameraFocalLength = 0.0f;


    };
}
