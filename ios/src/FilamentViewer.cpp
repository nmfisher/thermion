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

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>

#include <gltfio/materials/uberarchive.h>

#include <camutils/Manipulator.h>

#include <utils/NameComponentManager.h>

#include <imageio/ImageDecoder.h>

#include "math.h"

#include <math/mat4.h>
#include <math/quat.h>
#include <math/scalar.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <ktxreader/Ktx1Reader.h>

#include <iostream>

#include <mutex>

#include "Log.hpp"
#include "SceneResources.hpp"
#include "image/imagematerial.h"
#include "FilamentViewer.hpp"
#include "StreamBufferAdapter.hpp"

using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;
using namespace image;

namespace filament {
class IndirectLight;
class LightManager;
} // namespace filament

namespace polyvox {

const double kNearPlane = 0.05;  // 5 cm
const double kFarPlane = 1000.0; // 1 km
const float kScaleMultiplier = 100.0f;
const float kAperture = 16.0f;
const float kShutterSpeed = 1.0f / 125.0f;
const float kSensitivity = 100.0f;

FilamentViewer::FilamentViewer(void *layer, LoadResource loadResource,
                               FreeResource freeResource)
    : _layer(layer), _loadResource(loadResource), _freeResource(freeResource) {
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

  ToneMapper *tm = new LinearToneMapper();
  colorGrading = ColorGrading::Builder().toneMapper(tm).build(*_engine);
  delete tm;

  _view->setColorGrading(colorGrading);

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

  _materialProvider = gltfio::createUbershaderProvider(
      _engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);

  EntityManager &em = EntityManager::get();
  _ncm = new NameComponentManager(em);
  _assetLoader = AssetLoader::create({_engine, _materialProvider, _ncm, &em});
  _resourceLoader = new ResourceLoader({.engine = _engine,
                                        .normalizeSkinningWeights = true,
                                        .recomputeBoundingBoxes = true});
  _stbDecoder = createStbProvider(_engine);
  _resourceLoader->addTextureProvider("image/png", _stbDecoder);
  _resourceLoader->addTextureProvider("image/jpeg", _stbDecoder);
  manipulator = Manipulator<float>::Builder()
                    .orbitHomePosition(0.0f, 0.0f, 0.05f)
                    .targetPosition(0.0f, 0.0f, 0.0f)
                    .build(Mode::ORBIT);

  // Always add a direct light source since it is required for shadowing.
  _sun = EntityManager::get().create();
  LightManager::Builder(LightManager::Type::SUN)
      .color(Color::cct(6500.0f))
      .intensity(150000.0f)
      .direction(math::float3(0.0f, 0.0f, -1.0f))
      .castShadows(false)
      // .castShadows(true)
      .build(*_engine, _sun);
  _scene->addEntity(_sun);

  
  _sceneAssetLoader = new SceneAssetLoader(_loadResource,
                                   _freeResource,
                                   _assetLoader,
                                   _resourceLoader,
                                   _ncm, 
                                   _engine,
                                   _scene);
}

static constexpr float4 sFullScreenTriangleVertices[3] = {
    {-1.0f, -1.0f, 1.0f, 1.0f},
    {3.0f, -1.0f, 1.0f, 1.0f},
    {-1.0f, 3.0f, 1.0f, 1.0f}};

static const uint16_t sFullScreenTriangleIndices[3] = {0, 1, 2};

void FilamentViewer::createImageRenderable() {

  if (_imageEntity)
    return;

  auto &em = EntityManager::get();
  _imageMaterial =
      Material::Builder()
          .package(IMAGEMATERIAL_IMAGE_DATA, IMAGEMATERIAL_IMAGE_SIZE)
          .build(*_engine);

  _imageVb = VertexBuffer::Builder()
                 .vertexCount(3)
                 .bufferCount(1)
                 .attribute(VertexAttribute::POSITION, 0,
                            VertexBuffer::AttributeType::FLOAT4, 0)
                 .build(*_engine);

  _imageVb->setBufferAt(
      *_engine, 0,
      {sFullScreenTriangleVertices, sizeof(sFullScreenTriangleVertices)});

  _imageIb = IndexBuffer::Builder()
                 .indexCount(3)
                 .bufferType(IndexBuffer::IndexType::USHORT)
                 .build(*_engine);

  _imageIb->setBuffer(*_engine, {sFullScreenTriangleIndices,
                                 sizeof(sFullScreenTriangleIndices)});

  Entity imageEntity = em.create();
  RenderableManager::Builder(1)
      .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
      .material(0, _imageMaterial->getDefaultInstance())
      .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, _imageVb,
                _imageIb, 0, 3)
      .culling(false)
      .build(*_engine, imageEntity);

  _scene->addEntity(imageEntity);

