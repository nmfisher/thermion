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
                           float frameLength) : frameData(frameData), numWeights(numWeights), numFrames(numFrames), frameLengthInMs(frameLength) {
      }
      
      int frameIndex = -1;
      int numFrames;
      float frameLengthInMs;
      time_point_t startTime;
      
      float* frameData;
      int numWeights;
    };

    class FilamentViewer {
        public:
            FilamentViewer(void* layer, LoadResource loadResource, FreeResource freeResource);
            ~FilamentViewer();

            void loadSkybox(const char* const skyboxUri, const char* const iblUri);
            void removeSkybox();
            
            void loadGlb(const char* const uri);
            void loadGltf(const char* const uri, const char* relativeResourcePath);
            void removeAsset();

            void updateViewportAndCameraProjection(int height, int width, float scaleFactor);
            void render();
            unique_ptr<vector<string>> getTargetNames(const char* meshName);
            unique_ptr<vector<string>> getAnimationNames();
            Manipulator<float>* manipulator;
            
            
            ///
            /// Manually set the weights for all morph targets in the assets to the provided values.
            /// See [animateWeights] if you want to automatically
            ///
            void applyWeights(float* weights, int count);

            ///
            /// Update the asset's morph target weights every "frame" (which is an arbitrary length of time, i.e. this is not the same as a frame at the framerate of the underlying rendering framework).
            /// Accordingly:
            ///       length(data) = numWeights * numFrames
            ///       total_animation_duration_in_ms = number_of_frames * frameLengthInMs
            ///
            void animateWeights(float* data, int numWeights, int numFrames, float frameLengthInMs);

            ///  
            /// Play an embedded animation (i.e. an animation node embedded in the GLTF asset). If [loop] is true, the animation will repeat indefinitely.
            ///
            void playAnimation(int index, bool loop);

            ///
            /// Immediately stop the currently playing animation. NOOP if no animation is playing.
            ///
            void stopAnimation();

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
            NameComponentManager* _ncm;
            std::mutex mtx; // mutex to ensure thread safety when removing assets

            Entity _sun;
            Texture* _skyboxTexture;
            Skybox* _skybox;
            Texture* _iblTexture;
            IndirectLight* _indirectLight;

            MaterialProvider* _materialProvider;

            gltfio::ResourceLoader* _resourceLoader = nullptr;
            gltfio::TextureProvider* _stbDecoder = nullptr;
            bool _recomputeAabb = false;

            bool _actualSize = false;     
            
            float _cameraFocalLength = 0.0f;

            void updateMorphAnimation();
            void updateEmbeddedAnimation();
            
            // animation flags;
            bool isAnimating;
            unique_ptr<MorphAnimationBuffer> _morphAnimationBuffer;
            unique_ptr<EmbeddedAnimationBuffer> _embeddedAnimationBuffer;

    };


}

            

