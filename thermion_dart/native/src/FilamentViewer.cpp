#if __APPLE__
#include "TargetConditionals.h"
#endif

#ifdef _WIN32
#pragma comment(lib, "Ws2_32.lib")
#endif

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
#include <filament/SwapChain.h>
#include <backend/DriverEnums.h>
#include <backend/platforms/OpenGLPlatform.h>
#ifdef __EMSCRIPTEN__
#include <backend/platforms/PlatformWebGL.h>
#include <emscripten/emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#endif
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndexBuffer.h>
#include <filament/IndirectLight.h>

#include <filament/Options.h>

#include <filament/Renderer.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <filament/RenderableManager.h>
#include <filament/LightManager.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>

#include <gltfio/materials/uberarchive.h>

#include <utils/NameComponentManager.h>

#include <imageio/ImageDecoder.h>
#include <imageio/ImageEncoder.h>
#include <image/ColorTransform.h>

#include "math.h"

#include <math/mat4.h>
#include <math/TVecHelpers.h>

#include <math/quat.h>
#include <math/scalar.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <ktxreader/Ktx1Reader.h>
#include <ktxreader/Ktx2Reader.h>

#include <iostream>
#include <streambuf>
#include <sstream>
#include <istream>
#include <fstream>
#include <filesystem>
#include <mutex>
#include <iomanip>
#include <unordered_set>

#include "Log.hpp"

#include "FilamentViewer.hpp"
#include "StreamBufferAdapter.hpp"
#include "material/image.h"
#include "TimeIt.hpp"
#include "UnprojectTexture.hpp"

