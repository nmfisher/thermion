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

#include "FFilamentInstance.h"
#include "FFilamentAsset.h"

#include <math/mat4.h>
#include <math/quat.h>
#include <math/scalar.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <image/KtxUtility.h>

#include <chrono>
#include <iostream>

#include "Log.h"

#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <android/native_activity.h>

using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;
using namespace std::chrono;

namespace gltfio
{
  MaterialProvider *createUbershaderLoader(filament::Engine *engine);
}

namespace filament
{
  class IndirectLight;
  class LightManager;
}

namespace gltfio
{
  MaterialProvider *createGPUMorphShaderLoader(
      const void *opaqueData,
      uint64_t opaqueDataSize,
      const void *fadeData,
      uint64_t fadeDataSize,
      Engine *engine);
  void decomposeMatrix(const filament::math::mat4f &mat, filament::math::float3 *translation,
                       filament::math::quatf *rotation, filament::math::float3 *scale);
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
      const char *opaqueShaderPath,
      const char *fadeShaderPath,
      LoadResource loadResource,
      FreeResource freeResource) : _layer(layer),
                                   _loadResource(loadResource),
                                   _freeResource(freeResource),
                                   opaqueShaderResources(nullptr, 0, 0),
                                   fadeShaderResources(nullptr, 0, 0),
                                   _assetBuffer(nullptr, 0, 0)
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

    _materialProvider = gltfio::createUbershaderLoader(_engine);

    EntityManager &em = EntityManager::get();
    _ncm = new NameComponentManager(em);
    _assetLoader = AssetLoader::create({_engine, _materialProvider, _ncm, &em});
    _resourceLoader = new ResourceLoader(
        {.engine = _engine, .normalizeSkinningWeights = true, .recomputeBoundingBoxes = true});

    manipulator =
        Manipulator<float>::Builder().orbitHomePosition(0.0f, 0.0f, 0.05f).targetPosition(0.0f, 0.0f, 0.0f).build(Mode::ORBIT);
    _asset = nullptr;
  }

  FilamentViewer::~FilamentViewer()
  {
  }

  Renderer *FilamentViewer::getRenderer()
  {
    return _renderer;
  }

  void FilamentViewer::createSwapChain(void *surface)
  {
    _swapChain = _engine->createSwapChain(surface);
    // Log("swapchain created.");
  }

  void FilamentViewer::destroySwapChain()
  {
    if (_swapChain)
    {
      _engine->destroy(_swapChain);
      _swapChain = nullptr;
    }
    // Log("swapchain destroyed.");
  }

  void FilamentViewer::applyWeights(float *weights, int count)
  {

    for (size_t i = 0, c = _asset->getEntityCount(); i != c; ++i)
    {
      _asset->setMorphWeights(
          _asset->getEntities()[i],
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

  void FilamentViewer::releaseSourceAssets()
  {
    Log("Releasing source data");
    _asset->releaseSourceData();
    // _freeResource(opaqueShaderResources);
    // _freeResource(fadeShaderResources);
  }

  void FilamentViewer::loadGlb(const char *const uri)
  {

    Log("Loading GLB at URI %s", uri);

    if (_asset)
    {
      _asset->releaseSourceData();
      _resourceLoader->evictResourceData();
      _scene->removeEntities(_asset->getEntities(), _asset->getEntityCount());
      _assetLoader->destroyAsset(_asset);
    }
    _asset = nullptr;
    _animator = nullptr;

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

    Log("Successfully loaded GLB.");
  }

  void FilamentViewer::loadGltf(const char *const uri, const char *const relativeResourcePath)
  {

    Log("Loading GLTF at URI %s", uri);

    if (_asset)
    {
      Log("Asset already exists");
      _resourceLoader->evictResourceData();
      _scene->removeEntities(_asset->getEntities(), _asset->getEntityCount());
      _assetLoader->destroyAsset(_asset);
      _freeResource(_assetBuffer);
    }
    _asset = nullptr;
    _animator = nullptr;

    _assetBuffer = _loadResource(uri);

    // Parse the glTF file and create Filament entities.
    Log("Creating asset from JSON");
    _asset = _assetLoader->createAssetFromJson((uint8_t *)_assetBuffer.data, _assetBuffer.size);
    Log("Created asset from JSON");

    if (!_asset)
    {
      Log("Unable to parse asset");
      exit(1);
    }
    Log("Loading relative resources");
    loadResources(string(relativeResourcePath) + string("/"));
    Log("Loaded relative resources");
    //    _asset->releaseSourceData();

    Log("Load complete for GLTF at URI %s", uri);

    // transformToUnitCube();
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
    FFilamentAsset *asset = (FFilamentAsset *)_asset;

    gltfio::NodeMap &sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap
                                                        : asset->mNodeMap;
    Log("Setting camera to node %s", cameraName);
    for (auto pair : sourceNodes)
    {
      cgltf_node const *node = pair.first;

      if (strcmp(cameraName, node->name) != 0)
      {
        continue;
      }

      Log("Node %s : Matrix : %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f %03f Translation : %03f %03f %03f Rotation %03f %03f %03f %03f Scale %03f %03f %03f",
          node->name,
          node->matrix[0],
          node->matrix[1],
          node->matrix[2],
          node->matrix[3],
          node->matrix[4],
          node->matrix[5],
          node->matrix[6],
          node->matrix[7],
          node->matrix[8],
          node->matrix[9],
          node->matrix[10],
          node->matrix[11],
          node->matrix[12],
          node->matrix[13],
          node->matrix[14],
          node->matrix[15],
          node->translation[0],
          node->translation[1],
          node->translation[2],
          node->rotation[0],
          node->rotation[1],
          node->rotation[2],
          node->rotation[3],
          node->scale[0],
          node->scale[1],
          node->scale[2]
        );
      mat4f t = mat4f::translation(float3 { node->translation[0],node->translation[1],node->translation[2] });
      mat4f r { quatf { node->rotation[3], node->rotation[0], node->rotation[1], node->rotation[2] } };
      mat4f transform = t * r;

      if (!node->camera)
      {
        cgltf_node* leaf = node->children[0];

        Log("Child 1 trans : %03f %03f %03f rot : %03f %03f %03f %03f ", leaf->translation[0], leaf->translation[1],leaf->translation[2], leaf->rotation[0],leaf->rotation[1],leaf->rotation[2],leaf->rotation[3]);

        if (!leaf->camera) {
          leaf = leaf->children[0];
          Log("Child 2 %03f %03f %03f %03f %03f %03f %03f ", leaf->translation[0], leaf->translation[1],leaf->translation[2], leaf->rotation[0],leaf->rotation[1],leaf->rotation[2],leaf->rotation[3]);
          if (!leaf->camera) {
            Log("Could not find GLTF camera under node or its ssecond or third child nodes.");
            exit(-1);
          }
        }

        Log("Using rotation from leaf node.");

        mat4f child_rot { quatf { leaf->rotation[3], leaf->rotation[0], leaf->rotation[1], leaf->rotation[2] } };

        transform *= child_rot;
      }
  
      Entity cameraEntity = EntityManager::get().create();
      Camera *cam = _engine->createCamera(cameraEntity);

      const Viewport &vp = _view->getViewport();

      const double aspect = (double)vp.width / vp.height;

      // todo - pull focal length from gltf node

      cam->setLensProjection(_cameraFocalLength, aspect, kNearPlane, kFarPlane);

      if (!cam)
      {
        Log("Couldn't create camera");
      }
      else
      {
        _engine->getTransformManager().setTransform(
            _engine->getTransformManager().getInstance(cameraEntity), transform
            );

        _view->setCamera(cam);
        return true;
      }
    }
    return false;
  }

  unique_ptr<vector<string>> FilamentViewer::getAnimationNames()
  {

    size_t count = _animator->getAnimationCount();

    Log("Found %d animations in asset.", count);

    unique_ptr<vector<string>> names = make_unique<vector<string>>();

    for (size_t i = 0; i < count; i++)
    {
      names->push_back(_animator->getAnimationName(i));
    }

    return names;
  }

  StringList FilamentViewer::getTargetNames(const char *meshName)
  {
    FFilamentAsset *asset = (FFilamentAsset *)_asset;
    NodeMap &sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap : asset->mNodeMap;

    if (sourceNodes.empty())
    {
      Log("Asset source nodes empty?");
      return StringList(nullptr, 0);
    }
    Log("Fetching morph target names for mesh %s", meshName);

    for (auto pair : sourceNodes)
    {
      cgltf_node const *node = pair.first;
      cgltf_mesh const *mesh = node->mesh;

      if (mesh)
      {
        Log("Mesh : %s ", mesh->name);
        if (strcmp(meshName, mesh->name) == 0)
        {
          return StringList((const char **)mesh->target_names, (int)mesh->target_names_count);
        }
      }
    }
    return StringList(nullptr, 0);
  }

  void FilamentViewer::loadSkybox(const char *const skyboxPath, const char *const iblPath, AAssetManager *am)
  {

    ResourceBuffer skyboxBuffer = _loadResource(skyboxPath);

    image::KtxBundle *skyboxBundle =
        new image::KtxBundle(static_cast<const uint8_t *>(skyboxBuffer.data), static_cast<uint32_t>(skyboxBuffer.size));
    _skyboxTexture = image::ktx::createTexture(_engine, skyboxBundle, false);
    _skybox = filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);

    _scene->setSkybox(_skybox);
    _freeResource(skyboxBuffer);

    Log("Loading IBL from %s", iblPath);

    // Load IBL.
    ResourceBuffer iblBuffer = _loadResource(iblPath);

    image::KtxBundle *iblBundle = new image::KtxBundle(
        static_cast<const uint8_t *>(iblBuffer.data), static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture = image::ktx::createTexture(_engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                         .reflections(_iblTexture)
                         .irradiance(3, harmonics)
                         .intensity(30000.0f)
                         .build(*_engine);
    _scene->setIndirectLight(_indirectLight);

    _freeResource(iblBuffer);

    // Always add a direct light source since it is required for shadowing.
    _sun = EntityManager::get().create();
    LightManager::Builder(LightManager::Type::DIRECTIONAL)
        .color(Color::cct(6500.0f))
        .intensity(100000.0f)
        .direction(math::float3(0.0f, 1.0f, 0.0f))
        .castShadows(true)
        .build(*_engine, _sun);
    _scene->addEntity(_sun);

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
    _freeResource(_assetBuffer);
  };

  void FilamentViewer::render()
  {
    if (!_view || !_mainCamera || !_swapChain)
    {
      Log("Not ready for rendering");
      return;
    }

    if (morphAnimationBuffer)
    {
      updateMorphAnimation();
    }

    if(embeddedAnimationBuffer) {
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
    Log("Set viewport to %d %d", _width, _height);
  }

  void FilamentViewer::animateWeights(float *data, int numWeights, int numFrames, float frameRate)
  {
    morphAnimationBuffer = std::make_unique<MorphAnimationBuffer>(data, numWeights, numFrames, 1000 / frameRate);
  }

  void FilamentViewer::updateMorphAnimation()
  {

    if (morphAnimationBuffer->frameIndex >= morphAnimationBuffer->numFrames)
    {
      morphAnimationBuffer = nullptr;
      return;
    }

    if (morphAnimationBuffer->frameIndex == -1)
    {
      morphAnimationBuffer->frameIndex++;
      morphAnimationBuffer->startTime = std::chrono::high_resolution_clock::now();
      applyWeights(morphAnimationBuffer->frameData, morphAnimationBuffer->numWeights);
    }
    else
    {
      std::chrono::duration<double, std::milli> dur = std::chrono::high_resolution_clock::now() - morphAnimationBuffer->startTime;
      int frameIndex = dur.count() / morphAnimationBuffer->frameLength;
      if (frameIndex != morphAnimationBuffer->frameIndex)
      {
        morphAnimationBuffer->frameIndex = frameIndex;
        applyWeights(morphAnimationBuffer->frameData + (morphAnimationBuffer->frameIndex * morphAnimationBuffer->numWeights), morphAnimationBuffer->numWeights);
      }
    }
  }

  void FilamentViewer::playAnimation(int index) {
    embeddedAnimationBuffer = make_unique<EmbeddedAnimationBuffer>(index, _animator->getAnimationDuration(index));
  }

  void FilamentViewer::updateEmbeddedAnimation() {
    duration<double> dur = duration_cast<duration<double>>(std::chrono::high_resolution_clock::now() - embeddedAnimationBuffer->lastTime);
    float startTime = 0;
    if(!embeddedAnimationBuffer->hasStarted) {
      embeddedAnimationBuffer->hasStarted = true;
      embeddedAnimationBuffer->lastTime = std::chrono::high_resolution_clock::now();
    } else if(dur.count() >= embeddedAnimationBuffer->duration) {
      embeddedAnimationBuffer = nullptr;
      return;
    } else {
      startTime = dur.count();
    }

    _animator->applyAnimation(embeddedAnimationBuffer->animationIndex, startTime);
    _animator->updateBoneMatrices();

  }

}


// //
// //if(morphAnimationBuffer.frameIndex >= morphAnimationBuffer.numFrames) {
// //  this.morphAnimationBuffer = null;
// //  return;
// //}
// //
// //if(morphAnimationBuffer.frameIndex == -1) {
// //  applyWeights(morphAnimationBuffer->frameData, morphAnimationBuffer->numWeights);
// //  morphAnimationBuffer->frameIndex++;
// //  morphAnimationBuffer->lastTime = std::chrono::high_resolution_clock::now();
// //} else {
// //  duration dur = std::chrono::high_resolution_clock::now() - morphAnimationBuffer->lastTime;
// //  float msElapsed = dur.count();
// //  if(msElapsed > morphAnimationBuffer->frameLength) {
// //      frameIndex++;
// //      applyWeights(frameData + (frameIndex * numWeights), numWeights);
// //      morphAnimationBuffer->lastTime = std::chrono::high_resolution_clock::now();
// //  }
// //}


// void FilamentViewer::createMorpher(const char* meshName, int* primitives, int numPrimitives) {
//   // morphHelper = new gltfio::GPUMorphHelper((FFilamentAsset*)_asset, meshName, primitives, numPrimitives);
// //  morphHelper = new gltfio::CPUMorpher(((FFilamentAsset)*_asset, (FFilamentInstance*)_asset));
// }

// void FilamentViewer::animateBones() {
// }
//   Entity entity = _asset->getFirstEntityByName("CC_Base_JawRoot");
//   if(!entity) {
//     return;
//   }

//   TransformManager& transformManager = _engine->getTransformManager();

//   TransformManager::Instance node = transformManager.getInstance(  entity);

//   mat4f xform = transformManager.getTransform(node);
//   float3 scale;
//   quatf rotation;
//   float3 translation;
//   decomposeMatrix(xform, &translation, &rotation, &scale);

// //  const quatf srcQuat { weights[0] * 0.9238,0,weights[0] *  0.3826, 0 };
// //  float3 { scale[0] * (1.0f - weights[0]), scale[1] * (1.0f - weights[1]), scale[2] * (1.0f - weights[2]) }
// //  xform = composeMatrix(translation + float3 { weights[0], weights[1], weights[2] }, rotation, scale );
//   transformManager.setTransform(node, xform);

// }

// void FilamentViewer::updateAnimation(AnimationBuffer animation, std::function<void(int)> callback) {
//  if(morphAnimationBuffer.frameIndex >= animation.numFrames) {
//    this.animation = null;
//    return;
//  }

//  if(animation.frameIndex == -1) {
//    animation->frameIndex++;
//    animation->lastTime = std::chrono::high_resolution_clock::now();
//    callback(); //     applyWeights(morphAnimationBuffer->frameData, morphAnimationBuffer->numWeights);
//  } else {
//    duration dur = std::chrono::high_resolution_clock::now() - morphAnimationBuffer->lastTime;
//    float msElapsed = dur.count();
//    if(msElapsed > animation->frameLength) {
//        animation->frameIndex++;
//        animation->lastTime = std::chrono::high_resolution_clock::now();
//        callback(); //             applyWeights(frameData + (frameIndex * numWeights), numWeights);
//    }
//  }
// }
