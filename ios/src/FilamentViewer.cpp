/*
 * Copyright (C) 2019 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "FilamentViewer.hpp"

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
#include <filament/Viewport.h>

#include <filament/IndirectLight.h>
#include <filament/LightManager.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/Animator.h>

#include <camutils/Manipulator.h>

#include <utils/NameComponentManager.h>
#include <utils/JobSystem.h>

#include "math.h"
#include "upcast.h"

#include <math/mat4.h>
#include <math/quat.h>
#include <math/scalar.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <image/KtxUtility.h>

#include <chrono>
#include <iostream>

using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;

namespace filament {
    class IndirectLight;
    class LightManager;
}

namespace gltfio {
    MaterialProvider* createGPUMorphShaderLoader(const void* data, uint64_t size, Engine* engine);
    void decomposeMatrix(const filament::math::mat4f& mat, filament::math::float3* translation,
                    filament::math::quatf* rotation, filament::math::float3* scale);
}

namespace mimetic {
    
const double kNearPlane = 0.05;   // 5 cm
const double kFarPlane = 1000.0;  // 1 km
const float kScaleMultiplier = 100.0f;
const float kAperture = 16.0f;
const float kShutterSpeed = 1.0f / 125.0f;
const float kSensitivity = 100.0f;

filament::math::mat4f composeMatrix(const filament::math::float3& translation,
        const filament::math::quatf& rotation, const filament::math::float3& scale) {
    float tx = translation[0];
    float ty = translation[1];
    float tz = translation[2];
    float qx = rotation[0];
    float qy = rotation[1];
    float qz = rotation[2];
    float qw = rotation[3];
    float sx = scale[0];
    float sy = scale[1];
    float sz = scale[2];
    return filament::math::mat4f(
        (1 - 2 * qy*qy - 2 * qz*qz) * sx,
        (2 * qx*qy + 2 * qz*qw) * sx,
        (2 * qx*qz - 2 * qy*qw) * sx,
        0.f,
        (2 * qx*qy - 2 * qz*qw) * sy,
        (1 - 2 * qx*qx - 2 * qz*qz) * sy,
        (2 * qy*qz + 2 * qx*qw) * sy,
        0.f,
        (2 * qx*qz + 2 * qy*qw) * sz,
        (2 * qy*qz - 2 * qx*qw) * sz,
        (1 - 2 * qx*qx - 2 * qy*qy) * sz,
        0.f, tx, ty, tz, 1.f);
}

FilamentViewer::FilamentViewer(
        void* layer, 
        const char* shaderPath,
        LoadResource loadResource, 
        FreeResource freeResource) : _layer(layer), 
                                    _loadResource(loadResource),
                                    _freeResource(freeResource),
                                    materialProviderResources(nullptr, 0) {
    _engine = Engine::create(Engine::Backend::OPENGL);

    _renderer = _engine->createRenderer();
    _scene = _engine->createScene();
    Entity camera = EntityManager::get().create();
    _mainCamera = _engine->createCamera(camera);
    _view = _engine->createView();
    _view->setScene(_scene);
    _view->setCamera(_mainCamera);

    _cameraFocalLength = 28.0f;
    _mainCamera->setExposure(kAperture, kShutterSpeed, kSensitivity);

    _swapChain = _engine->createSwapChain(_layer);

   if(shaderPath) {
     materialProviderResources = _loadResource(shaderPath);
     _materialProvider = createGPUMorphShaderLoader(materialProviderResources.data, materialProviderResources.size, _engine);
      // _freeResource((void*)rb.data, rb.size, nullptr); <- TODO this is being freed too early, need to pass to callback?
   } else {
        _materialProvider = createUbershaderLoader(_engine);
   }
    EntityManager& em = EntityManager::get();
    _ncm = new NameComponentManager(em);
    _assetLoader = AssetLoader::create({_engine, _materialProvider, _ncm, &em});
    _resourceLoader = new ResourceLoader(
            {.engine = _engine, .normalizeSkinningWeights = true, .recomputeBoundingBoxes = false});
        
    manipulator =
            Manipulator<float>::Builder().orbitHomePosition(0.0f, 0.0f, 0.0f).targetPosition(0.0f, 0.0f, 0).build(Mode::ORBIT);
    _asset = nullptr;

}

FilamentViewer::~FilamentViewer() {

}

void FilamentViewer::loadResources(string relativeResourcePath) {
    const char* const* const resourceUris = _asset->getResourceUris();
    const size_t resourceUriCount = _asset->getResourceUriCount();
    for (size_t i = 0; i < resourceUriCount; i++) {
        string uri = relativeResourcePath + string(resourceUris[i]);
        ResourceBuffer buf = _loadResource(uri.c_str());
        ResourceLoader::BufferDescriptor b(
                buf.data, buf.size, (ResourceLoader::BufferDescriptor::Callback)&_freeResource, nullptr);
        _resourceLoader->addResourceData(resourceUris[i], std::move(b));
    }

    _resourceLoader->loadResources(_asset);
    const Entity* entities = _asset->getEntities();
    RenderableManager& rm = _engine->getRenderableManager();
    for(int i =0; i< _asset->getEntityCount(); i++) {
        Entity e = entities[i];
        auto inst = rm.getInstance(e);
        rm.setCulling(inst, false);
    }

    _animator = _asset->getAnimator();

    _scene->addEntities(_asset->getEntities(), _asset->getEntityCount());    
};

void FilamentViewer::releaseSourceAssets() {
  std::cout << "Releasing source data" << std::endl;
  _asset->releaseSourceData();
  _freeResource((void*)materialProviderResources.data, materialProviderResources.size, nullptr);
}

void FilamentViewer::animateWeightsInternal(float* data, int numWeights, int length, float frameRate) {
  int frameIndex = 0;
  int numFrames = length / numWeights;
  float frameLength = 1000 / frameRate;

  applyWeights(data, numWeights);
  auto animationStartTime = std::chrono::high_resolution_clock::now();
  while(frameIndex < numFrames) {
    duration dur = std::chrono::high_resolution_clock::now() - animationStartTime;
    int msElapsed = dur.count();
    if(msElapsed > frameLength) {
      std::cout << "frame" << frameIndex << std::endl;
      frameIndex++;
      applyWeights(data + (frameIndex * numWeights), numWeights);
      animationStartTime = std::chrono::high_resolution_clock::now();
    }
  }
}



void FilamentViewer::animateWeights(float* data, int numWeights, int length, float frameRate) {
  int numFrames = length / numWeights;
  float frameLength = 1000 / frameRate;
  
  thread* t = new thread(
[=](){
    int frameIndex = 0;

    applyWeights(data, numWeights);
    auto animationStartTime = std::chrono::high_resolution_clock::now();
    while(frameIndex < numFrames) {
      duration dur = std::chrono::high_resolution_clock::now() - animationStartTime;
      int msElapsed = dur.count();
      if(msElapsed > frameLength) {
        frameIndex++;
        applyWeights(data + (frameIndex * numWeights), numWeights);
        animationStartTime = std::chrono::high_resolution_clock::now();
      }
    }
 });
}

void FilamentViewer::loadGltf(const char* const uri, const char* const relativeResourcePath) {
    if(_asset) {
        _resourceLoader->evictResourceData();
        _scene->removeEntities(_asset->getEntities(), _asset->getEntityCount());
        _assetLoader->destroyAsset(_asset);
    }
    _asset = nullptr;
    _animator = nullptr;

    ResourceBuffer rbuf = _loadResource(uri);
    
    // Parse the glTF file and create Filament entities.
    _asset = _assetLoader->createAssetFromJson((uint8_t*)rbuf.data, rbuf.size);
  
    if (!_asset) {
        std::cerr << "Unable to parse asset" << std::endl;
        exit(1);
    }

    loadResources(string(relativeResourcePath) + string("/"));

    _freeResource((void*)rbuf.data, rbuf.size, nullptr);
  
    transformToUnitCube();

    startTime = std::chrono::high_resolution_clock::now();

}

StringList FilamentViewer::getTargetNames(const char* meshName) {
  FFilamentAsset* asset = (FFilamentAsset*)_asset;
  NodeMap &sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap
                                            : asset->mNodeMap;

  for (auto pair : sourceNodes) {
      cgltf_node const *node = pair.first;
      cgltf_mesh const *mesh = node->mesh;

      if (mesh && strcmp(meshName, mesh->name) == 0) {
        return StringList((const char**)mesh->target_names, (int) mesh->target_names_count);
      }
  }
  return StringList(nullptr, 0);
}

void FilamentViewer::createMorpher(const char* meshName, int* primitives, int numPrimitives) {
  morphHelper = new gltfio::GPUMorphHelper((FFilamentAsset*)_asset, meshName, primitives, numPrimitives);
//  morphHelper = new gltfio::CPUMorpher(((FFilamentAsset)*_asset, (FFilamentInstance*)_asset));
}

void FilamentViewer::applyWeights(float* weights, int count) {
  morphHelper->applyWeights(weights, count);
}

void FilamentViewer::animateBones() {
  Entity entity = _asset->getFirstEntityByName("CC_Base_JawRoot");
  if(!entity) {
    return;
  }

  TransformManager& transformManager = _engine->getTransformManager();

  TransformManager::Instance node = transformManager.getInstance(  entity);

  mat4f xform = transformManager.getTransform(node);
  float3 scale;
  quatf rotation;
  float3 translation;
  decomposeMatrix(xform, &translation, &rotation, &scale);

//  const quatf srcQuat { weights[0] * 0.9238,0,weights[0] *  0.3826, 0 };
//  float3 { scale[0] * (1.0f - weights[0]), scale[1] * (1.0f - weights[1]), scale[2] * (1.0f - weights[2]) }
//  xform = composeMatrix(translation + float3 { weights[0], weights[1], weights[2] }, rotation, scale );
  transformManager.setTransform(node, xform);

}

void FilamentViewer::playAnimation(int index) {
  _activeAnimation = index;
}

    
void FilamentViewer::loadSkybox(const char* const skyboxPath, const char* const iblPath) {
    ResourceBuffer skyboxBuffer = _loadResource(skyboxPath);
    
    image::KtxBundle* skyboxBundle =
            new image::KtxBundle(static_cast<const uint8_t*>(skyboxBuffer.data),
                    static_cast<uint32_t>(skyboxBuffer.size));
    _skyboxTexture = image::ktx::createTexture(_engine, skyboxBundle, false);
    _skybox = filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);
    _scene->setSkybox(_skybox);
    _freeResource((void*)skyboxBuffer.data, skyboxBuffer.size, nullptr);

    // Load IBL.
    ResourceBuffer iblBuffer = _loadResource(iblPath);

    image::KtxBundle* iblBundle = new image::KtxBundle(
            static_cast<const uint8_t*>(iblBuffer.data), static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture = image::ktx::createTexture(_engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                             .reflections(_iblTexture)
                             .irradiance(3, harmonics)
                             .intensity(30000.0f)
                             .build(*_engine);
    _scene->setIndirectLight(_indirectLight);
  
    _freeResource((void*)iblBuffer.data, iblBuffer.size, nullptr);

    // Always add a direct light source since it is required for shadowing.
    _sun = EntityManager::get().create();
    LightManager::Builder(LightManager::Type::DIRECTIONAL)
            .color(Color::cct(6500.0f))
            .intensity(100000.0f)
            .direction(math::float3(0.0f, -1.0f, 0.0f))
            .castShadows(true)
            .build(*_engine, _sun);
    _scene->addEntity(_sun);
}

void FilamentViewer::transformToUnitCube() {
      if (!_asset) {
          return;
      }
      auto& tm = _engine->getTransformManager();
      auto aabb = _asset->getBoundingBox();
      auto center = aabb.center();
      auto halfExtent = aabb.extent();
      auto maxExtent = max(halfExtent) * 2;
      auto scaleFactor = 2.0f / maxExtent;
      auto transform = math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
      tm.setTransform(tm.getInstance(_asset->getRoot()), transform);
}

void FilamentViewer::cleanup() {
    _resourceLoader->asyncCancelLoad();
    _assetLoader->destroyAsset(_asset);
    _materialProvider->destroyMaterials();
    AssetLoader::destroy(&_assetLoader);
};

void FilamentViewer::render() {
    if (!_view || !_mainCamera || !manipulator || !_animator) {
        return;
    }
  // Extract the camera basis from the helper and push it to the Filament camera.
    math::float3 eye, target, upward;
    manipulator->getLookAt(&eye, &target, &upward);

    _mainCamera->lookAt(eye, target, upward);

    if(_animator) {

        duration dur = std::chrono::high_resolution_clock::now() - startTime;
        if (_activeAnimation >= 0 && _animator->getAnimationCount() > 0) {
            _animator->applyAnimation(_activeAnimation, dur.count() / 1000);
            _animator->updateBoneMatrices();
        }
    }

    // Render the scene, unless the renderer wants to skip the frame.
    if (_renderer->beginFrame(_swapChain)) {
        _renderer->render(_view);
        _renderer->endFrame();
    }
}

void FilamentViewer::updateViewportAndCameraProjection(int width, int height, float contentScaleFactor) {
    if (!_view || !_mainCamera || !manipulator) {
        return;
    }

    manipulator->setViewport(width, height);

    const uint32_t _width = width * contentScaleFactor;
    const uint32_t _height = height * contentScaleFactor;
    _view->setViewport({0, 0, _width, _height});

    const double aspect = (double)width / height;
    _mainCamera->setLensProjection(_cameraFocalLength, aspect, kNearPlane, kFarPlane);
}


}
