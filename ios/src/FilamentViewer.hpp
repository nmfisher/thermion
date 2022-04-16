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


namespace polyvox {

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;

    struct EmbeddedAnimationBuffer  {        
      EmbeddedAnimationBuffer(int animationIndex, float duration, bool loop) : animationIndex(animationIndex), duration(duration), loop(loop) {}
      bool hasStarted = false;
      int animationIndex;
      float duration = 0;
      time_point_t lastTime;
      bool loop;
    };

    

    struct ResourceBuffer {
        ResourceBuffer(const void* data, const uint32_t size, const uint32_t id) : data(data), size(size), id(id) {};

        ResourceBuffer& operator=(ResourceBuffer other)
        {
          data = other.data;
          size = other.size;
          id = other.id;
          return *this;
        }
        const void* data;
        uint32_t size;
        uint32_t id;
    };

    using LoadResource = std::function<ResourceBuffer(const char* uri)>;
    using FreeResource = std::function<void (ResourceBuffer)>;

    struct MorphAnimationBuffer {
      
      MorphAnimationBuffer(float* frameData,
                           int numWeights,
                           int numFrames,
                           float frameLength) : frameData(frameData), numWeights(numWeights), numFrames(numFrames), frameLength(frameLength) {
      }
      
      int frameIndex = -1;
      int numFrames;
      float frameLength;
      time_point_t startTime;
      
      float* frameData;
      int numWeights;
    };

    class FilamentViewer {
        public:
            FilamentViewer(void* layer, LoadResource loadResource, FreeResource freeResource);
            ~FilamentViewer();
            void loadGlb(const char* const uri);
            void loadGltf(const char* const uri, const char* relativeResourcePath);
            void loadSkybox(const char* const skyboxUri, const char* const iblUri);

            void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
            void render();
            void releaseSourceAssets();
            unique_ptr<vector<string>> getTargetNames(const char* meshName);
            unique_ptr<vector<string>> getAnimationNames();
            Manipulator<float>* manipulator;
            void applyWeights(float* weights, int count);
            void animateWeights(float* data, int numWeights, int length, float frameRate);

            void playAnimation(int index, bool loop);
            bool setCamera(const char* nodeName);
            void destroySwapChain();
            void createSwapChain(void* surface);

            Renderer* getRenderer();

        private:
      
            void loadResources(std::string relativeResourcePath);
            void transformToUnitCube();
            void cleanup();
            
            void* _layer;

            LoadResource _loadResource;
            FreeResource _freeResource;
      
            Scene* _scene;
            View* _view;  
            Engine* _engine;
            Camera* _mainCamera;
            Renderer* _renderer;
    
            SwapChain* _swapChain = nullptr;

            Animator* _animator;

            AssetLoader* _assetLoader;
            FilamentAsset* _asset = nullptr;
            ResourceBuffer _assetBuffer;
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

            void updateMorphAnimation();
            void updateEmbeddedAnimation();
            
            // animation flags;
            bool isAnimating;
            unique_ptr<MorphAnimationBuffer> morphAnimationBuffer;
            unique_ptr<EmbeddedAnimationBuffer> embeddedAnimationBuffer;
    };


}

            

