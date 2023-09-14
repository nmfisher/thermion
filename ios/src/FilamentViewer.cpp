#if __APPLE__
  #include "TargetConditionals.h"
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
#include <backend/DriverEnums.h>
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/IndirectLight.h>

#include <filament/Options.h>

#include <filament/Renderer.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>
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
#include <fstream>

#include <mutex>

#include "Log.hpp"

#include "FilamentViewer.hpp"
#include "StreamBufferAdapter.hpp"
#include "material/image.h"
#include "TimeIt.hpp"

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

// const float kAperture = 1.0f;
// const float kShutterSpeed = 1.0f;
// const float kSensitivity = 50.0f;
struct Vertex {
    filament::math::float2 position;
    uint32_t color;
};

static constexpr float4 sFullScreenTriangleVertices[3] = {
        { -1.0f, -1.0f, 1.0f, 1.0f },
        {  3.0f, -1.0f, 1.0f, 1.0f },
        { -1.0f,  3.0f, 1.0f, 1.0f } };

static const uint16_t sFullScreenTriangleIndices[3] = {0, 1, 2};

FilamentViewer::FilamentViewer(const void* context, const ResourceLoaderWrapper* const resourceLoaderWrapper)
  : _resourceLoaderWrapper(resourceLoaderWrapper) {
  
  #if TARGET_OS_IPHONE
    _engine = Engine::create(Engine::Backend::METAL);
  #else
    _engine = Engine::create(Engine::Backend::OPENGL, nullptr, (void*)context, nullptr);
  #endif

  _renderer = _engine->createRenderer();

  float fr = 60.0f;
  _renderer->setDisplayInfo({.refreshRate = fr});

  Renderer::FrameRateOptions fro;
  fro.interval = 1 / fr;
  _renderer->setFrameRateOptions(fro);

  _scene = _engine->createScene();

  Log("Scene created");
  
  utils::Entity camera = EntityManager::get().create();

  _mainCamera = _engine->createCamera(camera);

  Log("Main camera created");
  _view = _engine->createView();

  setToneMapping(ToneMapping::ACES);

  setBloom(0.6f);

  _view->setScene(_scene);
  _view->setCamera(_mainCamera);

  _cameraFocalLength = 28.0f;
  _mainCamera->setLensProjection(_cameraFocalLength, 1.0f, kNearPlane,
                                 kFarPlane);
  // _mainCamera->setExposure(kAperture, kShutterSpeed, kSensitivity);
  
  const float aperture = _mainCamera->getAperture();
  const float shutterSpeed = _mainCamera->getShutterSpeed();
  const float sens = _mainCamera->getSensitivity();
  // _mainCamera->setExposure(2.0f, 1.0f, 1.0f);

  Log("Camera aperture %f shutter %f sensitivity %f", aperture, shutterSpeed, sens);

  View::DynamicResolutionOptions options;
  options.enabled = false;
  // options.homogeneousScaling = homogeneousScaling;
  // options.minScale = filament::math::float2{ minScale };
  // options.maxScale = filament::math::float2{ maxScale };
  // options.sharpness = sharpness;
  // options.quality = View::QualityLevel::ULTRA;
  _view->setDynamicResolutionOptions(options);

  View::MultiSampleAntiAliasingOptions multiSampleAntiAliasingOptions;
  multiSampleAntiAliasingOptions.enabled = true;

  _view->setMultiSampleAntiAliasingOptions(multiSampleAntiAliasingOptions);

  _view->setAntiAliasing(AntiAliasing::NONE);

  // auto materialRb = _resourceLoader->load("file:///mnt/hdd_2tb/home/hydroxide/projects/filament/unlit.filamat");
  // Log("Loaded resource of size %d", materialRb.size);
  // _materialProvider = new FileMaterialProvider(_engine, (void*) materialRb.data, (size_t)materialRb.size);
  
  EntityManager &em = EntityManager::get();

  _ncm = new NameComponentManager(em);

  _assetManager = new AssetManager(
    _resourceLoaderWrapper, 
    _ncm, 
    _engine,
    _scene);
  
 _imageTexture = Texture::Builder()
                         .width(1)
                         .height(1)
                         .levels(0x01)
                         .format(Texture::InternalFormat::RGB16F)
                         .sampler(Texture::Sampler::SAMPLER_2D)
                         .build(*_engine);
    
  _imageMaterial =
       Material::Builder()
           .package(IMAGE_PACKAGE, IMAGE_IMAGE_SIZE)
           .build(*_engine);
  _imageMaterial->setDefaultParameter("showImage",0);
  _imageMaterial->setDefaultParameter("backgroundColor", RgbaType::sRGB, float4(0.5f, 0.5f, 0.5f, 1.0f));
  _imageMaterial->setDefaultParameter("image", _imageTexture, _imageSampler);
  _imageScale = mat4f { 1.0f , 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f };

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

  utils::Entity imageEntity = em.create();
  RenderableManager::Builder(1)
      .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
      .material(0, _imageMaterial->getDefaultInstance())
      .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, _imageVb,
                _imageIb, 0, 3)
      .culling(false)
      .build(*_engine, imageEntity);
  _imageEntity = &imageEntity;
  _scene->addEntity(imageEntity);
}

