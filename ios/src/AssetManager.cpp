#include "AssetManager.hpp"
#include "Log.hpp"
#include <thread>
#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>

#include <imageio/ImageDecoder.h>

#include "StreamBufferAdapter.hpp"
#include "SceneAsset.hpp"
#include "Log.hpp"

#include "material/UnlitMaterialProvider.hpp"
#include "material/FileMaterialProvider.hpp"
#include "gltfio/materials/uberarchive.h"

extern "C" {
  #include "material/image.h"
  #include "material/unlit_opaque.h"
}

namespace polyvox {

using namespace std;
using namespace std::chrono;
using namespace image;
using namespace utils;
using namespace filament;
using namespace filament::gltfio;

AssetManager::AssetManager(ResourceLoaderWrapper* resourceLoaderWrapper,
                            NameComponentManager *ncm, 
                            Engine *engine,
                            Scene *scene)
    : _resourceLoaderWrapper(resourceLoaderWrapper),
      _ncm(ncm),
      _engine(engine), 
      _scene(scene) {

        _stbDecoder = createStbProvider(_engine);

        _gltfResourceLoader = new ResourceLoader({.engine = _engine,
                                        .normalizeSkinningWeights = true });
        _ubershaderProvider = gltfio::createUbershaderProvider(
           _engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
        EntityManager &em = EntityManager::get();
        _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em });
        _unlitProvider = new UnlitMaterialProvider(_engine);
        
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);
      }

AssetManager::~AssetManager() { 
  _gltfResourceLoader->asyncCancelLoad();
  _ubershaderProvider->destroyMaterials();
  _unlitProvider->destroyMaterials();
  destroyAll();
  AssetLoader::destroy(&_assetLoader);
  
}

EntityId AssetManager::loadGltf(const char *uri,
                                       const char *relativeResourcePath) {
  ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

  // Parse the glTF file and create Filament entities.
  FilamentAsset *asset =
      _assetLoader->createAsset((uint8_t *)rbuf.data, rbuf.size);

  if (!asset) {
    Log("Unable to parse asset");
    return 0;
  }

  const char *const *const resourceUris = asset->getResourceUris();
  const size_t resourceUriCount = asset->getResourceUriCount();

  for (size_t i = 0; i < resourceUriCount; i++) {
    string uri =
        string(relativeResourcePath) + string("/") + string(resourceUris[i]);
    ResourceBuffer buf = _resourceLoaderWrapper->load(uri.c_str());

    ResourceLoader::BufferDescriptor b(buf.data, buf.size);
    _gltfResourceLoader->addResourceData(resourceUris[i], std::move(b));
    _resourceLoaderWrapper->free(buf);
  }

  _gltfResourceLoader->loadResources(asset);
  const utils::Entity *entities = asset->getEntities();
  RenderableManager &rm = _engine->getRenderableManager();
  for (int i = 0; i < asset->getEntityCount(); i++) {
    auto inst = rm.getInstance(entities[i]);
    rm.setCulling(inst, false);
  }

  FilamentInstance* inst = asset->getInstance();
  inst->getAnimator()->updateBoneMatrices();
  inst->recomputeBoundingBoxes();

  _scene->addEntities(asset->getEntities(), asset->getEntityCount());

  asset->releaseSourceData();

  Log("Load complete for GLTF at URI %s", uri);
  SceneAsset sceneAsset(asset);
  

  utils::Entity e = EntityManager::get().create();

  EntityId eid = Entity::smuggle(e);

  _entityIdLookup.emplace(eid, _assets.size());
  _assets.push_back(sceneAsset);

  return eid;
}

