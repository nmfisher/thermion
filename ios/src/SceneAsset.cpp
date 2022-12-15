#include <iostream>
#include <chrono>

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>

#include <imageio/ImageDecoder.h>

#include "StreamBufferAdapter.hpp"
#include "SceneAsset.hpp"
#include "Log.hpp"
#include "SceneResources.hpp"

using namespace std::chrono;

namespace polyvox {

using namespace std;
using namespace filament;
using namespace filament::gltfio;
using namespace image;
using namespace utils;

SceneAsset::SceneAsset(FilamentAsset *asset, Engine *engine,
                       NameComponentManager *ncm, LoadResource loadResource, FreeResource freeResource)
    : _asset(asset), _engine(engine), _ncm(ncm), _loadResource(loadResource), _freeResource(freeResource) {
  _animator = _asset->getInstance()->getAnimator();
  for (int i = 0; i < _animator->getAnimationCount(); i++) {
    _embeddedAnimationStatus.push_back(
        GLTFAnimation(false,false));
  }
  Log("Created animation buffers for %d", _embeddedAnimationStatus.size());
}

SceneAsset::~SceneAsset() { 
  // most other destructor work is deferred to SceneAssetLoader so we don't need to do anything here
  if(_texture) {
    _engine->destroy(_texture);
    _texture = nullptr;
  }
}

void SceneAsset::setMorphTargetWeights(float *weights, int count) {
  RenderableManager &rm = _engine->getRenderableManager();
  for (size_t i = 0, c = _asset->getEntityCount(); i != c; ++i) {
    auto inst = rm.getInstance(_asset->getEntities()[i]);
    rm.setMorphWeights(inst, weights, count);
  }
}

void SceneAsset::setAnimation(
                float* morphData, 
                int numMorphWeights, 
                float* boneData, 
                const char** boneNames, 
                const char** meshNames, 
                int numBones, 
                int numFrames, 
                float frameLengthInMs) {
  _runtimeAnimationBuffer = std::make_unique<RuntimeAnimation>(
      morphData, 
      numMorphWeights, 
      boneData, 
      boneNames, 
      meshNames,
      numBones, 
      numFrames, 
      frameLengthInMs
    );
}

void SceneAsset::updateAnimations() {
  updateRuntimeAnimation();
  updateEmbeddedAnimations();
}

void SceneAsset::updateRuntimeAnimation() {
  
  if (!_runtimeAnimationBuffer) {
    return;
  }

  if (_runtimeAnimationBuffer->frameIndex == -1) {
    _runtimeAnimationBuffer->startTime = high_resolution_clock::now();
  }  

  duration<double, std::milli> dur =
        high_resolution_clock::now() - _runtimeAnimationBuffer->startTime;
    int frameIndex =
        static_cast<int>(dur.count() / _runtimeAnimationBuffer->mFrameLengthInMs);
    
  // if the animation has finished, return early
  if (frameIndex >= _runtimeAnimationBuffer->mNumFrames) {
    _runtimeAnimationBuffer = nullptr;
    return;
  } 

  if (frameIndex > _runtimeAnimationBuffer->frameIndex) {
    _runtimeAnimationBuffer->frameIndex = frameIndex;
    if(_runtimeAnimationBuffer->mMorphFrameData) {
      auto morphFramePtrOffset = frameIndex * _runtimeAnimationBuffer->mNumMorphWeights;
      setMorphTargetWeights(_runtimeAnimationBuffer->mMorphFrameData + morphFramePtrOffset,
                    _runtimeAnimationBuffer->mNumMorphWeights);
    }

    if(_runtimeAnimationBuffer->mBoneFrameData) {

      for(int i = 0; i < _runtimeAnimationBuffer->mNumBones; i++) {
        auto boneFramePtrOffset = (frameIndex * _runtimeAnimationBuffer->mNumBones * 7) + (i*7);
        const char* boneName = _runtimeAnimationBuffer->mBoneNames[i].c_str();
        const char* meshName = _runtimeAnimationBuffer->mMeshNames[i].c_str();
        float* frame = _runtimeAnimationBuffer->mBoneFrameData + boneFramePtrOffset;

        float transX = frame[0];
        float transY = frame[1];
        float transZ = frame[2];
        float quatX = frame[3];
        float quatY = frame[4];
        float quatZ = frame[5];
        float quatW = frame[6];
        setBoneTransform(boneName, meshName, transX, transY, transZ, quatX, quatY, quatZ, quatW);
      }
    }
  }
}

void SceneAsset::playAnimation(int index, bool loop, bool reverse) {
  if (index > _animator->getAnimationCount() - 1) {
    Log("Asset does not contain an animation at index %d", index);
  } else {
    const char* name = _animator->getAnimationName(index);
    Log("Playing animation %d : %s", index, name);
    if (_embeddedAnimationStatus[index].started) {
      Log("Animation already playing, call stop first.");
    } else {
      Log("Starting animation at index %d with loop : %d and reverse %d ", index, loop, reverse);
      _embeddedAnimationStatus[index].play = true;
      _embeddedAnimationStatus[index].loop = loop;
      _embeddedAnimationStatus[index].reverse = reverse;
    }
  }
}

void SceneAsset::stopAnimation(int index) {
  Log("Stopping animation %d", index);
  // TODO - does this need to be threadsafe?
  _embeddedAnimationStatus[index].play = false;
  _embeddedAnimationStatus[index].started = false;
}

void SceneAsset::loadTexture(const char* resourcePath, int renderableIndex) {

  Log("Loading texture at %s for renderableIndex %d", resourcePath, renderableIndex);

  string rp(resourcePath);

  if(_texture) {
    _engine->destroy(_texture);
    _texture = nullptr;
  }
  
  ResourceBuffer imageResource = _loadResource(rp.c_str());
  
  StreamBufferAdapter sb((char *)imageResource.data, (char *)imageResource.data + imageResource.size);

  istream *inputStream = new std::istream(&sb);

  LinearImage *image = new LinearImage(ImageDecoder::decode(
      *inputStream, rp.c_str(), ImageDecoder::ColorSpace::SRGB));

  if (!image->isValid()) {
    Log("Invalid image : %s", rp.c_str());
    return;
  }

  uint32_t channels = image->getChannels();
  uint32_t w = image->getWidth();
  uint32_t h = image->getHeight();
  _texture = Texture::Builder()
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

  _texture->setImage(*_engine, 0, std::move(buffer));
  setTexture();
  delete inputStream;

  _freeResource(imageResource.id);
  
}

void SceneAsset::setTexture() {
  
  MaterialInstance* const* inst = _asset->getInstance()->getMaterialInstances();
  size_t mic =  _asset->getInstance()->getMaterialInstanceCount();
  Log("Material instance count : %d", mic);
    
  auto sampler = TextureSampler();
  inst[0]->setParameter("baseColorIndex",0);
  inst[0]->setParameter("baseColorMap",_texture,sampler);

}

void SceneAsset::updateEmbeddedAnimations() {
  auto now = high_resolution_clock::now();
  int animationIndex = 0;
  bool playing = false;
  for (auto &status : _embeddedAnimationStatus) {
    if (status.play == false) {
      continue;
    }
    playing = true;

    float animationLength = _animator->getAnimationDuration(animationIndex);
    
    duration<double> elapsed =
        duration_cast<duration<double>>(now - status.startedAt);
    float animationTimeOffset = 0;
    bool finished = false;
    if (!status.started) {

      status.started = true;
      status.startedAt = now;
    } else if (elapsed.count() >= animationLength) {
      if (status.loop) {
        status.startedAt = now;
      } else {
        animationTimeOffset = elapsed.count();
        finished = true;
      }
    } else {
      animationTimeOffset = elapsed.count();
    }

    if(status.reverse) {
      animationTimeOffset = _animator->getAnimationDuration(animationIndex) - animationTimeOffset;
    }

    if (!finished) {
      _animator->applyAnimation(animationIndex, animationTimeOffset);
    } else {
      Log("Animation %d finished", animationIndex);

      status.play = false;
      status.started = false;
    }
    animationIndex++;
  }
  if(playing)
    _animator->updateBoneMatrices();
}

unique_ptr<vector<string>> SceneAsset::getAnimationNames() {
  size_t count = _animator->getAnimationCount();

  Log("Found %d animations in asset.", count);

  unique_ptr<vector<string>> names = make_unique<vector<string>>();

  for (size_t i = 0; i < count; i++) {
    names->push_back(_animator->getAnimationName(i));
  }

  return names;
}

unique_ptr<vector<string>> SceneAsset::getMorphTargetNames(const char *meshName) {
  if (!_asset) {
    Log("No asset, ignoring call.");
    return nullptr;
  }
//  Log("Retrieving morph target names for mesh  %s", meshName);
  unique_ptr<vector<string>> names = make_unique<vector<string>>();
  const Entity *entities = _asset->getEntities();
  
  for (int i = 0; i < _asset->getEntityCount(); i++) {
    Entity e = entities[i];
    auto inst = _ncm->getInstance(e);
    const char *name = _ncm->getName(inst);

    if (strcmp(name, meshName) == 0) {
      size_t count = _asset->getMorphTargetCountAt(e);
      for (int j = 0; j < count; j++) {
        const char *morphName = _asset->getMorphTargetNameAt(e, j);
        names->push_back(morphName);
      }
      break;
    }
  }
  return names;
}

void SceneAsset::transformToUnitCube() {
  if (!_asset) {
    Log("No asset, cannot transform.");
    return;
  }
  Log("Transforming asset to unit cube.");
  auto &tm = _engine->getTransformManager();
  FilamentInstance* inst = _asset->getInstance();
  auto aabb = inst->getBoundingBox();
  auto center = aabb.center();
  auto halfExtent = aabb.extent();
  auto maxExtent = max(halfExtent) * 2;
  auto scaleFactor = 2.0f / maxExtent;
  auto transform =
      math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
  tm.setTransform(tm.getInstance(inst->getRoot()), transform);
}

void SceneAsset::updateTransform() {
  auto &tm = _engine->getTransformManager();
  auto transform = 
      _position * _rotation * math::mat4f::scaling(_scale);
  tm.setTransform(tm.getInstance(_asset->getRoot()), transform);
}

void SceneAsset::setScale(float scale) {
  _scale = scale;
  updateTransform();
}

void SceneAsset::setPosition(float x, float y, float z) {
  Log("Setting position to %f %f %f", x, y, z);
  _position = math::mat4f::translation(math::float3(x,y,z));
  updateTransform();
}

void SceneAsset::setRotation(float rads, float x, float y, float z) {
  Log("Rotating %f radians around axis %f %f %f", rads, x, y, z);
  _rotation = math::mat4f::rotation(rads, math::float3(x,y,z));
  updateTransform();
}

void SceneAsset::setBoneTransform(
  const char* boneName, 
  const char* entityName, 
  float transX, 
  float transY, 
  float transZ, 
  float quatX,
  float quatY,
  float quatZ,
  float quatW) {  

  auto filamentInstance = _asset->getInstance();

  if(filamentInstance->getSkinCount()) { 
    Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
  }

  filamentInstance->getAnimator()->resetBoneMatrices();
  
  int skinIndex = 0;
  const utils::Entity* joints = filamentInstance->getJointsAt(skinIndex);
  size_t numJoints = filamentInstance->getJointCountAt(skinIndex);

  int boneIndex = -1;
  for(int i =0; i < numJoints; i++) {
    const char* jointName = _ncm->getName(_ncm->getInstance(joints[i]));
    if(strcmp(jointName, boneName) == 0) { 
      boneIndex = i;
      Log("Found bone index %d for bone %s", boneIndex, boneName);
      break;
    }
  }
  if(boneIndex == -1) {
    Log("Failed to find bone index %d for bone %s", boneName);
    return;
  }

  RenderableManager &rm = _engine->getRenderableManager();
  
  RenderableManager::Bone transform = {.unitQuaternion={quatX,quatY,quatZ,quatW}, .translation={transX,transY,transZ}};
  
  for(int j = 0; j < _asset->getEntityCount(); j++) {
    Entity e = _asset->getEntities()[j];    
    if(strcmp(entityName,_ncm->getName(_ncm->getInstance(e)))==0) {
      
      Log("Setting bone transform on entity %s", _ncm->getName(_ncm->getInstance(e)));

      auto inst = rm.getInstance(e);
      if(!inst) {
        Log("No renderable instance");  
      }
      rm.setBones(inst, &transform, 1, boneIndex);
    }    
  }
}


const utils::Entity *SceneAsset::getCameraEntities() {
  return _asset->getCameraEntities();
}

size_t SceneAsset::getCameraEntityCount() {
  return _asset->getCameraEntityCount();
}

const Entity* SceneAsset::getLightEntities() const noexcept { 
  return _asset->getLightEntities();
}

size_t SceneAsset::getLightEntityCount() const noexcept {
  return _asset->getLightEntityCount();
}


} // namespace polyvox