namespace filament
{
  class IndirectLight;
  class LightManager;
} // namespace filament

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace gltfio;
  using namespace utils;
  using namespace image;
  using namespace std::chrono;

  using std::string;

  static constexpr filament::math::float4 sFullScreenTriangleVertices[3] = {
      {-1.0f, -1.0f, 1.0f, 1.0f},
      {3.0f, -1.0f, 1.0f, 1.0f},
      {-1.0f, 3.0f, 1.0f, 1.0f}};

  static const uint16_t sFullScreenTriangleIndices[3] = {0, 1, 2};

  FilamentViewer::FilamentViewer(const void *sharedContext, const ResourceLoaderWrapperImpl *const resourceLoader, void *const platform, const char *uberArchivePath)
      : _resourceLoaderWrapper(resourceLoader)
  {
    _context = (void *)sharedContext;
    ASSERT_POSTCONDITION(_resourceLoaderWrapper != nullptr, "Resource loader must be non-null");

#if TARGET_OS_IPHONE
    ASSERT_POSTCONDITION(platform == nullptr, "Custom Platform not supported on iOS");
    _engine = Engine::create(Engine::Backend::METAL);
#elif TARGET_OS_OSX
    ASSERT_POSTCONDITION(platform == nullptr, "Custom Platform not supported on macOS");
    _engine = Engine::create(Engine::Backend::METAL);
#elif defined(__EMSCRIPTEN__)
    _engine = Engine::create(Engine::Backend::OPENGL, (backend::Platform *)new filament::backend::PlatformWebGL(), (void *)sharedContext, nullptr);
#elif defined(_WIN32)
    Engine::Config config;
    config.stereoscopicEyeCount = 1;
    _engine = Engine::create(Engine::Backend::OPENGL, (backend::Platform *)platform, (void *)sharedContext, &config);
#else
    _engine = Engine::create(Engine::Backend::OPENGL, (backend::Platform *)platform, (void *)sharedContext, nullptr);
#endif

    _engine->setAutomaticInstancingEnabled(true);

    _renderer = _engine->createRenderer();

    Renderer::ClearOptions clearOptions;
    clearOptions.clear = true;
    _renderer->setClearOptions(clearOptions);

    _frameInterval = 1000.0f / 60.0f;

    setFrameInterval(_frameInterval);

    _scene = _engine->createScene();

    utils::Entity camera = EntityManager::get().create();

    _mainCamera = _engine->createCamera(camera);

    createView();

    setRenderable(_views[0], true);

    const float aperture = _mainCamera->getAperture();
    const float shutterSpeed = _mainCamera->getShutterSpeed();
    const float sens = _mainCamera->getSensitivity();

    EntityManager &em = EntityManager::get();

    _sceneManager = new SceneManager(
        _resourceLoaderWrapper,
        _engine,
        _scene,
        uberArchivePath,
        _mainCamera);
  }

  void FilamentViewer::setFrameInterval(float frameInterval)
  {
    _frameInterval = frameInterval;
    Renderer::FrameRateOptions fro;
    fro.interval = 1; // frameInterval;
    fro.history = 5;
    _renderer->setFrameRateOptions(fro);
  }

  EntityId FilamentViewer::addLight(
      LightManager::Type t,
      float colour,
      float intensity,
      float posX,
      float posY,
      float posZ,
      float dirX,
      float dirY,
      float dirZ,
      float falloffRadius,
      float spotLightConeInner,
      float spotLightConeOuter,
      float sunAngularRadius,
      float sunHaloSize,
      float sunHaloFallof,
      bool shadows)
  {
    auto light = EntityManager::get().create();

    auto result = LightManager::Builder(t)
                      .color(Color::cct(colour))
                      .intensity(intensity)
                      .falloff(falloffRadius)
                      .spotLightCone(spotLightConeInner, spotLightConeOuter)
                      .sunAngularRadius(sunAngularRadius)
                      .sunHaloSize(sunHaloSize)
                      .sunHaloFalloff(sunHaloFallof)
                      .position(filament::math::float3(posX, posY, posZ))
                      .direction(filament::math::float3(dirX, dirY, dirZ))
                      .castShadows(shadows)
                      .build(*_engine, light);
    if (result != LightManager::Builder::Result::Success)
    {
      Log("ERROR : failed to create light");
    }
    else
    {
      _scene->addEntity(light);
      _lights.push_back(light);
    }

    return Entity::smuggle(light);
  }

  void FilamentViewer::setLightPosition(EntityId entityId, float x, float y, float z)
  {
    auto light = Entity::import(entityId);

    if (light.isNull())
    {
      Log("Light not found for entity %d", entityId);
      return;
    }

    auto &lm = _engine->getLightManager();

    auto instance = lm.getInstance(light);

    lm.setPosition(instance, filament::math::float3{x, y, z});
  }

  void FilamentViewer::setLightDirection(EntityId entityId, float x, float y, float z)
  {
    auto light = Entity::import(entityId);

    if (light.isNull())
    {
      Log("Light not found for entity %d", entityId);
      return;
    }

    auto &lm = _engine->getLightManager();

    auto instance = lm.getInstance(light);

    lm.setDirection(instance, filament::math::float3{x, y, z});
  }

  void FilamentViewer::removeLight(EntityId entityId)
  {
    auto entity = utils::Entity::import(entityId);
    if (entity.isNull())
    {
      Log("Error: light entity not found under ID %d", entityId);
    }
    else
    {
      auto removed = remove(_lights.begin(), _lights.end(), entity);
      _scene->remove(entity);
      EntityManager::get().destroy(1, &entity);
    }
  }

  void FilamentViewer::clearLights()
  {
    _scene->removeEntities(_lights.data(), _lights.size());
    EntityManager::get().destroy(_lights.size(), _lights.data());
    _lights.clear();
  }

  static bool endsWith(std::string path, std::string ending)
  {
    return path.compare(path.length() - ending.length(), ending.length(), ending) == 0;
  }

  void FilamentViewer::loadKtx2Texture(string path, ResourceBuffer rb)
  {

    // TODO - check all this

    // ktxreader::Ktx2Reader reader(*_engine);

    // reader.requestFormat(Texture::InternalFormat::DXT3_SRGBA);
    // reader.requestFormat(Texture::InternalFormat::DXT3_RGBA);

    // // Uncompressed formats are lower priority, so they get added last.
    // reader.requestFormat(Texture::InternalFormat::SRGB8_A8);
    // reader.requestFormat(Texture::InternalFormat::RGBA8);

    // // std::ifstream inputStream("/data/data/app.polyvox.filament_example/foo.ktx", ios::binary);

    // // auto contents = vector<uint8_t>((istreambuf_iterator<char>(inputStream)), {});

    // _imageTexture = reader.load(contents.data(), contents.size(),
    //           ktxreader::Ktx2Reader::TransferFunction::LINEAR);
  }

  void FilamentViewer::loadKtxTexture(string path, ResourceBuffer rb)
  {
    ktxreader::Ktx1Bundle *bundle =
        new ktxreader::Ktx1Bundle(static_cast<const uint8_t *>(rb.data),
                                  static_cast<uint32_t>(rb.size));

    // the ResourceBuffer will go out of scope before the texture callback is invoked
    // make a copy to the heap
    ResourceBuffer *rbCopy = new ResourceBuffer(rb);

    std::vector<void *> *callbackData = new std::vector<void *>{(void *)_resourceLoaderWrapper, rbCopy};

    _imageTexture =
        ktxreader::Ktx1Reader::createTexture(
            _engine, *bundle, false, [](void *userdata)
            {
          std::vector<void*>* vec = (std::vector<void*>*)userdata;
          ResourceLoaderWrapperImpl* loader = (ResourceLoaderWrapperImpl*)vec->at(0);
          ResourceBuffer* rb = (ResourceBuffer*) vec->at(1);
          loader->free(*rb);
          delete rb;
          delete vec; },
            callbackData);

    auto info = bundle->getInfo();
    _imageWidth = info.pixelWidth;
    _imageHeight = info.pixelHeight;
  }

  void FilamentViewer::loadPngTexture(string path, ResourceBuffer rb)
  {

    thermion::StreamBufferAdapter sb((char *)rb.data, (char *)rb.data + rb.size);

    std::istream inputStream(&sb);

    LinearImage *image = new LinearImage(ImageDecoder::decode(
        inputStream, path.c_str(), ImageDecoder::ColorSpace::SRGB));

    if (!image->isValid())
    {
      Log("Invalid image : %s", path.c_str());
      return;
    }

    uint32_t channels = image->getChannels();
    _imageWidth = image->getWidth();
    _imageHeight = image->getHeight();

    _imageTexture = Texture::Builder()
                        .width(_imageWidth)
                        .height(_imageHeight)
                        .levels(0x01)
                        .format(channels == 3 ? Texture::InternalFormat::RGB16F
                                              : Texture::InternalFormat::RGBA16F)
                        .sampler(Texture::Sampler::SAMPLER_2D)
                        .build(*_engine);

    Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
                                                               void *data)
    {
      delete reinterpret_cast<LinearImage *>(data);
    };

    auto pbd = Texture::PixelBufferDescriptor(
        image->getPixelRef(), size_t(_imageWidth * _imageHeight * channels * sizeof(float)),
        channels == 3 ? Texture::Format::RGB : Texture::Format::RGBA,
        Texture::Type::FLOAT, nullptr, freeCallback, image);

    _imageTexture->setImage(*_engine, 0, std::move(pbd));

    // don't need to free the ResourceBuffer in the texture callback
    // LinearImage takes a copy
    _resourceLoaderWrapper->free(rb);
  }

  void FilamentViewer::loadTextureFromPath(string path)
  {
    std::string ktxExt(".ktx");
    string ktx2Ext(".ktx2");
    string pngExt(".png");

    if (path.length() < 5)
    {
      Log("Invalid resource path : %s", path.c_str());
      return;
    }

    ResourceBuffer rb = _resourceLoaderWrapper->load(path.c_str());

    if (endsWith(path, ktxExt))
    {
      loadKtxTexture(path, rb);
    }
    else if (endsWith(path, ktx2Ext))
    {
      loadKtx2Texture(path, rb);
    }
    else if (endsWith(path, pngExt))
    {
      loadPngTexture(path, rb);
    }
  }

  void FilamentViewer::setBackgroundColor(const float r, const float g, const float b, const float a)
  {
    std::lock_guard lock(_imageMutex);

    if (_imageEntity.isNull())
    {
      createBackgroundImage();
    }
    _imageMaterial->setDefaultParameter("showImage", 0);
    _imageMaterial->setDefaultParameter("backgroundColor", RgbaType::sRGB, filament::math::float4(r, g, b, a));
    _imageMaterial->setDefaultParameter("transform", _imageScale);
  }

  void FilamentViewer::createBackgroundImage()
  {

    _dummyImageTexture = Texture::Builder()
                             .width(1)
                             .height(1)
                             .levels(0x01)
                             .format(Texture::InternalFormat::RGB16F)
                             .sampler(Texture::Sampler::SAMPLER_2D)
                             .build(*_engine);
    try
    {
      _imageMaterial =
          Material::Builder()
              .package(IMAGE_IMAGE_DATA, IMAGE_IMAGE_SIZE)
              .build(*_engine);
      _imageMaterial->setDefaultParameter("showImage", 0);
      _imageMaterial->setDefaultParameter("backgroundColor", RgbaType::sRGB, filament::math::float4(1.0f, 1.0f, 1.0f, 0.0f));
      _imageMaterial->setDefaultParameter("image", _dummyImageTexture, _imageSampler);
    }
    catch (...)
    {
      Log("Failed to load background image material provider");
      std::rethrow_exception(std::current_exception());
    }
    _imageScale = mat4f{1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f};

    _imageMaterial->setDefaultParameter("transform", _imageScale);

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
    auto &em = EntityManager::get();
    _imageEntity = em.create();
    RenderableManager::Builder(1)
        .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
        .material(0, _imageMaterial->getDefaultInstance())
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, _imageVb,
                  _imageIb, 0, 3)
        .layerMask(0xFF, 1u << SceneManager::LAYERS::BACKGROUND)
        .culling(false)
        .build(*_engine, _imageEntity);
    _scene->addEntity(_imageEntity);
  }

  void FilamentViewer::clearBackgroundImage()
  {
    std::lock_guard lock(_imageMutex);

    if (_imageEntity.isNull())
    {
      createBackgroundImage();
    }
    _imageMaterial->setDefaultParameter("image", _dummyImageTexture, _imageSampler);
    _imageMaterial->setDefaultParameter("showImage", 0);
    if (_imageTexture)
    {
      _engine->destroy(_imageTexture);
      _imageTexture = nullptr;
    }
  }

  void FilamentViewer::setBackgroundImage(const char *resourcePath, bool fillHeight, uint32_t width, uint32_t height)
  {

    std::lock_guard lock(_imageMutex);

    if (_imageEntity.isNull())
    {
      createBackgroundImage();
    }

    string resourcePathString(resourcePath);

    loadTextureFromPath(resourcePathString);

    // This currently just anchors the image at the bottom left of the viewport at its original size
    // TODO - implement stretch/etc
    float xScale = float(width) / float(_imageWidth);

    float yScale;
    if (fillHeight)
    {
      yScale = 1.0f;
    }
    else
    {
      yScale = float(height) / float(_imageHeight);
    }

    _imageScale = mat4f{xScale, 0.0f, 0.0f, 0.0f, 0.0f, yScale, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f};

    _imageMaterial->setDefaultParameter("transform", _imageScale);
    _imageMaterial->setDefaultParameter("image", _imageTexture, _imageSampler);
    _imageMaterial->setDefaultParameter("showImage", 1);
  }

  ///
  /// Translates the background image by (x,y) pixels.
  /// If clamp is true, x/y are both clamped so that the left/top and right/bottom sides of the background image
  /// are positioned at a max/min of -1/1 respectively
  /// (i.e. you cannot set a position where the left/top or right/bottom sides would be "inside" the screen coordinate space).
  ///
  void FilamentViewer::setBackgroundImagePosition(float x, float y, bool clamp = false, uint32_t width = 0, uint32_t height = 0)
  {
    std::lock_guard lock(_imageMutex);

    if (_imageEntity.isNull())
    {
      createBackgroundImage();
    }

    // to translate the background image, we apply a transform to the UV coordinates of the quad texture, not the quad itself (see image.mat).
    // this allows us to set a background colour for the quad when the texture has been translated outside the quad's bounds.
    // so we need to munge the coordinates appropriately (and take into consideration the scale transform applied when the image was loaded).

    // first, convert x/y to a percentage of the original image size
    x /= _imageWidth;
    y /= _imageHeight;

    // now scale these by the viewport dimensions so they can be incorporated directly into the UV transform matrix.
    // x *= _imageScale[0][0];
    // y *= _imageScale[1][1];

    // TODO - I haven't updated the clamp calculations to work with scaled image width/height percentages so the below code is probably wrong, don't use it until it's fixed.
    if (clamp)
    {
      Log("Clamping background image translation");
      // first, clamp x/y
      auto xScale = float(_imageWidth) / width;
      auto yScale = float(_imageHeight) / height;

      float xMin = 0;
      float xMax = 0;
      float yMin = 0;
      float yMax = 0;

      // we need to clamp x so that it can only be translated between (left side touching viewport left) and (right side touching viewport right)
      // if width is less than viewport, these values are 0/1-xScale respectively
      if (xScale < 1)
      {
        xMin = 0;
        xMax = 1 - xScale;
        // otherwise, these value are (xScale-1 and 1-xScale)
      }
      else
      {
        xMin = 1 - xScale;
        xMax = 0;
      }

      // do the same for y
      if (yScale < 1)
      {
        yMin = 0;
        yMax = 1 - yScale;
      }
      else
      {
        yMin = 1 - yScale;
        yMax = 0;
      }

      x = std::max(xMin, std::min(x, xMax));
      y = std::max(yMin, std::min(y, yMax));
    }

    // these values are then negated to account for the fact that the transform is applied to the UV coordinates, not the vertices (see image.mat).
    // i.e. translating the image right by 0.5 units means translating the UV coordinates left by 0.5 units.
    x = -x;
    y = -y;

    auto transform = math::mat4f::translation(filament::math::float3(x, y, 0.0f)) * _imageScale;

    _imageMaterial->setDefaultParameter("transform", transform);
  }

  FilamentViewer::~FilamentViewer()
  {
    clearLights();

    for (auto view : _views)
    {
      _engine->destroy(view);
    }

    _views.clear();

    for (auto swapChain : _swapChains)
    {
      _engine->destroy(swapChain);
    }

    _swapChains.clear();

    if (!_imageEntity.isNull())
    {
      _engine->destroy(_imageEntity);
      _engine->destroy(_imageTexture);
      _engine->destroy(_imageVb);
      _engine->destroy(_imageIb);
      _engine->destroy(_imageMaterial);
    }
    delete _sceneManager;
    _engine->destroyCameraComponent(_mainCamera->getEntity());
    _mainCamera = nullptr;
    _engine->destroy(_scene);
    _engine->destroy(_renderer);
    Engine::destroy(&_engine);
    delete _resourceLoaderWrapper;
  }

  Renderer *FilamentViewer::getRenderer() { return _renderer; }

  SwapChain *FilamentViewer::createSwapChain(const void *window, uint32_t width, uint32_t height)
  {
    std::lock_guard lock(_renderMutex);
    SwapChain *swapChain;
    if (window)
    {
      swapChain = _engine->createSwapChain((void *)window, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE);
      Log("Created window swapchain.");
    }
    else
    {
      Log("Created headless swapchain %dx%d.", width, height);
      swapChain = _engine->createSwapChain(width, height, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE | filament::SwapChain::CONFIG_HAS_STENCIL_BUFFER);
    }
    _swapChains.push_back(swapChain);
    return swapChain;
  }

  RenderTarget *FilamentViewer::createRenderTarget(intptr_t texture, uint32_t width, uint32_t height)
  {
    Log("Creating render target with size %d x %d", width, height);
    // Create filament textures and render targets (note the color buffer has the import call)
    auto rtColor = filament::Texture::Builder()
                       .width(width)
                       .height(height)
                       .levels(1)
                       .usage(filament::Texture::Usage::COLOR_ATTACHMENT | filament::Texture::Usage::SAMPLEABLE)
                       .format(filament::Texture::InternalFormat::RGBA8)
                       .import(texture)
                       .build(*_engine);
    auto rtDepth = filament::Texture::Builder()
                       .width(width)
                       .height(height)
                       .levels(1)
                       .usage(filament::Texture::Usage::DEPTH_ATTACHMENT | filament::Texture::Usage::SAMPLEABLE)
                       .format(filament::Texture::InternalFormat::DEPTH32F)
                       .build(*_engine);
    auto rt = filament::RenderTarget::Builder()
                  .texture(RenderTarget::AttachmentPoint::COLOR, rtColor)
                  .texture(RenderTarget::AttachmentPoint::DEPTH, rtDepth)
                  .build(*_engine);
    _renderTargets.push_back(rt);
    return rt;
  }

  void FilamentViewer::destroyRenderTarget(RenderTarget *renderTarget)
  {
    std::lock_guard lock(_renderMutex);
    auto rtDepth = renderTarget->getTexture(RenderTarget::AttachmentPoint::DEPTH);
    if (rtDepth)
    {
      _engine->destroy(rtDepth);
    }
    auto rtColor = renderTarget->getTexture(RenderTarget::AttachmentPoint::COLOR);
    if (rtColor)
    {
      _engine->destroy(rtColor);
    }
    _engine->destroy(renderTarget);
    auto it = std::find(_renderTargets.begin(), _renderTargets.end(), renderTarget);
    if (it != _renderTargets.end())
    {
      _renderTargets.erase(it);
    }
  }

  void FilamentViewer::destroySwapChain(SwapChain *swapChain)
  {
    std::lock_guard lock(_renderMutex);
    auto it = std::find(_swapChains.begin(), _swapChains.end(), swapChain);
    if (it != _swapChains.end())
    {
      _swapChains.erase(it);
    }
    _engine->destroy(swapChain);
    Log("Swapchain destroyed.");
#ifdef __EMSCRIPTEN__
    _engine->execute();
#else
    _engine->flushAndWait();
#endif
  }

  ///
  ///
  ///
  View *FilamentViewer::createView()
  {
    auto *view = _engine->createView();
    view->setLayerEnabled(SceneManager::LAYERS::DEFAULT_ASSETS, true);
    view->setLayerEnabled(SceneManager::LAYERS::BACKGROUND, true); // skybox + image
    view->setLayerEnabled(SceneManager::LAYERS::OVERLAY, false);   // world grid + gizmo
    view->setBlendMode(filament::View::BlendMode::TRANSLUCENT);
    view->setStencilBufferEnabled(true);
    view->setAmbientOcclusionOptions({.enabled = false});
    view->setDynamicResolutionOptions({.enabled = false});
#if defined(_WIN32)
    view->setStereoscopicOptions({.enabled = true});
#endif

    // there's a glitch on certain iGPUs where nothing will render when postprocessing is enabled and bloom is disabled
    // set bloom to a small value here
    view->setBloomOptions({.strength = 0.01});
    view->setDithering(filament::Dithering::NONE);
    view->setShadowingEnabled(false);
    view->setScreenSpaceRefractionEnabled(false);
    view->setPostProcessingEnabled(false);
    view->setScene(_scene);
    view->setCamera(_mainCamera);

    _views.push_back(view);
    return view;
  }

  ///
  ///
  ///
  View *FilamentViewer::getViewAt(int32_t index)
  {
    Log("Getting view at %d", index);
    if (index < _views.size())
    {
      return _views[index];
    }
    return nullptr;
  }

  /// @brief
  ///
  ///
  void FilamentViewer::clearEntities()
  {
    _sceneManager->destroyAll();
  }

  /// @brief 
  /// @param asset 
  ///
  void FilamentViewer::removeEntity(EntityId asset)
  {
    _renderMutex.lock();
    // todo - what if we are using a camera from this asset?
    _sceneManager->remove(asset);
    _renderMutex.unlock();
  }

  ///
  ///
  ///
  void FilamentViewer::setMainCamera(View *view)
  {
    view->setCamera(_mainCamera);
  }

  ///
  ///
  ///
  EntityId FilamentViewer::getMainCamera()
  {
    return Entity::smuggle(_mainCamera->getEntity());
  }

  void FilamentViewer::loadSkybox(const char *const skyboxPath)
  {

    removeSkybox();

    if (!skyboxPath)
    {
      Log("No skybox path provided, removed skybox.");
    }

    Log("Loading skybox from path %s", skyboxPath);
    ResourceBuffer skyboxBuffer = _resourceLoaderWrapper->load(skyboxPath);

    // because this will go out of scope before the texture callback is invoked, we need to make a copy of the variable itself (not its contents)
    ResourceBuffer *skyboxBufferCopy = new ResourceBuffer(skyboxBuffer);

    if (skyboxBuffer.size <= 0)
    {
      Log("Could not load skybox resource.");
      return;
    }

    Log("Loaded skybox data of length %d", skyboxBuffer.size);

    std::vector<void *> *callbackData = new std::vector<void *>{(void *)_resourceLoaderWrapper, skyboxBufferCopy};

    image::Ktx1Bundle *skyboxBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(skyboxBuffer.data),
                              static_cast<uint32_t>(skyboxBuffer.size));

    _skyboxTexture =
        ktxreader::Ktx1Reader::createTexture(
            _engine, *skyboxBundle, false, [](void *userdata)
            {
                std::vector<void*>* vec = (std::vector<void*>*)userdata;
                ResourceLoaderWrapperImpl* loader = (ResourceLoaderWrapperImpl*)vec->at(0);
                ResourceBuffer* rb = (ResourceBuffer*) vec->at(1);
                loader->free(*rb);
                delete rb;
                delete vec; },
            callbackData);
    _skybox =
        filament::Skybox::Builder()
            .environment(_skyboxTexture)
            .build(*_engine);

    _skybox->setLayerMask(0xFF, 1u << SceneManager::LAYERS::BACKGROUND);

    _scene->setSkybox(_skybox);
  }

  void FilamentViewer::removeSkybox()
  {
    _scene->setSkybox(nullptr);
    if (_skybox)
    {
      _engine->destroy(_skybox);
      _skybox = nullptr;
    }
    if (_skyboxTexture)
    {
      _engine->destroy(_skyboxTexture);
      _skyboxTexture = nullptr;
    }
  }

  void FilamentViewer::removeIbl()
  {
    if (_indirectLight)
    {
      _engine->destroy(_indirectLight);
      _engine->destroy(_iblTexture);
      _indirectLight = nullptr;
      _iblTexture = nullptr;
    }
    _scene->setIndirectLight(nullptr);
  }

  void FilamentViewer::rotateIbl(const math::mat3f &matrix)
  {
    _indirectLight->setRotation(matrix);
  }

  void FilamentViewer::createIbl(float r, float g, float b, float intensity)
  {
    if (_indirectLight)
    {
      removeIbl();
    }

    _iblTexture = Texture::Builder()
                      .width(1)
                      .height(1)
                      .levels(0x01)
                      .format(Texture::InternalFormat::RGB16F)
                      .sampler(Texture::Sampler::SAMPLER_CUBEMAP)

                      .build(*_engine);
    // Create a copy of the cubemap data
    float *pixelData = new float[18]{
        r,
        g,
        b,
        r,
        g,
        b,
        r,
        g,
        b,
        r,
        g,
        b,
        r,
        g,
        b,
        r,
        g,
        b,
    };

    Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t, void *data)
    {
      delete[] reinterpret_cast<float *>(data);
    };

    auto pbd = Texture::PixelBufferDescriptor(
        pixelData,
        18 * sizeof(float),
        Texture::Format::RGB,
        Texture::Type::FLOAT,
        freeCallback,
        pixelData);

    _iblTexture->setImage(*_engine, 0, std::move(pbd));

    _indirectLight = IndirectLight::Builder()
                         .reflections(_iblTexture)
                         .intensity(intensity)
                         .build(*_engine);

    _scene->setIndirectLight(_indirectLight);
  }

  void FilamentViewer::loadIbl(const char *const iblPath, float intensity)
  {
    removeIbl();
    if (iblPath)
    {
      // Load IBL.
      ResourceBuffer iblBuffer = _resourceLoaderWrapper->load(iblPath);
      // because this will go out of scope before the texture callback is invoked, we need to make a copy to the heap
      ResourceBuffer *iblBufferCopy = new ResourceBuffer(iblBuffer);

      if (iblBuffer.size == 0)
      {
        Log("Error loading IBL, resource could not be loaded.");
        return;
      }

      image::Ktx1Bundle *iblBundle =
          new image::Ktx1Bundle(static_cast<const uint8_t *>(iblBuffer.data),
                                static_cast<uint32_t>(iblBuffer.size));
      filament::math::float3 harmonics[9];
      iblBundle->getSphericalHarmonics(harmonics);

      std::vector<void *> *callbackData = new std::vector<void *>{(void *)_resourceLoaderWrapper, iblBufferCopy};

      _iblTexture =
          ktxreader::Ktx1Reader::createTexture(
              _engine, *iblBundle, false, [](void *userdata)
              {
            std::vector<void*>* vec = (std::vector<void*>*)userdata;
            ResourceLoaderWrapperImpl* loader = (ResourceLoaderWrapperImpl*)vec->at(0);
            ResourceBuffer* rb = (ResourceBuffer*) vec->at(1);
            loader->free(*rb);
            delete rb;
            delete vec; },
              callbackData);
      _indirectLight = IndirectLight::Builder()
                           .reflections(_iblTexture)
                           .irradiance(3, harmonics)
                           .intensity(intensity)
                           .build(*_engine);
      _scene->setIndirectLight(_indirectLight);

      Log("IBL loaded.");
    }
  }

  bool FilamentViewer::render(
      uint64_t frameTimeInNanos,
      SwapChain *swapChain,
      void *pixelBuffer,
      void (*callback)(void *buf, size_t size, void *data),
      void *data)
  {

    if (!swapChain)
    {
      return false;
    }

    auto now = std::chrono::high_resolution_clock::now();
    auto secsSinceLastFpsCheck = float(std::chrono::duration_cast<std::chrono::seconds>(now - _fpsCounterStartTime).count());

    if (secsSinceLastFpsCheck >= 1)
    {
      auto fps = _frameCount / secsSinceLastFpsCheck;
      _frameCount = 0;
      _skippedFrames = 0;
      _fpsCounterStartTime = now;
    }

    Timer tmr;

    _sceneManager->updateTransforms();
    _sceneManager->updateAnimations();

    _cumulativeAnimationUpdateTime += tmr.elapsed();

    // Render the scene, unless the renderer wants to skip the frame.
    bool beginFrame = _renderer->beginFrame(swapChain, frameTimeInNanos);
    if (!beginFrame)
    {
      _skippedFrames++;
    } else  {
      for(auto *view : _renderable) {
        _renderer->render(view);
      }
      _frameCount++;
      _renderer->endFrame();
    }
#ifdef __EMSCRIPTEN__
    _engine->execute();
#endif
    return beginFrame;
  }

  class CaptureCallbackHandler : public filament::backend::CallbackHandler
  {
    void post(void *user, Callback callback)
    {
      callback(user);
    }
  };

  void FilamentViewer::capture(View *view, uint8_t *out, bool useFence, SwapChain *swapChain, void (*onComplete)())
  {

    if (!swapChain)
    {
      Log("NO SWAPCHAIN");
      return;
    }

    Viewport const &vp = view->getViewport();
    size_t pixelBufferSize = vp.width * vp.height * 4;
    auto *pixelBuffer = new uint8_t[pixelBufferSize];
    auto callback = [](void *buf, size_t size, void *data)
    {
      auto frameCallbackData = (std::vector<void *> *)data;
      uint8_t *out = (uint8_t *)(frameCallbackData->at(0));
      void *callbackPtr = frameCallbackData->at(1);

      memcpy(out, buf, size);
      delete frameCallbackData;
      if (callbackPtr)
      {
        void (*callback)(void) = (void (*)(void))callbackPtr;
        callback();
      }
    };

    // Create a fence
    Fence *fence = nullptr;
    if (useFence)
    {
      fence = _engine->createFence();
    }

    auto userData = new std::vector<void *>{out, (void *)onComplete};

    auto dispatcher = new CaptureCallbackHandler();

    auto pbd = Texture::PixelBufferDescriptor(
        pixelBuffer, pixelBufferSize,
        Texture::Format::RGBA,
        Texture::Type::UBYTE, dispatcher, callback, userData);
    _renderer->beginFrame(swapChain, 0);
    _renderer->render(view);
    _renderer->readPixels(0, 0, vp.width, vp.height, std::move(pbd));
    _renderer->endFrame();

#ifdef __EMSCRIPTEN__
    _engine->execute();
    emscripten_webgl_commit_frame();
#endif
    if (fence)
    {
      Fence::waitAndDestroy(fence);
    }
  }

  void FilamentViewer::capture(View *view, uint8_t *out, bool useFence, SwapChain *swapChain, RenderTarget *renderTarget, void (*onComplete)())
  {

    if (!(renderTarget || swapChain)) {
      Log("NO RENDER TARGET OR SWAPCHAIN");
      return;
    }

    if(swapChain && !_engine->isValid(swapChain)) {
      Log("SWAPCHAIN PROVIDED BUT NOT VALID");
      return;
    }

    int i =0 ;
    for(auto sc : _swapChains) {
      if(sc == swapChain) {
        Log("Using swapchain at index %d", i);
      }
      i++;
    }

    Viewport const &vp = view->getViewport();
    size_t pixelBufferSize = vp.width * vp.height * 4;
    auto *pixelBuffer = new uint8_t[pixelBufferSize];
    auto callback = [](void *buf, size_t size, void *data)
    {
      auto frameCallbackData = (std::vector<void *> *)data;
      uint8_t *out = (uint8_t *)(frameCallbackData->at(0));
      void *callbackPtr = frameCallbackData->at(1);

      memcpy(out, buf, size);
      delete frameCallbackData;
      if (callbackPtr)
      {
        void (*callback)(void) = (void (*)(void))callbackPtr;
        callback();
      }
    };

    // Create a fence
    Fence *fence = nullptr;
    if (useFence)
    {
      fence = _engine->createFence();
    }

    auto userData = new std::vector<void *>{out, (void *)onComplete};

    auto dispatcher = new CaptureCallbackHandler();

    auto pbd = Texture::PixelBufferDescriptor(
        pixelBuffer, pixelBufferSize,
        Texture::Format::RGBA,
        Texture::Type::UBYTE, dispatcher, callback, userData);
    _renderer->beginFrame(swapChain, 0);
    _renderer->render(view);
    _renderer->readPixels(renderTarget, 0, 0, vp.width, vp.height, std::move(pbd));
    _renderer->endFrame();

#ifdef __EMSCRIPTEN__
    _engine->execute();
    emscripten_webgl_commit_frame();
#endif
    if (fence)
    {
      Fence::waitAndDestroy(fence);
    }
  }

  Camera *FilamentViewer::getCamera(EntityId entity)
  {
    return _engine->getCameraComponent(Entity::import(entity));
  }

  void FilamentViewer::pick(View *view, uint32_t x, uint32_t y, void (*callback)(EntityId entityId, int x, int y))
  {

    view->pick(x, y, [=](filament::View::PickingQueryResult const &result) { 

      if(_sceneManager->isGizmoEntity(result.renderable)) {
        Log("Gizmo entity, ignoring");
        return;
      }
      std::unordered_set<Entity, Entity::Hasher> nonPickableEntities = {
        _imageEntity,
        _sceneManager->_gridOverlay->sphere(),
        _sceneManager->_gridOverlay->grid(),
      };

      if (nonPickableEntities.find(result.renderable) == nonPickableEntities.end()) {
        callback(Entity::smuggle(result.renderable), x, y);
      } });
  }

  void FilamentViewer::unprojectTexture(EntityId entityId, uint8_t *input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight)
  {
    const auto *geometry = _sceneManager->getGeometry(entityId);
    if (!geometry->uvs)
    {
      Log("No UVS");
      return;
    }

    // UnprojectTexture unproject(geometry, _view->getCamera(), _engine);

    // TODO - check that input dimensions match viewport?

    // unproject.unproject(utils::Entity::import(entityId), input, out, inputWidth, inputHeight, outWidth, outHeight);
  }

} // namespace thermion
