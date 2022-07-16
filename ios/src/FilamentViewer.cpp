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
#include <gltfio/TextureProvider.h>

#include <gltfio/materials/uberarchive.h>

#include <camutils/Manipulator.h>

#include <utils/NameComponentManager.h>

#include "math.h"

#include <math/mat4.h>
#include <math/quat.h>
#include <math/scalar.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <ktxreader/Ktx1Reader.h>

#include <chrono>
#include <iostream>

#include <mutex>

#include "Log.h"

using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;
using namespace std::chrono;

namespace filament
{
  class IndirectLight;
  class LightManager;
}

namespace polyvox
{

  const double kNearPlane = 0.05;  // 5 cm
  const double kFarPlane = 1000.0; // 1 km
  const float kScaleMultiplier = 100.0f;
  const float kAperture = 16.0f;
  const float kShutterSpeed = 1.0f / 125.0f;
  const float kSensitivity = 100.0f;

  filament::math::mat4f composeMatrix(const filament::math::float3 &translation,
                                      const filament::math::quatf &rotation, const filament::math::float3 &scale)
  {
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
        (1 - 2 * qy * qy - 2 * qz * qz) * sx,
        (2 * qx * qy + 2 * qz * qw) * sx,
        (2 * qx * qz - 2 * qy * qw) * sx,
        0.f,
        (2 * qx * qy - 2 * qz * qw) * sy,
        (1 - 2 * qx * qx - 2 * qz * qz) * sy,
        (2 * qy * qz + 2 * qx * qw) * sy,
        0.f,
        (2 * qx * qz + 2 * qy * qw) * sz,
        (2 * qy * qz - 2 * qx * qw) * sz,
        (1 - 2 * qx * qx - 2 * qy * qy) * sz,
        0.f, tx, ty, tz, 1.f);
  }

  FilamentViewer::FilamentViewer(
      void *layer,
      LoadResource loadResource,
      FreeResource freeResource) : _layer(layer),
                                   _loadResource(loadResource),
                                   _freeResource(freeResource)
  {
    _engine = Engine::create(Engine::Backend::OPENGL);

    _renderer = _engine->createRenderer();

    _renderer->setDisplayInfo({.refreshRate = 60.0f,
                               .presentationDeadlineNanos = (uint64_t)0,
                               .vsyncOffsetNanos = (uint64_t)0});
    _scene = _engine->createScene();
    Entity camera = EntityManager::get().create();
    _mainCamera = _engine->createCamera(camera);
    _view = _engine->createView();
    _view->setScene(_scene);
    _view->setCamera(_mainCamera);

    _cameraFocalLength = 28.0f;
    _mainCamera->setExposure(kAperture, kShutterSpeed, kSensitivity);

    _swapChain = _engine->createSwapChain(_layer);

    View::DynamicResolutionOptions options;
    options.enabled = true;
    // options.homogeneousScaling = homogeneousScaling;
    // options.minScale = filament::math::float2{ minScale };
    // options.maxScale = filament::math::float2{ maxScale };
    // options.sharpness = sharpness;
    options.quality = View::QualityLevel::MEDIUM;
    ;
    _view->setDynamicResolutionOptions(options);

    View::MultiSampleAntiAliasingOptions multiSampleAntiAliasingOptions;
    multiSampleAntiAliasingOptions.enabled = true;

    _view->setMultiSampleAntiAliasingOptions(multiSampleAntiAliasingOptions);

    _materialProvider = gltfio::createUbershaderProvider(_engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);

    EntityManager &em = EntityManager::get();
    _ncm = new NameComponentManager(em);
    _assetLoader = AssetLoader::create({_engine, _materialProvider, _ncm, &em});
    _resourceLoader = new ResourceLoader(
        {.engine = _engine, .normalizeSkinningWeights = true, .recomputeBoundingBoxes = true});
    _stbDecoder = createStbProvider(_engine);
    _resourceLoader->addTextureProvider("image/png", _stbDecoder);
    _resourceLoader->addTextureProvider("image/jpeg", _stbDecoder);
    manipulator =
        Manipulator<float>::Builder().orbitHomePosition(0.0f, 0.0f, 0.05f).targetPosition(0.0f, 0.0f, 0.0f).build(Mode::ORBIT);
    _asset = nullptr;

    // Always add a direct light source since it is required for shadowing.
    _sun = EntityManager::get().create();
    LightManager::Builder(LightManager::Type::DIRECTIONAL)
        .color(Color::cct(6500.0f))
        .intensity(100000.0f)
        .direction(math::float3(0.0f, 1.0f, 0.0f))
        .castShadows(false)
        // .castShadows(true)
        .build(*_engine, _sun);
    _scene->addEntity(_sun);

  }

  FilamentViewer::~FilamentViewer()
  {
    cleanup();
  }

  Renderer *FilamentViewer::getRenderer()
  {
    return _renderer;
  }

  void FilamentViewer::createSwapChain(void *surface)
  {
    _swapChain = _engine->createSwapChain(surface);
    Log("swapchain created.");
  }

  void FilamentViewer::destroySwapChain()
  {
    if (_swapChain)
    {
      _engine->destroy(_swapChain);
      _swapChain = nullptr;
      Log("Swapchain destroyed.");
    }
  }

  void FilamentViewer::applyWeights(float *weights, int count)
  {

    for (size_t i = 0, c = _asset->getEntityCount(); i != c; ++i)
    {
      RenderableManager &rm = _engine->getRenderableManager();
      auto inst = rm.getInstance(_asset->getEntities()[i]);
      rm.setMorphWeights(
          inst,
          weights,
          count);
    }
  }

  void FilamentViewer::loadResources(string relativeResourcePath)
  {
    const char *const *const resourceUris = _asset->getResourceUris();
    const size_t resourceUriCount = _asset->getResourceUriCount();

    Log("Loading %d resources for asset", resourceUriCount);

    for (size_t i = 0; i < resourceUriCount; i++)
    {
      string uri = relativeResourcePath + string(resourceUris[i]);
      Log("Creating resource buffer for resource at %s",uri.c_str());
      ResourceBuffer buf = _loadResource(uri.c_str());

      // using FunctionCallback = std::function<void(void*, unsigned int, void *)>;

      // auto cb = [&] (void * ptr, unsigned int len, void * misc)  {

      // };
      // FunctionCallback fcb = cb;
      ResourceLoader::BufferDescriptor b(
          buf.data, buf.size);
      _resourceLoader->addResourceData(resourceUris[i], std::move(b));
      _freeResource(buf);
    }

    _resourceLoader->loadResources(_asset);
    const Entity *entities = _asset->getEntities();
    RenderableManager &rm = _engine->getRenderableManager();
    for (int i = 0; i < _asset->getEntityCount(); i++)
    {
      Entity e = entities[i];
      auto inst = rm.getInstance(e);
      rm.setCulling(inst, false);
    }

    _animator = _asset->getAnimator();

    _scene->addEntities(_asset->getEntities(), _asset->getEntityCount());
  };

  void FilamentViewer::loadGlb(const char *const uri)
  {

    Log("Loading GLB at URI %s", uri);

    ResourceBuffer rbuf = _loadResource(uri);

    _asset = _assetLoader->createAssetFromBinary(
        (const uint8_t *)rbuf.data, rbuf.size);

    if (!_asset)
    {
      Log("Unknown error loading GLB asset.");
      exit(1);
    }

    int entityCount = _asset->getEntityCount();

    _scene->addEntities(_asset->getEntities(), entityCount);

    Log("Added %d entities to scene", entityCount);
    _resourceLoader->loadResources(_asset);
    _animator = _asset->getAnimator();

    const Entity *entities = _asset->getEntities();
    RenderableManager &rm = _engine->getRenderableManager();
    for (int i = 0; i < _asset->getEntityCount(); i++)
    {
      Entity e = entities[i];
      auto inst = rm.getInstance(e);
      rm.setCulling(inst, false);
    }

    _freeResource(rbuf);

    _animator->updateBoneMatrices();

    // transformToUnitCube();

    _asset->releaseSourceData();

    Log("Successfully loaded GLB.");
  }

  void FilamentViewer::loadGltf(const char *const uri, const char *const relativeResourcePath)
  {

    Log("Loading GLTF at URI %s", uri);

    _asset = nullptr;
    _animator = nullptr;

    ResourceBuffer rbuf  = _loadResource(uri);

    // Parse the glTF file and create Filament entities.
    Log("Creating asset from JSON");
    _asset = _assetLoader->createAssetFromJson((uint8_t *)rbuf.data, rbuf.size);
    Log("Created asset from JSON");

    if (!_asset)
    {
      Log("Unable to parse asset");
      exit(1);
    }
    Log("Loading relative resources");
    loadResources(string(relativeResourcePath) + string("/"));
    Log("Loaded relative resources");
    _asset->releaseSourceData();

    Log("Load complete for GLTF at URI %s", uri);

    // transformToUnitCube();
  }

  void FilamentViewer::removeAsset() {
    if (!_asset) {
      Log("No asset loaded, ignoring call.");
      return;
    }

    mtx.lock();
    
    _resourceLoader->evictResourceData();
    _scene->removeEntities(_asset->getEntities(), _asset->getEntityCount());
    _assetLoader->destroyAsset(_asset);
    _asset = nullptr;
    _animator = nullptr;
    _morphAnimationBuffer = nullptr;
    _embeddedAnimationBuffer = nullptr;
    _view->setCamera(_mainCamera);
    mtx.unlock();
  }

  void FilamentViewer::removeSkybox() { 
    _scene->setSkybox(nullptr);
  }


  ///
  /// Sets the active camera to the GLTF camera specified by [name].
  /// Blender export arranges cameras as follows
  /// - parent node with global (?) matrix
  /// --- child node with "camera" property set to camera node name
  /// - camera node
  /// We therefore find the first node where the "camera" property is equal to the requested name,
  /// then use the parent transform matrix.
  ///
  bool FilamentViewer::setCamera(const char *cameraName)
  {
    Log("Attempting to set camera to %s.", cameraName);
    size_t count = _asset->getCameraEntityCount();
    if(count == 0) {
          Log("Failed, no cameras found in current asset.");
      return false;
    }

    const utils::Entity* cameras = _asset->getCameraEntities();
    Log("%zu cameras found in current asset", cameraName, count);
    for(int i=0; i < count; i++) {
      
      auto inst = _ncm->getInstance(cameras[i]);
      const char* name = _ncm->getName(inst);
      Log("Camera %d : %s", i, name);
      if (strcmp(name, cameraName) == 0) {

        Camera* camera = _engine->createCamera(cameras[i]);
        const Viewport &vp = _view->getViewport();

        const double aspect = (double)vp.width / vp.height;

        // todo - pull focal length from gltf node

        camera->setLensProjection(_cameraFocalLength, aspect, kNearPlane, kFarPlane);
        _view->setCamera(camera);
        Log("Successfully set camera.");
        return true;
      }
    }
    Log("Unable to locate camera under name %s ", cameraName);
    return false;
  }

  unique_ptr<vector<string>> FilamentViewer::getAnimationNames()
  {
    if(!_asset) {
      Log("No asset, ignoring call.");
      return nullptr;
    }
    size_t count = _animator->getAnimationCount();

    Log("Found %d animations in asset.", count);

    unique_ptr<vector<string>> names = make_unique<vector<string>>();

    for (size_t i = 0; i < count; i++)
    {
      names->push_back(_animator->getAnimationName(i));
    }

    return names;
  }

  unique_ptr<vector<string>> FilamentViewer::getTargetNames(const char *meshName)
  {
    if(!_asset) {
      Log("No asset, ignoring call.");
      return nullptr;
    }
    Log("Retrieving morph target names for mesh  %s", meshName);
    unique_ptr<vector<string>> names = make_unique<vector<string>>();
    const Entity *entities = _asset->getEntities();
    RenderableManager &rm = _engine->getRenderableManager();
    for (int i = 0; i < _asset->getEntityCount(); i++)
    {
      Entity e = entities[i];
      auto inst = _ncm->getInstance(e);
      const char* name = _ncm->getName(inst);
      Log("Got entity instance name %s", name);
      if(strcmp(name, meshName) == 0) {
        size_t count = _asset->getMorphTargetCountAt(e);
        for(int j=0; j< count; j++) {
          const char* morphName = _asset->getMorphTargetNameAt(e, j);
          names->push_back(morphName);
        }
        break;
      }
    }
    return names;
  }

  void FilamentViewer::loadSkybox(const char *const skyboxPath, const char *const iblPath)
  {

    ResourceBuffer skyboxBuffer = _loadResource(skyboxPath);

    image::Ktx1Bundle *skyboxBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(skyboxBuffer.data), static_cast<uint32_t>(skyboxBuffer.size));
    _skyboxTexture = ktxreader::Ktx1Reader::createTexture(_engine, skyboxBundle, false);
    _skybox = filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);

    _scene->setSkybox(_skybox);
    _freeResource(skyboxBuffer);

    Log("Loading IBL from %s", iblPath);

    // Load IBL.
    ResourceBuffer iblBuffer = _loadResource(iblPath);

    image::Ktx1Bundle *iblBundle = new image::Ktx1Bundle(
        static_cast<const uint8_t *>(iblBuffer.data), static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture = ktxreader::Ktx1Reader::createTexture(_engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                         .reflections(_iblTexture)
                         .irradiance(3, harmonics)
                         .intensity(30000.0f)
                         .build(*_engine);
    _scene->setIndirectLight(_indirectLight);

    _freeResource(iblBuffer);

    Log("Skybox/IBL load complete.");
  }

  void FilamentViewer::transformToUnitCube()
  {
    if (!_asset)
    {
      Log("No asset, cannot transform.");
      return;
    }
    auto &tm = _engine->getTransformManager();
    auto aabb = _asset->getBoundingBox();
    auto center = aabb.center();
    auto halfExtent = aabb.extent();
    auto maxExtent = max(halfExtent) * 2;
    auto scaleFactor = 2.0f / maxExtent;
    auto transform = math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
    tm.setTransform(tm.getInstance(_asset->getRoot()), transform);
  }

  void FilamentViewer::cleanup()
  {
    _resourceLoader->asyncCancelLoad();
    _assetLoader->destroyAsset(_asset);
    _materialProvider->destroyMaterials();
    AssetLoader::destroy(&_assetLoader);
  };

  void FilamentViewer::render()
  {

    if (!_view || !_mainCamera || !_swapChain)
    {
      Log("Not ready for rendering");
      return;
    }
    
    mtx.lock();
    if(_asset) {
      updateMorphAnimation();
      updateEmbeddedAnimation();
    }
    

    math::float3 eye, target, upward;
    manipulator->getLookAt(&eye, &target, &upward);
    _mainCamera->lookAt(eye, target, upward);

    // Render the scene, unless the renderer wants to skip the frame.
    if (_renderer->beginFrame(_swapChain))
    {
      _renderer->render(_view);
      _renderer->endFrame();
    }
    mtx.unlock();  
  }

  void FilamentViewer::updateViewportAndCameraProjection(int width, int height, float contentScaleFactor)
  {
    if (!_view || !_mainCamera)
    {
      Log("Skipping camera update, no view or camrea");
      return;
    }

    const uint32_t _width = width * contentScaleFactor;
    const uint32_t _height = height * contentScaleFactor;
    _view->setViewport({0, 0, _width, _height});

    const double aspect = (double)width / height;
    _mainCamera->setLensProjection(_cameraFocalLength, aspect, kNearPlane, kFarPlane);

    Log("Set viewport to width: %d height:  %d scaleFactor : %f", width, height, contentScaleFactor);
  }

  void FilamentViewer::animateWeights(float *data, int numWeights, int numFrames, float frameLengthInMs)
  {
    Log("Making morph animation buffer with %d weights across %d frames and frame length %f ms ", numWeights, numFrames, frameLengthInMs);
    _morphAnimationBuffer = std::make_unique<MorphAnimationBuffer>(data, numWeights, numFrames, frameLengthInMs);
  }

  void FilamentViewer::updateMorphAnimation()
  {
    if(!_morphAnimationBuffer) {
      return;
    }

    if (_morphAnimationBuffer->frameIndex == -1) {
      _morphAnimationBuffer->frameIndex++;
      _morphAnimationBuffer->startTime = high_resolution_clock::now();
      applyWeights(_morphAnimationBuffer->frameData, _morphAnimationBuffer->numWeights);
    }
    else
    {
      duration<double, std::milli> dur = high_resolution_clock::now() - _morphAnimationBuffer->startTime;
      int frameIndex = static_cast<int>(dur.count() / _morphAnimationBuffer->frameLengthInMs);

      if (frameIndex > _morphAnimationBuffer->numFrames - 1)
      {
        duration<double, std::milli> dur = high_resolution_clock::now() - _morphAnimationBuffer->startTime;
        Log("Morph animation completed in %f ms (%d frames at framerate %f), final frame was %d", dur.count(), _morphAnimationBuffer->numFrames, 1000 / _morphAnimationBuffer->frameLengthInMs, _morphAnimationBuffer->frameIndex);
        _morphAnimationBuffer = nullptr;
      } else if (frameIndex != _morphAnimationBuffer->frameIndex) {
        Log("Rendering frame %d (of a total %d)", frameIndex, _morphAnimationBuffer->numFrames);
        _morphAnimationBuffer->frameIndex = frameIndex;
        auto framePtrOffset = frameIndex * _morphAnimationBuffer->numWeights;
        applyWeights(_morphAnimationBuffer->frameData + framePtrOffset, _morphAnimationBuffer->numWeights);
      }
    }
  }

  void FilamentViewer::playAnimation(int index, bool loop) {
    if(index > _animator->getAnimationCount() - 1) {
      Log("Asset does not contain an animation at index %d", index);
    } else {
      _embeddedAnimationBuffer = make_unique<EmbeddedAnimationBuffer>(index, _animator->getAnimationDuration(index), loop);
    }
  }

  void FilamentViewer::stopAnimation() {
    // TODO - does this need to be threadsafe?
    _embeddedAnimationBuffer = nullptr;
  }

  void FilamentViewer::updateEmbeddedAnimation() {
    if(!_embeddedAnimationBuffer) {
      return;
    }
    duration<double> dur = duration_cast<duration<double>>(high_resolution_clock::now() - _embeddedAnimationBuffer->lastTime);
    float startTime = 0;
    if(!_embeddedAnimationBuffer->hasStarted) {
      _embeddedAnimationBuffer->hasStarted = true;
      _embeddedAnimationBuffer->lastTime = high_resolution_clock::now();
    } else if(dur.count() >= _embeddedAnimationBuffer->duration) {
      if(_embeddedAnimationBuffer->loop) {
        _embeddedAnimationBuffer->lastTime = high_resolution_clock::now();
      } else {
        _embeddedAnimationBuffer = nullptr;
        return;
      }
    } else {
      startTime = dur.count();
    }

    _animator->applyAnimation(_embeddedAnimationBuffer->animationIndex, startTime);
    _animator->updateBoneMatrices();

  }

}