EntityId AssetManager::loadGlb(const char *uri, bool unlit) {
  
  Log("Loading GLB at URI %s", uri);

  ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

  FilamentAsset *asset = _assetLoader->createAsset(
      (const uint8_t *)rbuf.data, rbuf.size);

  if (!asset) {
    Log("Unknown error loading GLB asset.");
    return 0;
  }

  int entityCount = asset->getEntityCount();

  _scene->addEntities(asset->getEntities(), entityCount);

  _gltfResourceLoader->loadResources(asset);

  // const Entity *entities = asset->getEntities();

  // RenderableManager &rm = _engine->getRenderableManager();

  // MaterialKey config;
  // auto mi_new = _materialProvider->createMaterialInstance(&config, nullptr);
  
  // for (int i = 0; i < asset->getEntityCount(); i++) {
  //   auto entityInstance = rm.getInstance(entities[i]);   
  //   auto mi = rm.getMaterialInstanceAt(entityInstance, 0);
  //   // auto m = mi->getMaterial();
  //   // auto shading = m->getShading();
  //   // Log("Shading %d", shading);
  // }

  auto lights = asset->getLightEntities();
  _scene->addEntities(lights, asset->getLightEntityCount());
  
  FilamentInstance* inst = asset->getInstance();

  inst->getAnimator()->updateBoneMatrices();

  inst->recomputeBoundingBoxes();

  asset->releaseSourceData();

  _resourceLoaderWrapper->free(rbuf);

  SceneAsset sceneAsset(asset);

  utils::Entity e = EntityManager::get().create();
  EntityId eid = Entity::smuggle(e);

  _entityIdLookup.emplace(eid, _assets.size());
  _assets.push_back(sceneAsset);

  return eid;
}

void AssetManager::destroyAll() {
  for (auto& asset : _assets) {
    _scene->removeEntities(asset.mAsset->getEntities(),
                         asset.mAsset->getEntityCount());

    _scene->removeEntities(asset.mAsset->getLightEntities(),
                          asset.mAsset->getLightEntityCount());

    _gltfResourceLoader->evictResourceData();
    _assetLoader->destroyAsset(asset.mAsset);
  }
  _assets.clear();
}

FilamentAsset* AssetManager::getAssetByEntityId(EntityId entityId) {
  const auto& pos = _entityIdLookup.find(entityId);
  if(pos == _entityIdLookup.end()) {
    return nullptr;
  }
  return _assets[pos->second].mAsset;
}