void FilamentViewer::setBloom(float strength) {
  decltype(_view->getBloomOptions()) opts;
  opts.enabled = true;
  opts.strength = strength;
  _view->setBloomOptions(opts);
}

void FilamentViewer::setToneMapping(ToneMapping toneMapping) {
  
  ToneMapper* tm;
  switch(toneMapping) {
    case ToneMapping::ACES:
      tm = new ACESToneMapper();
      break;
    case ToneMapping::LINEAR:
      tm = new LinearToneMapper();
      break;
    case ToneMapping::FILMIC:
      tm = new FilmicToneMapper();
      break;
  }

 
 auto newColorGrading = ColorGrading::Builder().toneMapper(tm).build(*_engine);
 _view->setColorGrading(newColorGrading);
 _engine->destroy(colorGrading);
 delete tm;
}

void FilamentViewer::setFrameInterval(float frameInterval) {
  Renderer::FrameRateOptions fro;
  fro.interval = frameInterval;
  _renderer->setFrameRateOptions(fro);
  Log("Set framerate interval to %f", frameInterval);
}

int32_t FilamentViewer::addLight(LightManager::Type t, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) {
  auto light = EntityManager::get().create();
  LightManager::Builder(t)
      .color(Color::cct(colour))
      .intensity(intensity)
      .position(math::float3(posX, posY, posZ))
      .direction(math::float3(dirX, dirY, dirZ))
      .castShadows(shadows)
      .build(*_engine, light);
  _scene->addEntity(light);
  _lights.push_back(light);
  auto entityId = Entity::smuggle(light);
  Log("Added light under entity ID %d of type %d with colour %f intensity %f at (%f, %f, %f) with direction (%f, %f, %f) with shadows %d", entityId, t, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  return entityId;
}

void FilamentViewer::removeLight(EntityId entityId) {
  Log("Removing light with entity ID %d", entityId);
  auto entity = utils::Entity::import(entityId);
  if(entity.isNull()) {
    Log("Error: light entity not found under ID %d", entityId);
  } else {
    auto removed = remove(_lights.begin(), _lights.end(), entity);
    _scene->remove(entity);
    EntityManager::get().destroy(1, &entity);
  }
}

void FilamentViewer::clearLights() {
  Log("Removing all lights");
  _scene->removeEntities(_lights.data(), _lights.size());
  EntityManager::get().destroy(_lights.size(), _lights.data());
  _lights.clear();
}

static bool endsWith(string path, string ending) {
  return path.compare(path.length() - ending.length(), ending.length(), ending) == 0;
}

void FilamentViewer::loadKtx2Texture(string path, ResourceBuffer rb) {

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

void FilamentViewer::loadKtxTexture(string path, ResourceBuffer rb) {
    ktxreader::Ktx1Bundle *bundle =
          new ktxreader::Ktx1Bundle(static_cast<const uint8_t *>(rb.data),
                                static_cast<uint32_t>(rb.size));
    _imageTexture =
          ktxreader::Ktx1Reader::createTexture(_engine, *bundle, false, [](void* userdata) {
          Ktx1Bundle* bundle = (Ktx1Bundle*) userdata;
          delete bundle;
      }, bundle);

    auto info = bundle->getInfo();
    _imageWidth = info.pixelWidth;
    _imageHeight = info.pixelHeight;
}

void FilamentViewer::loadPngTexture(string path, ResourceBuffer rb) {
  
  polyvox::StreamBufferAdapter sb((char *)rb.data, (char *)rb.data + rb.size);

  std::istream inputStream(&sb);

  LinearImage* image = new LinearImage(ImageDecoder::decode(
        inputStream, path.c_str(), ImageDecoder::ColorSpace::SRGB));

  if (!image->isValid()) {
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
                                                            void *data) {
    Log("Deleting LinearImage");
    delete reinterpret_cast<LinearImage*>(data);
  };

  auto pbd = Texture::PixelBufferDescriptor(
     image->getPixelRef(), size_t(_imageWidth * _imageHeight * channels * sizeof(float)),
     channels == 3 ? Texture::Format::RGB : Texture::Format::RGBA,
     Texture::Type::FLOAT, nullptr, freeCallback, image);

  _imageTexture->setImage(*_engine, 0, std::move(pbd));
}

void FilamentViewer::loadTextureFromPath(string path) {
  string ktxExt(".ktx");
  string ktx2Ext(".ktx2");
  string pngExt(".png");

  if (path.length() < 5) {
    Log("Invalid resource path : %s", path.c_str());
    return;
  }

  ResourceBuffer rb = _resourceLoaderWrapper->load(path.c_str());

  if(endsWith(path, ktxExt)) {
    loadKtxTexture(path, rb);
  } else if(endsWith(path, ktx2Ext)) {
    loadKtx2Texture(path, rb);
  } else if(endsWith(path, pngExt)) {
    loadPngTexture(path, rb);
  }

  _resourceLoaderWrapper->free(rb);

}

void FilamentViewer::setBackgroundColor(const float r, const float g, const float b, const float a) {
  _imageMaterial->setDefaultParameter("showImage", 0);
  _imageMaterial->setDefaultParameter("backgroundColor", RgbaType::sRGB, float4(r, g, b, a));
  const Viewport& vp = _view->getViewport();
  _imageMaterial->setDefaultParameter("transform", _imageScale);
}

void FilamentViewer::clearBackgroundImage() {
  _imageMaterial->setDefaultParameter("showImage", 0);
  if (_imageTexture) {
    Log("Destroying existing texture");
    _engine->destroy(_imageTexture);
    Log("Destroyed.");
    _imageTexture = nullptr;
  }
}

void FilamentViewer::setBackgroundImage(const char *resourcePath) {

  string resourcePathString(resourcePath);

  Log("Setting background image to %s", resourcePath);

  clearBackgroundImage();

  loadTextureFromPath(resourcePathString);

  // This currently just anchors the image at the bottom left of the viewport at its original size
  // TODO - implement stretch/etc
  const Viewport& vp = _view->getViewport();
  Log("Image width %d height %d vp width %d height %d", _imageWidth, _imageHeight, vp.width, vp.height);
  _imageScale = mat4f { float(vp.width) / float(_imageWidth) , 0.0f, 0.0f, 0.0f, 0.0f, float(vp.height) / float(_imageHeight), 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f };

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
void FilamentViewer::setBackgroundImagePosition(float x, float y, bool clamp=false) {

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
  if(clamp) {
    Log("Clamping background image translation");
    // first, clamp x/y
    auto xScale = float(_imageWidth) / _view->getViewport().width;
    auto yScale = float(_imageHeight) / _view->getViewport().height;

    float xMin = 0;
    float xMax = 0;
    float yMin = 0;
    float yMax = 0;

    // we need to clamp x so that it can only be translated between (left side touching viewport left) and (right side touching viewport right)
    // if width is less than viewport, these values are 0/1-xScale respectively
    if(xScale < 1) {
      xMin = 0;
      xMax = 1-xScale;  
    // otherwise, these value are (xScale-1 and 1-xScale)
    } else {
      xMin = 1-xScale;
      xMax = 0;
    }

    // do the same for y
    if(yScale < 1) {
      yMin = 0;
      yMax = 1-yScale;  
    } else {
      yMin = 1-yScale;
      yMax = 0;
    }

    x = std::max(xMin, std::min(x,xMax));
    y = std::max(yMin, std::min(y,yMax));
  }

  // these values are then negated to account for the fact that the transform is applied to the UV coordinates, not the vertices (see image.mat).
  // i.e. translating the image right by 0.5 units means translating the UV coordinates left by 0.5 units.
  x = -x;
  y = -y;
  Log("x %f y %f", x, y);

  Log("imageScale %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f ", _imageScale[0][0],_imageScale[0][1],_imageScale[0][2], _imageScale[0][3], \
  _imageScale[1][0],_imageScale[1][1],_imageScale[1][2], _imageScale[1][3],\
  _imageScale[2][0],_imageScale[2][1],_imageScale[2][2], _imageScale[2][3], \
  _imageScale[3][0],_imageScale[3][1],_imageScale[3][2], _imageScale[3][3]);

  auto transform = math::mat4f::translation(math::float3(x, y, 0.0f)) * _imageScale;
  

  Log("transform %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f ", transform[0][0],transform[0][1],transform[0][2], transform[0][3], \
  transform[1][0],transform[1][1],transform[1][2], transform[1][3],\
  transform[2][0],transform[2][1],transform[2][2], transform[2][3], \
  transform[3][0],transform[3][1],transform[3][2], transform[3][3]);
  _imageMaterial->setDefaultParameter("transform", transform);
}

FilamentViewer::~FilamentViewer() { 
  clearAssets();
  delete _assetManager;
  
  for(auto it : _lights) {
    _engine->destroy(it);
  }
  
  _engine->destroyCameraComponent(_mainCamera->getEntity());
  _mainCamera = nullptr;
  _engine->destroy(_view);
  _engine->destroy(_scene);
  _engine->destroy(_renderer);
  _engine->destroy(_swapChain);
  
  Engine::destroy(&_engine); // clears engine*
}

Renderer *FilamentViewer::getRenderer() { return _renderer; }

void FilamentViewer::createSwapChain(const void *surface, uint32_t width, uint32_t height) {
  #if TARGET_OS_IPHONE
    _swapChain = _engine->createSwapChain((void*)surface, filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER);
  #else
    if(surface) {
      _swapChain = _engine->createSwapChain(width, height, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE);
    } else {
      _swapChain = _engine->createSwapChain((void*)surface, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE);
    }
  #endif
  Log("Swapchain created.");
}

void FilamentViewer::createRenderTarget(intptr_t textureId, uint32_t width, uint32_t height) {
  // Create filament textures and render targets (note the color buffer has the import call)
  _rtColor = filament::Texture::Builder()
    .width(width)
    .height(height)
    .levels(1)
    .usage(filament::Texture::Usage::COLOR_ATTACHMENT | filament::Texture::Usage::SAMPLEABLE)
    .format(filament::Texture::InternalFormat::RGBA8)
    .import(textureId)
    .build(*_engine);
  _rtDepth = filament::Texture::Builder()
    .width(width)
    .height(height)
    .levels(1)
    .usage(filament::Texture::Usage::DEPTH_ATTACHMENT)
    .format(filament::Texture::InternalFormat::DEPTH24)
    .build(*_engine);
  _rt = filament::RenderTarget::Builder()
    .texture(RenderTarget::AttachmentPoint::COLOR, _rtColor)
    .texture(RenderTarget::AttachmentPoint::DEPTH, _rtDepth)
    .build(*_engine);

  // Make a specific viewport just for our render target
  _view->setRenderTarget(_rt);
  
  Log("Set render target for glTextureId %u %u x %u", textureId, width, height);

}

void FilamentViewer::destroySwapChain() {
  if(_rt) {
    _view->setRenderTarget(nullptr);
    _engine->destroy(_rtDepth);
    _engine->destroy(_rtColor);
    _engine->destroy(_rt);
    _rt = nullptr;
    _rtDepth = nullptr;
    _rtColor = nullptr;
  }
  if (_swapChain) {
    _engine->destroy(_swapChain);
    _swapChain = nullptr;
    Log("Swapchain destroyed.");
  }
}

void FilamentViewer::clearAssets() {
  Log("Clearing all assets");
  if(_mainCamera) {
    _view->setCamera(_mainCamera);
  }

  _assetManager->destroyAll();
 
  Log("Cleared all assets");
}

void FilamentViewer::removeAsset(EntityId asset) {
  Log("Removing asset from scene");

  mtx.lock();
  // todo - what if we are using a camera from this asset?
  _view->setCamera(_mainCamera);
  _assetManager->remove(asset);
  mtx.unlock();
}

/// 
/// Set the exposure for the current active camera.
///
void FilamentViewer::setCameraExposure(float aperture, float shutterSpeed, float sensitivity) {
  Camera& cam =_view->getCamera();
  Log("Setting aperture (%03f) shutterSpeed (%03f) and sensitivity (%03f)", aperture, shutterSpeed, sensitivity);
  cam.setExposure(aperture, shutterSpeed, sensitivity);
}

///
/// Set the focal length of the active camera.
///
void FilamentViewer::setCameraFocalLength(float focalLength) {
  Camera& cam =_view->getCamera();
  _cameraFocalLength = focalLength;
  cam.setLensProjection(_cameraFocalLength, 1.0f, kNearPlane,
                                 kFarPlane);                            
}

///
/// Set the focus distance of the active camera.
///
void FilamentViewer::setCameraFocusDistance(float focusDistance) {
  Camera& cam =_view->getCamera();
  _cameraFocusDistance = focusDistance;
  cam.setFocusDistance(_cameraFocusDistance);                           
}

///
/// Sets the active camera to the GLTF camera node specified by [name] (or if null, the first camera found under that node).
/// N.B. Blender will generally export a three-node hierarchy -
/// Camera1->Camera_Orientation->Camera2. The correct name will be the Camera_Orientation.
///
bool FilamentViewer::setCamera(EntityId entityId, const char *cameraName) {

    auto asset = _assetManager->getAssetByEntityId(entityId);
    if(!asset) {
        Log("Failed to find asset attached to specified entity id.");
    }
    size_t count = asset->getCameraEntityCount();
    if (count == 0) {
        Log("Failed, no cameras found in current asset.");
        return false;
    }

    const utils::Entity* cameras = asset->getCameraEntities();

    utils::Entity target;

    if(!cameraName) {
        auto inst = _ncm->getInstance(cameras[0]);
        const char *name = _ncm->getName(inst);
        target = cameras[0];
        Log("No camera specified, using first : %s", name);
    } else {
        for (int j = 0; j < count; j++) {
            auto inst = _ncm->getInstance(cameras[j]);
            const char *name = _ncm->getName(inst);
            if (strcmp(name, cameraName) == 0) {
                target = cameras[j];
                break;
            }
        }
    }
    if(target.isNull()) {
      Log("Unable to locate camera under name %s ", cameraName);
      return false;
    }

    Camera *camera = _engine->getCameraComponent(target);
    if(!camera) {
        Log("Failed to retrieve camera component for target");
    }
    _view->setCamera(camera);

    const Viewport &vp = _view->getViewport();
    const double aspect = (double)vp.width / vp.height;

    // const float aperture = camera->getAperture();
    // const float shutterSpeed = camera->getShutterSpeed();
    // const float sens = camera->getSensitivity();
    // camera->setExposure(1.0f);

    camera->setScaling({1.0 / aspect, 1.0});
    return true;
}

void FilamentViewer::loadSkybox(const char *const skyboxPath) {
  Log("Loading skybox from %s", skyboxPath);

  removeSkybox();
 
  if (skyboxPath) {
    ResourceBuffer skyboxBuffer = _resourceLoaderWrapper->load(skyboxPath);

    if(skyboxBuffer.size <= 0) {
      Log("Could not load skybox resource.");
      return;
    }
    
    image::Ktx1Bundle *skyboxBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(skyboxBuffer.data),
                              static_cast<uint32_t>(skyboxBuffer.size));

    _skyboxTexture =
        ktxreader::Ktx1Reader::createTexture(_engine, *skyboxBundle, false, [](void* userdata) {
        image::Ktx1Bundle* bundle = (image::Ktx1Bundle*) userdata;
        delete bundle;
    }, skyboxBundle);
    _skybox =
        filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);

    _scene->setSkybox(_skybox);
    _resourceLoaderWrapper->free(skyboxBuffer);
  }
}

void FilamentViewer::removeSkybox() { 
  Log("Removing skybox");
  if(_skybox) {

    _engine->destroy(_skybox);
    _engine->destroy(_skyboxTexture);
    _skybox = nullptr;
    _skyboxTexture = nullptr;
  } 
  _scene->setSkybox(nullptr); 
}

void FilamentViewer::removeIbl() { 
  if(_indirectLight) {
    _engine->destroy(_indirectLight);
    _engine->destroy(_iblTexture);
    _indirectLight = nullptr;
    _iblTexture = nullptr;
  }
  _scene->setIndirectLight(nullptr); 
}

void FilamentViewer::loadIbl(const char *const iblPath, float intensity) {
  removeIbl();
  if (iblPath) {
    Log("Loading IBL from %s", iblPath);

    // Load IBL.
    ResourceBuffer iblBuffer = _resourceLoaderWrapper->load(iblPath);

    if(iblBuffer.size == 0) {
      Log("Error loading IBL, resource could not be loaded.");
      return;
    }

    image::Ktx1Bundle *iblBundle =
        new image::Ktx1Bundle(static_cast<const uint8_t *>(iblBuffer.data),
                              static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture =
        ktxreader::Ktx1Reader::createTexture(_engine, *iblBundle, false, [](void* userdata) {
        image::Ktx1Bundle* bundle = (image::Ktx1Bundle*) userdata;
        delete bundle;
    }, iblBundle);
    _indirectLight = IndirectLight::Builder()
                         .reflections(_iblTexture)
                         .irradiance(3, harmonics)
                         .intensity(intensity)
                         .build(*_engine);
    _scene->setIndirectLight(_indirectLight);

    _resourceLoaderWrapper->free(iblBuffer);

    Log("Skybox/IBL load complete.");
  }
}

double _elapsed = 0;
int _frameCount = 0;

void FilamentViewer::render(uint64_t frameTimeInNanos) {

  if (!_view || !_mainCamera || !_swapChain) {
    Log("Not ready for rendering");
    return;
  }

  if(_frameCount == 60) {
    // Log("1 sec average for asset animation update %f", _elapsed / 60);
    _elapsed = 0;
    _frameCount = 0;
  }

  Timer tmr;

  _assetManager->updateAnimations();

  _elapsed += tmr.elapsed();
  _frameCount++;

  // Render the scene, unless the renderer wants to skip the frame.
  if (_renderer->beginFrame(_swapChain, frameTimeInNanos)) {
    _renderer->render(_view);
    _renderer->endFrame();
  } else {
    // skipped frame
  }
  
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

  Camera& cam =_view->getCamera();
  cam.setLensProjection(_cameraFocalLength, 1.0f, kNearPlane,
                                 kFarPlane);

  cam.setScaling({1.0 / aspect, 1.0});

  Log("Set viewport to width: %d height: %d aspect %f scaleFactor : %f", width, height, aspect,
      contentScaleFactor);
}

void FilamentViewer::setCameraPosition(float x, float y, float z) {
  Camera& cam =_view->getCamera();

  _cameraPosition = math::mat4f::translation(math::float3(x,y,z));
  cam.setModelMatrix(_cameraPosition * _cameraRotation);
}

void FilamentViewer::setCameraRotation(float rads, float x, float y, float z) {
  Camera& cam =_view->getCamera();

  _cameraRotation = math::mat4f::rotation(rads, math::float3(x,y,z));
  cam.setModelMatrix(_cameraPosition * _cameraRotation);
}

void FilamentViewer::setCameraModelMatrix(const float* const matrix) {
  Camera& cam =_view->getCamera();

  mat4 modelMatrix(
    matrix[0],
   matrix[1],
   matrix[2],
   matrix[3],
   matrix[4],
   matrix[5],
   matrix[6],
   matrix[7],
   matrix[8],
   matrix[9],
   matrix[10],
   matrix[11],
   matrix[12],
   matrix[13],
   matrix[14],
   matrix[15]
);
  cam.setModelMatrix(modelMatrix);
}

void FilamentViewer::grabBegin(float x, float y, bool pan) {
  if (!_view || !_mainCamera || !_swapChain) {
    Log("View not ready, ignoring grab");
    return;
  }
  _panning = pan;
  _startX = x;
  _startY = y;
}

void FilamentViewer::grabUpdate(float x, float y) {
    if (!_view || !_swapChain) {
        Log("View not ready, ignoring grab");
        return;
    }
    Camera& cam =_view->getCamera();
    auto eye =  cam.getPosition();// math::float3  {0.0f, 0.5f, 50.0f } ;// ; //
    auto target = eye + cam.getForwardVector();
    auto upward = cam.getUpVector();
    Viewport const& vp = _view->getViewport();
    if(_panning) {
        auto trans = cam.getModelMatrix() * mat4::translation(math::float3 { 10 * (x - _startX) / vp.width, 10 * (y - _startY) / vp.height, 0.0f });
        cam.setModelMatrix(trans);
    } else {
        auto trans = cam.getModelMatrix() * mat4::rotation(
                                                   
                                                          0.01,
//                                                           math::float3 { 0.0f, 1.0f, 0.0f });
                                                           math::float3 { (y - _startY) / vp.height, (x - _startX) / vp.width, 0.0f });
        cam.setModelMatrix(trans);
    }
    _startX = x;
    _startY = y;

}

void FilamentViewer::grabEnd() {
  if (!_view || !_mainCamera || !_swapChain) {
    Log("View not ready, ignoring grab");
    return;
  }
}

void FilamentViewer::scrollBegin() {
  // noop
}

void FilamentViewer::scrollUpdate(float x, float y, float delta) {
    Camera& cam =_view->getCamera();
    Viewport const& vp = _view->getViewport();
    auto trans = cam.getModelMatrix() * mat4::translation(math::float3 {0.0f, 0.0f, delta });
    cam.setModelMatrix(trans);
}

void FilamentViewer::scrollEnd() {
  
}

} // namespace polyvox

  
