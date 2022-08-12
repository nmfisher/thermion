#include <chrono>
#include "SceneResources.hpp"
#include "SceneAsset.hpp"
#include "Log.hpp"
#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>

#include <filament/TransformManager.h>


using namespace std::chrono;

namespace polyvox {

using namespace std;
using namespace filament;
using namespace filament::gltfio;
using namespace utils;

SceneAsset::SceneAsset(FilamentAsset* asset, Engine* engine, NameComponentManager* ncm)
    : _asset(asset), _engine(engine), _ncm(ncm) {
      _animator = _asset->getAnimator();
  }

SceneAsset::~SceneAsset() { _asset = nullptr; }

void SceneAsset::applyWeights(float *weights, int count) {
  RenderableManager& rm = _engine->getRenderableManager();
  for (size_t i = 0, c = _asset->getEntityCount(); i != c; ++i) {
    auto inst = rm.getInstance(_asset->getEntities()[i]);
    rm.setMorphWeights(inst, weights, count);
  }
}

void SceneAsset::animateWeights(float *data, int numWeights, int numFrames,
                                float frameLengthInMs) {
  Log("Making morph animation buffer with %d weights across %d frames and "
      "frame length %f ms ",
      numWeights, numFrames, frameLengthInMs);
  _morphAnimationBuffer = std::make_unique<MorphAnimationStatus>(
      data, numWeights, numFrames, frameLengthInMs);
}

void SceneAsset::updateAnimations() {
  updateMorphAnimation();
  updateEmbeddedAnimation();
}

void SceneAsset::updateMorphAnimation() {
  if (!_morphAnimationBuffer) {
    return;
  }

  if (_morphAnimationBuffer->frameIndex == -1) {
    _morphAnimationBuffer->frameIndex++;
    _morphAnimationBuffer->startTime = high_resolution_clock::now();
    applyWeights(_morphAnimationBuffer->frameData,
                 _morphAnimationBuffer->numWeights);
  } else {
    duration<double, std::milli> dur =
        high_resolution_clock::now() - _morphAnimationBuffer->startTime;
    int frameIndex =
        static_cast<int>(dur.count() / _morphAnimationBuffer->frameLengthInMs);

    if (frameIndex > _morphAnimationBuffer->numFrames - 1) {
      duration<double, std::milli> dur =
          high_resolution_clock::now() - _morphAnimationBuffer->startTime;
      Log("Morph animation completed in %f ms (%d frames at framerate %f), "
          "final frame was %d",
          dur.count(), _morphAnimationBuffer->numFrames,
          1000 / _morphAnimationBuffer->frameLengthInMs,
          _morphAnimationBuffer->frameIndex);
      _morphAnimationBuffer = nullptr;
    } else if (frameIndex != _morphAnimationBuffer->frameIndex) {
      Log("Rendering frame %d (of a total %d)", frameIndex,
          _morphAnimationBuffer->numFrames);
      _morphAnimationBuffer->frameIndex = frameIndex;
      auto framePtrOffset = frameIndex * _morphAnimationBuffer->numWeights;
      applyWeights(_morphAnimationBuffer->frameData + framePtrOffset,
                   _morphAnimationBuffer->numWeights);
    }
  }
}

void SceneAsset::playAnimation(int index, bool loop) {
  if (index > _animator->getAnimationCount() - 1) {
    Log("Asset does not contain an animation at index %d", index);
  } else {
    _boneAnimationStatus = make_unique<BoneAnimationStatus>(
        index, _animator->getAnimationDuration(index), loop);
  }
}

void SceneAsset::stopAnimation() {
  // TODO - does this need to be threadsafe?
  _boneAnimationStatus = nullptr;
}

void SceneAsset::updateEmbeddedAnimation() {
  if (!_boneAnimationStatus) {
    return;
  }

  duration<double> dur = duration_cast<duration<double>>(
      high_resolution_clock::now() - _boneAnimationStatus->lastTime);
  float startTime = 0;
  if (!_boneAnimationStatus->hasStarted) {
    _boneAnimationStatus->hasStarted = true;
    _boneAnimationStatus->lastTime = high_resolution_clock::now();
  } else if (dur.count() >= _boneAnimationStatus->duration) {
    if (_boneAnimationStatus->loop) {
      _boneAnimationStatus->lastTime = high_resolution_clock::now();
    } else {
      _boneAnimationStatus = nullptr;
      return;
    }
  } else {
    startTime = dur.count();
  }

  _animator->applyAnimation(_boneAnimationStatus->animationIndex, startTime);
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

unique_ptr<vector<string>> SceneAsset::getTargetNames(const char *meshName) {
  if (!_asset) {
    Log("No asset, ignoring call.");
    return nullptr;
  }
  Log("Retrieving morph target names for mesh  %s", meshName);
  unique_ptr<vector<string>> names = make_unique<vector<string>>();
  const Entity *entities = _asset->getEntities();
  RenderableManager &rm = _engine->getRenderableManager();
  for (int i = 0; i < _asset->getEntityCount(); i++) {
    Entity e = entities[i];
    auto inst = _ncm->getInstance(e);
    const char *name = _ncm->getName(inst);
    Log("Got entity instance name %s", name);
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

void SceneAsset::transformToUnitCube()
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

  const utils::Entity* SceneAsset::getCameraEntities() {
    return _asset->getCameraEntities();
  }

  size_t SceneAsset::getCameraEntityCount() {
    return _asset->getCameraEntityCount();
  }

} // namespace polyvox