void AssetManager::updateAnimations() { 
  
  auto now = high_resolution_clock::now();

  RenderableManager &rm = _engine->getRenderableManager();
  
  for (auto& asset : _assets) {
    if(!asset.mAnimating) {
      continue;
    }
    asset.mAnimating = false;
    
    // dynamically constructed morph animation
    AnimationStatus& morphAnimation = asset.mAnimations[0];

    if(morphAnimation.mAnimating) {
      
      auto elapsed = float(
        std::chrono::duration_cast<std::chrono::milliseconds>(
          now - morphAnimation.mStart
        ).count()) / 1000.0f;
      int lengthInFrames = static_cast<int>(
        morphAnimation.mDuration * 1000.0f / 
        asset.mMorphAnimationBuffer.mFrameLengthInMs
      );

      // if more time has elapsed than the animation duration && not looping
      // mark the animation as complete
      if(elapsed >= morphAnimation.mDuration && !morphAnimation.mLoop) {
        morphAnimation.mStart = time_point_t::max();
        morphAnimation.mAnimating = false;
      } else {
        
        asset.mAnimating = true;      
        int frameNumber = static_cast<int>(elapsed * 1000.0f / asset.mMorphAnimationBuffer.mFrameLengthInMs) % lengthInFrames;
        // offset from the end if reverse
        if(morphAnimation.mReverse) {
          frameNumber = lengthInFrames - frameNumber;
        } 
        
        Log("setting weights for framenumber %d, elapsed is %f, lengthInFrames is %d, mNumMorphWeights %d", frameNumber, elapsed, lengthInFrames,asset.mMorphAnimationBuffer.mNumMorphWeights );
          // set the weights appropriately
          rm.setMorphWeights(
            rm.getInstance(asset.mMorphAnimationBuffer.mMeshTarget),
            asset.mMorphAnimationBuffer.mFrameData.data() + (frameNumber * asset.mMorphAnimationBuffer.mNumMorphWeights),
            asset.mMorphAnimationBuffer.mNumMorphWeights);
      }
    }

    // // bone animation
    // AnimationStatus boneAnimation = asset.mAnimations[1];
    // elapsed = (now - boneAnimation.mStart).count();

    // lengthInFrames = static_cast<int>(boneAnimation.mDuration / asset.mBoneAnimationBuffer.mFrameLengthInMs);

    // if(elapsed >= boneAnimation.mDuration) {
    //   if(boneAnimation.mLoop) {
    //     boneAnimation.mStart = now;
    //     if(boneAnimation.mReverse) {
    //       boneAnimation.mFrameNumber = lengthInFrames;
    //     }
    //     asset.mAnimating = true;
    //   } else {
    //     boneAnimation.mStart = time_point_t::max();
    //   }
    // } else {
    //   asset.mAnimating = true;
    // }

    // frameNumber = static_cast<int>(elapsed / asset.mBoneAnimationBuffer.mFrameLengthInMs);
    // if(frameNumber < lengthInFrames) {
    //   if(boneAnimation.mReverse) {
    //     frameNumber = lengthInFrames - frameNumber;
    //   } 
    //   boneAnimation.mFrameNumber = frameNumber;
    //   setBoneTransform(
    //     asset.mAsset->getInstance(),
    //     asset.mBoneAnimationBuffer.mAnimations,
    //     frameNumber
    //   );
    // }

    // GLTF animations
    
    int j = -1;
    for(AnimationStatus& anim : asset.mAnimations) {
      j++;
      if(j < 2) {
        continue;
      }

      if(!anim.mAnimating) {
        continue;
      }

      auto elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - anim.mStart).count()) / 1000.0f;

      if(anim.mLoop || elapsed < anim.mDuration) {
        asset.mAnimator->applyAnimation(j-2, elapsed);
        asset.mAnimating = true;
      } else if(elapsed - anim.mDuration < 0.3) { 
        // cross-fade
        // animator->applyCrossFade(j-2, anim.mDuration - 0.05, elapsed / 0.3);
        // asset.mAnimating = true;
        // anim.mStart = time_point_t::max();
      } else { 
        // stop
        anim.mStart = time_point_t::max();
      }
    }
    if(asset.mAnimating) {
      asset.mAnimator->updateBoneMatrices();
    }
  }
}

void AssetManager::remove(EntityId entityId) {
  const auto& pos = _entityIdLookup.find(entityId);
  if(pos == _entityIdLookup.end()) {
    Log("Couldn't find asset under specified entity id.");
    return;
  }
  SceneAsset& sceneAsset = _assets[pos->second];

  _scene->removeEntities(sceneAsset.mAsset->getEntities(),
                        sceneAsset.mAsset->getEntityCount());

  _scene->removeEntities(sceneAsset.mAsset->getLightEntities(),
                        sceneAsset.mAsset->getLightEntityCount());

  _assetLoader->destroyAsset(sceneAsset.mAsset);
  
  if(sceneAsset.mTexture) {
    _engine->destroy(sceneAsset.mTexture);
  }
  EntityManager& em = EntityManager::get();
  em.destroy(Entity::import(entityId));
  sceneAsset.mAsset = nullptr; // still need to remove this somewhere...
}

void AssetManager::setMorphTargetWeights(const char* const entityName, float *weights, int count) {
  // TODO 
}

utils::Entity AssetManager::findEntityByName(SceneAsset asset, const char* entityName) {
  utils::Entity entity;
  for (size_t i = 0, c = asset.mAsset->getEntityCount(); i != c; ++i) {
    auto entity = asset.mAsset->getEntities()[i];    
    auto name = _ncm->getName(_ncm->getInstance(entity));

    if(strcmp(entityName,name)==0) {
      return entity;
    }
  }
  return entity;
}