  _imageEntity = &imageEntity;

  Texture *texture = Texture::Builder()
                         .width(1)
                         .height(1)
                         .levels(1)
                         .format(Texture::InternalFormat::RGBA8)
                         .sampler(Texture::Sampler::SAMPLER_2D)
                         .build(*_engine);
  static uint32_t pixel = 0;
  Texture::PixelBufferDescriptor buffer(&pixel, 4, Texture::Format::RGBA,
                                        Texture::Type::UBYTE);
  texture->setImage(*_engine, 0, std::move(buffer));
}

void FilamentViewer::setBackgroundImage(const char *resourcePath) {

  createImageRenderable();

  if (_imageTexture) {
    _engine->destroy(_imageTexture);
    _imageTexture = nullptr;
  }

  ResourceBuffer bg = _loadResource(resourcePath);

  polyvox::StreamBufferAdapter sb((char *)bg.data, (char *)bg.data + bg.size);

  std::istream *inputStream = new std::istream(&sb);

  LinearImage *image = new LinearImage(ImageDecoder::decode(
      *inputStream, resourcePath, ImageDecoder::ColorSpace::SRGB));

  if (!image->isValid()) {
    Log("Invalid image : %s", resourcePath);
    return;
  }

  delete inputStream;

  _freeResource(bg);

  uint32_t channels = image->getChannels();
  uint32_t w = image->getWidth();
  uint32_t h = image->getHeight();
  _imageTexture = Texture::Builder()
                      .width(w)
                      .height(h)
                      .levels(0xff)
                      .format(channels == 3 ? Texture::InternalFormat::RGB16F
                                            : Texture::InternalFormat::RGBA16F)
                      .sampler(Texture::Sampler::SAMPLER_2D)
                      .build(*_engine);

  Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
                                                             void *data) {
    delete reinterpret_cast<LinearImage *>(data);
  };

  Texture::PixelBufferDescriptor buffer(
      image->getPixelRef(), size_t(w * h * channels * sizeof(float)),
      channels == 3 ? Texture::Format::RGB : Texture::Format::RGBA,
      Texture::Type::FLOAT, freeCallback);

  _imageTexture->setImage(*_engine, 0, std::move(buffer));
  _imageTexture->generateMipmaps(*_engine);

  float srcWidth = _imageTexture->getWidth();
  float srcHeight = _imageTexture->getHeight();
  float dstWidth = _view->getViewport().width;
  float dstHeight = _view->getViewport().height;

  mat3f transform(1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f);

  _imageMaterial->setDefaultParameter("transform", transform);
  _imageMaterial->setDefaultParameter("image", _imageTexture, _imageSampler);

  _imageMaterial->setDefaultParameter("showImage", 1);

  _imageMaterial->setDefaultParameter("backgroundColor", RgbType::sRGB,
                                      float3(1.0f));
}

FilamentViewer::~FilamentViewer() { cleanup(); }

Renderer *FilamentViewer::getRenderer() { return _renderer; }

void FilamentViewer::createSwapChain(void *surface) {
  _swapChain = _engine->createSwapChain(surface);
  Log("swapchain created.");
}

void FilamentViewer::destroySwapChain() {
  if (_swapChain) {
    _engine->destroy(_swapChain);
    _swapChain = nullptr;
    Log("Swapchain destroyed.");
  }
}

SceneAsset *FilamentViewer::loadGlb(const char *const uri) {
    SceneAsset *asset = _sceneAssetLoader->fromGlb(uri);
  if (!asset) {
    Log("Unknown error loading asset.");
  } else {
    _assets.push_back(asset);
    Log("GLB loaded, asset at index %d", _assets.size() - 1);
  }
  return asset;
}

SceneAsset *FilamentViewer::loadGltf(const char *const uri,
                                     const char *const relativeResourcePath) {
  Log("Loading GLTF at URI %s with relativeResourcePath %s", uri,
      relativeResourcePath);
  SceneAsset *asset = _sceneAssetLoader->fromGltf(uri, relativeResourcePath);
  if (!asset) {
    Log("Unknown error loading asset.");
  } else {
    _assets.push_back(asset);
  }
  return asset;
}


void FilamentViewer::clearAssets() {
  Log("Clearing all assets");
  mtx.lock();
  _view->setCamera(_mainCamera);
  int i = 0;
  for (auto asset : _assets) {
    _sceneAssetLoader->remove(asset);
    Log("Cleared asset %d", i);
    i++;
  }
  _assets.clear();
  mtx.unlock();
}

