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
#include "ResourceManagement.hpp"
#include "SceneAssetAnimation.hpp"

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
                const float* const morphData,
                int numMorphWeights, 
                const BoneAnimation* const boneAnimations,
                int numBoneAnimations,
                int numFrames, 
                float frameLengthInMs) {

  auto filamentInstance = _asset->getInstance();

  size_t skinCount = filamentInstance->getSkinCount();

  if(skinCount > 1) { 
    Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
  }
  
  auto transforms = make_unique<vector<BoneTransformTarget>>();

  auto numFloats = numFrames * 7;

  for(int i = 0; i < numBoneAnimations; i++) {
    
    auto boneIndices = make_unique<vector<uint8_t>>();
    boneIndices->resize(boneAnimations[i].numBones);
    for(int j = 0; j < boneAnimations[i].numBones; j++) {
      boneIndices->at(j) = getBoneIndex(boneAnimations[i].boneNames[j]);
    }

    auto meshTargets = make_unique<vector<Entity>>();
    for(int j = 0; j < _asset->getEntityCount(); j++) {
      for(int k = 0; k < boneAnimations[i].numMeshTargets;k++) {
        auto meshName = boneAnimations[i].meshNames[k];
        auto entity = _asset->getEntities()[j];    
        auto nameInstance = _ncm->getInstance(entity);
        if(strcmp(meshName,_ncm->getName(nameInstance))==0) {
            meshTargets->push_back(entity);
        }
      }
    }

      auto frameData = make_unique<vector<float>>(
        boneAnimations[i].data, 
        boneAnimations[i].data + (numFloats * sizeof(float))
      );

      transforms->push_back(BoneTransformTarget(
          boneIndices,
          meshTargets,
          frameData
      ));
  }
  _runtimeAnimationBuffer = std::make_unique<RuntimeAnimation>(
      morphData, 
      numMorphWeights, 
      transforms, 
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

  if (_runtimeAnimationBuffer->frameNumber == -1) {
    _runtimeAnimationBuffer->startTime = high_resolution_clock::now();
  }  

  duration<double, std::milli> dur =
        high_resolution_clock::now() - _runtimeAnimationBuffer->startTime;
    int frameNumber =
        static_cast<int>(dur.count() / _runtimeAnimationBuffer->mFrameLengthInMs);
    
  // if the animation has finished, return early
  if (frameNumber >= _runtimeAnimationBuffer->mNumFrames) {
    _runtimeAnimationBuffer = nullptr;
    return;
  } 

  if (frameNumber > _runtimeAnimationBuffer->frameNumber) {
    _runtimeAnimationBuffer->frameNumber = frameNumber;
    if(_runtimeAnimationBuffer->mMorphFrameData) {
      auto morphFramePtrOffset = frameNumber * _runtimeAnimationBuffer->mNumMorphWeights;
      setMorphTargetWeights(_runtimeAnimationBuffer->mMorphFrameData + morphFramePtrOffset,
                    _runtimeAnimationBuffer->mNumMorphWeights);
    }

    if(_runtimeAnimationBuffer->mTargets->size() > 0) {
      for(auto& target : *(_runtimeAnimationBuffer->mTargets)) {
        
        setBoneTransform(
          target.skinIndex,
          *(target.mBoneIndices), 
          *(target.mMeshTargets),
          *(target.mBoneData),
          frameNumber
        );
      }
    }
  }
}

size_t SceneAsset::getBoneIndex(const char* name) { 
  
  auto filamentInstance = _asset->getInstance();

  int skinIndex = 0;
  const utils::Entity* joints = filamentInstance->getJointsAt(skinIndex);
  size_t numJoints = filamentInstance->getJointCountAt(skinIndex);

  int boneIndex = -1;
  for(int i =0; i < numJoints; i++) {
    const char* jointName = _ncm->getName(_ncm->getInstance(joints[i]));
    if(strcmp(jointName, name) == 0) { 
      boneIndex = i;
      break;
    }
  }
  if(boneIndex == -1) {
    Log("Failed to find bone index %d for bone %s", name);
  }
  return boneIndex;
}

void SceneAsset::setBoneTransform(
  uint8_t skinIndex,
  const vector<uint8_t>& boneIndices,
  const vector<Entity>& targets, 
  const vector<float> data,
  int frameNumber) {  

  auto filamentInstance = _asset->getInstance();

  RenderableManager &rm = _engine->getRenderableManager();
  TransformManager &transformManager = _engine->getTransformManager();

  auto frameDataOffset = frameNumber * 7;

  for(auto& target : targets) {
  
    auto renderable = rm.getInstance(target);

    math::mat4f inverseGlobalTransform = inverse(
      transformManager.getWorldTransform(
        transformManager.getInstance(target)
      )
    );

    for(auto boneIndex : boneIndices) {

        utils::Entity joint = filamentInstance->getJointsAt(skinIndex)[boneIndex];

        math::mat4f localTransform(math::quatf{
          data[frameDataOffset+6],
          data[frameDataOffset+3],
          data[frameDataOffset+4],
          data[frameDataOffset+5]
        });

        const math::mat4f& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(skinIndex)[boneIndex];
        auto jointInstance = transformManager.getInstance(joint);
        math::mat4f globalJointTransform = transformManager.getWorldTransform(jointInstance);
      
        math::mat4f boneTransform = inverseGlobalTransform * globalJointTransform * localTransform * inverseBindMatrix;
        
        rm.setBones(
        renderable, 
        &boneTransform,
        1, boneIndex);
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