bool AssetManager::setMorphAnimationBuffer(
    EntityId entityId,
    const char* entityName,
    const float* const morphData,
    int numMorphWeights, 
    int numFrames, 
    float frameLengthInMs) {

  const auto& pos = _entityIdLookup.find(entityId);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return false;
  }
  auto& asset = _assets[pos->second];

  auto entity = findEntityByName(asset, entityName);
  if(!entity) {
    Log("Warning: failed to find entity %s", entityName);
    return false;
  } 

  asset.mMorphAnimationBuffer.mMeshTarget = entity;
  asset.mMorphAnimationBuffer.mFrameData.clear();
  asset.mMorphAnimationBuffer.mFrameData.insert(
    asset.mMorphAnimationBuffer.mFrameData.begin(), 
    morphData,
    morphData + (numFrames * numMorphWeights)
  );
  asset.mMorphAnimationBuffer.mFrameLengthInMs = frameLengthInMs;
  asset.mMorphAnimationBuffer.mNumMorphWeights = numMorphWeights;
  
  AnimationStatus& animation = asset.mAnimations[0];
  animation.mDuration = (frameLengthInMs * numFrames) / 1000.0f;
  animation.mStart = high_resolution_clock::now();
  animation.mAnimating = true;
  asset.mAnimating = true;
  Log("set start to  %d, dur is %f", 
      std::chrono::duration_cast<std::chrono::milliseconds>(animation.mStart.time_since_epoch()).count(), 
      animation.mDuration
  );
  return true;
}

bool AssetManager::setBoneAnimationBuffer(
    EntityId entity,
    int length,
    const char** const boneNames,
    const char** const meshNames,
    const float* const frameData,
    int numFrames, 
    float frameLengthInMs) {

  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return false;
  }
  auto& asset = _assets[pos->second];

  auto filamentInstance = asset.mAsset->getInstance();

  size_t skinCount = filamentInstance->getSkinCount();

  if(skinCount > 1) { 
    Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
  }

  int skinIndex = 0;
  const utils::Entity* joints = filamentInstance->getJointsAt(skinIndex);
  size_t numJoints = filamentInstance->getJointCountAt(skinIndex);
  vector<int> boneIndices;
  for(int i = 0; i < length; i++) {
    for(int j = 0; j < numJoints; j++) {
        const char* jointName = _ncm->getName(_ncm->getInstance(joints[j]));
          if(strcmp(jointName, boneNames[i]) == 0) { 
          boneIndices.push_back(j);
          break;
        }
      }
  }

  if(boneIndices.size() != length) {
    Log("Failed to find one or more bone indices");
    return false;
  }
  
  asset.mBoneAnimationBuffer.mAnimations.clear();

  for(int i = 0; i < length; i++) {
    BoneAnimationData boneAnimationData;
    boneAnimationData.mBoneIndex = boneIndices[i];

    auto entity = findEntityByName(asset, meshNames[i]);

    if(!entity) {
      Log("Mesh target %s for bone animation could not be found", meshNames[i]);
      return false;
    }
    
    boneAnimationData.mMeshTarget = entity;

    boneAnimationData.mFrameData.insert(
      boneAnimationData.mFrameData.begin(), 
      frameData[i * numFrames * 7 * sizeof(float)],  // 7 == x, y, z, w + three euler angles
      frameData[(i+1) * numFrames * 7 * sizeof(float)]
    );

    asset.mBoneAnimationBuffer.mAnimations.push_back(boneAnimationData);
  }
  return true;
}