void FilamentViewer::removeAsset(SceneAsset *asset) {
  mtx.lock();
  // todo - what if we are using a camera from this asset?
  _view->setCamera(_mainCamera);
  _sceneAssetLoader->remove(asset);
  
  bool erased = false;
  for (auto it = _assets.begin(); it != _assets.end();) {
    if (*it == asset) {
      _assets.erase(it);
      erased = true;
      break;
    }
  }
  if (!erased) {
    Log("Error removing asset from scene : not found");
  }
  mtx.unlock();
}

///
/// Sets the active camera to the GLTF camera node specified by [name].
/// N.B. Blender will generally export a three-node hierarchy -
/// Camera1->Camera_Orientation->Camera2. The correct name will be the
/// grandchild (i.e. Camera2 in this scenario).
///
bool FilamentViewer::setCamera(SceneAsset *asset, const char *cameraName) {
  Log("Attempting to set camera to %s.", cameraName);
  size_t count = asset->getCameraEntityCount();
  if (count == 0) {
    Log("Failed, no cameras found in current asset.");
    return false;
  }

  const utils::Entity *cameras = asset->getCameraEntities();
  Log("%zu cameras found in asset", count);
  for (int i = 0; i < count; i++) {

    auto inst = _ncm->getInstance(cameras[i]);
    const char *name = _ncm->getName(inst);
    Log("Camera %d : %s", i, name);
    if (strcmp(name, cameraName) == 0) {

      Camera *camera = _engine->getCameraComponent(cameras[i]);
      _view->setCamera(camera);

      const Viewport &vp = _view->getViewport();
      const double aspect = (double)vp.width / vp.height;

      Log("Camera focal length : %f aspect %f", camera->getFocalLength(),
          aspect);
      camera->setScaling({1.0 / aspect, 1.0});
      Log("Successfully set camera.");
      return true;
    }
  }
  Log("Unable to locate camera under name %s ", cameraName);
  return false;
}

void FilamentViewer::loadSkybox(const char *const skyboxPath) {
  if (!skyboxPath) {
    _scene->setSkybox(nullptr);
  } else {
    ResourceBuffer skyboxBuffer = _loadResource(skyboxPath);

    image::Ktx1Bundle *skyboxBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(skyboxBuffer.data),
                              static_cast<uint32_t>(skyboxBuffer.size));
    _skyboxTexture =
        ktxreader::Ktx1Reader::createTexture(_engine, skyboxBundle, false);
    _skybox =
        filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);

    _scene->setSkybox(_skybox);
    _freeResource(skyboxBuffer);
  }
}

void FilamentViewer::removeSkybox() { _scene->setSkybox(nullptr); }

void FilamentViewer::removeIbl() { _scene->setIndirectLight(nullptr); }

void FilamentViewer::loadIbl(const char *const iblPath) {
  if (!iblPath) {
    _scene->setIndirectLight(nullptr);
  } else {

    Log("Loading IBL from %s", iblPath);

    // Load IBL.
    ResourceBuffer iblBuffer = _loadResource(iblPath);

    image::Ktx1Bundle *iblBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(iblBuffer.data),
                              static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture =
        ktxreader::Ktx1Reader::createTexture(_engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                         .reflections(_iblTexture)
                         .irradiance(3, harmonics)
                         .intensity(30000.0f)
                         .build(*_engine);
    _scene->setIndirectLight(_indirectLight);

    _freeResource(iblBuffer);

    Log("Skybox/IBL load complete.");
  }
}

void FilamentViewer::cleanup() {
  _resourceLoader->asyncCancelLoad();
  _materialProvider->destroyMaterials();
  AssetLoader::destroy(&_assetLoader);
};

void FilamentViewer::render() {

  if (!_view || !_mainCamera || !_swapChain) {
    Log("Not ready for rendering");
    return;
  }

  mtx.lock();
  for (auto &asset : _assets) {
    asset->updateAnimations();
  }

  math::float3 eye, target, upward;
  manipulator->getLookAt(&eye, &target, &upward);
  _mainCamera->lookAt(eye, target, upward);

  // Render the scene, unless the renderer wants to skip the frame.
  if (_renderer->beginFrame(_swapChain)) {
    _renderer->render(_view);
    _renderer->endFrame();
  }
  mtx.unlock();
}

void FilamentViewer::updateViewportAndCameraProjection(
    int width, int height, float contentScaleFactor) {
  if (!_view || !_mainCamera) {
    Log("Skipping camera update, no view or camrea");
    return;
  }

  const uint32_t _width = width * contentScaleFactor;
  const uint32_t _height = height * contentScaleFactor;
  _view->setViewport({0, 0, _width, _height});

  const double aspect = (double)width / height;
  _mainCamera->setLensProjection(_cameraFocalLength, aspect, kNearPlane,
                                 kFarPlane);

  Log("Set viewport to width: %d height:  %d scaleFactor : %f", width, height,
      contentScaleFactor);
}

} // namespace polyvox