void AssetManager::setBoneTransform(
  FilamentInstance* filamentInstance,
  vector<BoneAnimationData> animations,
  int frameNumber) {  

  RenderableManager &rm = _engine->getRenderableManager();
  
  TransformManager &transformManager = _engine->getTransformManager();

  auto frameDataOffset = frameNumber * 7;

  int skinIndex = 0;

  for(auto& animation : animations) {
  
    math::mat4f inverseGlobalTransform = inverse(
      transformManager.getWorldTransform(
        transformManager.getInstance(animation.mMeshTarget)
      )
    );

    utils::Entity joint = filamentInstance->getJointsAt(skinIndex)[animation.mBoneIndex];

    math::mat4f localTransform(math::quatf{
      animation.mFrameData[frameDataOffset+6],
      animation.mFrameData[frameDataOffset+3],
      animation.mFrameData[frameDataOffset+4],
      animation.mFrameData[frameDataOffset+5]
    });

    const math::mat4f& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(animation.skinIndex)[animation.mBoneIndex];
    auto jointInstance = transformManager.getInstance(joint);
    math::mat4f globalJointTransform = transformManager.getWorldTransform(jointInstance);
      
    math::mat4f boneTransform = inverseGlobalTransform * globalJointTransform * localTransform * inverseBindMatrix;
    auto renderable = rm.getInstance(animation.mMeshTarget);
    rm.setBones(
      renderable, 
      &boneTransform,
      1, 
      animation.mBoneIndex
    );
  }
}

void AssetManager::playAnimation(EntityId e, int index, bool loop, bool reverse) {
  const auto& pos = _entityIdLookup.find(e);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];

  asset.mAnimations[index+2].mAnimating = true;
  asset.mAnimations[index+2].mStart = std::chrono::high_resolution_clock::now();
  asset.mAnimations[index+2].mLoop = loop;
  asset.mAnimations[index+2].mReverse = reverse;
  // Log("new start %d, dur is %f", std::chrono::duration_cast<std::chrono::milliseconds>(asset.mAnimations[index+2].mStart.time_since_epoch()).count(), asset.mAnimations[index+2].mDuration);
  asset.mAnimating = true;
}

void AssetManager::stopAnimation(EntityId entityId, int index) {
  const auto& pos = _entityIdLookup.find(entityId);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];
  asset.mAnimations[index+2].mStart = time_point_t::max();
}

void AssetManager::loadTexture(EntityId entity, const char* resourcePath, int renderableIndex) {

  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];

  Log("Loading texture at %s for renderableIndex %d", resourcePath, renderableIndex);

  string rp(resourcePath);

  if(asset.mTexture) {
    _engine->destroy(asset.mTexture);
    asset.mTexture = nullptr;
  }
  
  ResourceBuffer imageResource = _resourceLoaderWrapper->load(rp.c_str());
  
  StreamBufferAdapter sb((char *)imageResource.data, (char *)imageResource.data + imageResource.size);

  istream *inputStream = new std::istream(&sb);

  LinearImage *image = new LinearImage(ImageDecoder::decode(
      *inputStream, rp.c_str(), ImageDecoder::ColorSpace::SRGB));

  if (!image->isValid()) {
    Log("Invalid image : %s", rp.c_str());
    delete inputStream;
    _resourceLoaderWrapper->free(imageResource);
    return;
  }

  uint32_t channels = image->getChannels();
  uint32_t w = image->getWidth();
  uint32_t h = image->getHeight();
  asset.mTexture = Texture::Builder()
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

  asset.mTexture->setImage(*_engine, 0, std::move(buffer));
  MaterialInstance* const* inst = asset.mAsset->getInstance()->getMaterialInstances();
  size_t mic =  asset.mAsset->getInstance()->getMaterialInstanceCount();
  Log("Material instance count : %d", mic);
    
  auto sampler = TextureSampler();
  inst[0]->setParameter("baseColorIndex",0);
  inst[0]->setParameter("baseColorMap",asset.mTexture,sampler);
  delete inputStream;

  _resourceLoaderWrapper->free(imageResource);
  
}


void AssetManager::setAnimationFrame(EntityId entity, int animationIndex, int animationFrame) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];
  auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
  asset.mAnimator->applyAnimation(animationIndex, offset);
  asset.mAnimator->updateBoneMatrices();
}

unique_ptr<vector<string>> AssetManager::getAnimationNames(EntityId entity) {

  const auto& pos = _entityIdLookup.find(entity);

  unique_ptr<vector<string>> names = make_unique<vector<string>>();

  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity id.");
    return names;
  }
  auto& asset = _assets[pos->second];

  size_t count = asset.mAnimator->getAnimationCount();


  for (size_t i = 0; i < count; i++) {
    names->push_back(asset.mAnimator->getAnimationName(i));
  }

  return names;
}

unique_ptr<vector<string>> AssetManager::getMorphTargetNames(EntityId entity, const char *meshName) {

  unique_ptr<vector<string>> names = make_unique<vector<string>>();

  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return names;
  }
  auto& asset = _assets[pos->second];

  const utils::Entity *entities = asset.mAsset->getEntities();
  
  for (int i = 0; i < asset.mAsset->getEntityCount(); i++) {
    utils::Entity e = entities[i];
    auto inst = _ncm->getInstance(e);
    const char *name = _ncm->getName(inst);

    if (strcmp(name, meshName) == 0) {
      size_t count = asset.mAsset->getMorphTargetCountAt(e);
      for (int j = 0; j < count; j++) {
        const char *morphName = asset.mAsset->getMorphTargetNameAt(e, j);
        names->push_back(morphName);
      }
      break;
    }
  }
  return names;
}

void AssetManager::transformToUnitCube(EntityId entity) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];

  Log("Transforming asset to unit cube.");
  auto &tm = _engine->getTransformManager();
  FilamentInstance* inst = asset.mAsset->getInstance();
  auto aabb = inst->getBoundingBox();
  auto center = aabb.center();
  auto halfExtent = aabb.extent();
  auto maxExtent = max(halfExtent) * 2;
  auto scaleFactor = 2.0f / maxExtent;
  auto transform =
      math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
  tm.setTransform(tm.getInstance(inst->getRoot()), transform);
}

void AssetManager::updateTransform(SceneAsset asset) {
  auto &tm = _engine->getTransformManager();
  auto transform = 
      asset.mPosition * asset.mRotation * math::mat4f::scaling(asset.mScale);
  tm.setTransform(tm.getInstance(asset.mAsset->getRoot()), transform);
}

void AssetManager::setScale(EntityId entity, float scale) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];
  asset.mScale = scale;
  updateTransform(asset);
}

void AssetManager::setPosition(EntityId entity, float x, float y, float z) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];
  asset.mPosition = math::mat4f::translation(math::float3(x,y,z));
  updateTransform(asset);
}

void AssetManager::setRotation(EntityId entity, float rads, float x, float y, float z) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto& asset = _assets[pos->second];
  asset.mRotation = math::mat4f::rotation(rads, math::float3(x,y,z));
  updateTransform(asset);
}

const utils::Entity *AssetManager::getCameraEntities(EntityId entity) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return nullptr;
  }
  auto& asset = _assets[pos->second];
  return asset.mAsset->getCameraEntities();
}

size_t AssetManager::getCameraEntityCount(EntityId entity) {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return 0;
  }
  auto& asset = _assets[pos->second];
  return asset.mAsset->getCameraEntityCount();
}

const utils::Entity* AssetManager::getLightEntities(EntityId entity) const noexcept { 
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return nullptr;
  }
  auto& asset = _assets[pos->second];
  return asset.mAsset->getLightEntities();
}

size_t AssetManager::getLightEntityCount(EntityId entity) const noexcept {
  const auto& pos = _entityIdLookup.find(entity);
  if(pos == _entityIdLookup.end()) {
    Log("ERROR: asset not found for entity.");
    return 0;
  }
  auto& asset = _assets[pos->second];
  return asset.mAsset->getLightEntityCount();
}


} // namespace polyvox
