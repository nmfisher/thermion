#include "AssetManager.hpp"
#include "Log.hpp"

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
#include "ResourceManagement.hpp"
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

AssetManager::AssetManager(LoadResource loadResource,
                            FreeResource freeResource,
                            NameComponentManager *ncm, 
                            Engine *engine,
                            Scene *scene)
    : _loadResource(loadResource), 
      _freeResource(freeResource), 
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
  ResourceBuffer rbuf = _loadResource(uri);

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
    ResourceBuffer buf = _loadResource(uri.c_str());

    // using FunctionCallback = std::function<void(void*, unsigned int, void
    // *)>; auto cb = [&] (void * ptr, unsigned int len, void * misc)  {
    // };
    // FunctionCallback fcb = cb;

    ResourceLoader::BufferDescriptor b(buf.data, buf.size);
    _gltfResourceLoader->addResourceData(resourceUris[i], std::move(b));
    _freeResource(buf.id);
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

  _assets.emplace(eid, sceneAsset);

  return eid;
}

EntityId AssetManager::loadGlb(const char *uri, bool unlit) {
  
  Log("Loading GLB at URI %s", uri);
  _loadResource("BLORTY");
  Log("blorty");

  ResourceBuffer rbuf = _loadResource(uri);

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

  _freeResource(rbuf.id);

  SceneAsset sceneAsset(asset);

  utils::Entity e = EntityManager::get().create();
  EntityId eid = Entity::smuggle(e);

  _assets.emplace(eid, sceneAsset);

  return eid;
}

void AssetManager::destroyAll() {
  for (auto kp : _assets) {
    auto asset = kp.second;
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
  const auto& pos = _assets.find(entityId);
  if(pos == _assets.end()) {
    return nullptr;
  }
  return pos->second.mAsset;
}


void AssetManager::updateAnimations() { 
  auto now = high_resolution_clock::now();

  RenderableManager &rm = _engine->getRenderableManager();
  
  for (auto kp : _assets) {
    auto asset = kp.second;
    if(asset.mAnimating) {

      asset.mAnimating = false;
      
      // morph animation
      AnimationStatus morphAnimation = asset.mAnimations[0];
      auto elapsed = (now - morphAnimation.mStart).count();

      int lengthInFrames = static_cast<int>(morphAnimation.mDuration / asset.mMorphAnimationBuffer.mFrameLengthInMs);

      if(elapsed >= morphAnimation.mDuration) {
        if(morphAnimation.mLoop) {
          morphAnimation.mStart = now;
          if(morphAnimation.mReverse) {
            morphAnimation.mFrameNumber = lengthInFrames;
          }
          asset.mAnimating = true;
        } else {
          morphAnimation.mStart = time_point_t::max();
        }
      } else {
        asset.mAnimating = true;
      }
      
      int frameNumber = static_cast<int>(elapsed / asset.mMorphAnimationBuffer.mFrameLengthInMs);
      if(frameNumber < lengthInFrames) {
        if(morphAnimation.mReverse) {
          frameNumber = lengthInFrames - frameNumber;
        } 
        rm.setMorphWeights(
          *(asset.mMorphAnimationBuffer.mInstance),
          asset.mMorphAnimationBuffer.mFrameData.data() + (morphAnimation.mFrameNumber * asset.mMorphAnimationBuffer.mNumMorphWeights),
          asset.mMorphAnimationBuffer.mNumMorphWeights);
      }

      // bone animation
      AnimationStatus boneAnimation = asset.mAnimations[1];
      elapsed = (now - boneAnimation.mStart).count();

      lengthInFrames = static_cast<int>(boneAnimation.mDuration / asset.mBoneAnimationBuffer.mFrameLengthInMs);

      if(elapsed >= boneAnimation.mDuration) {
        if(boneAnimation.mLoop) {
          boneAnimation.mStart = now;
          if(boneAnimation.mReverse) {
            boneAnimation.mFrameNumber = lengthInFrames;
          }
          asset.mAnimating = true;
        } else {
          boneAnimation.mStart = time_point_t::max();
        }
      } else {
        asset.mAnimating = true;
      }

      frameNumber = static_cast<int>(elapsed / asset.mBoneAnimationBuffer.mFrameLengthInMs);
      if(frameNumber < lengthInFrames) {
        if(boneAnimation.mReverse) {
          frameNumber = lengthInFrames - frameNumber;
        } 
        boneAnimation.mFrameNumber = frameNumber;
        setBoneTransform(
          asset.mAsset->getInstance(),
          asset.mBoneAnimationBuffer.mAnimations,
          frameNumber
        );
      }

      // GLTF animations
      
      Animator* animator = asset.mAnimator;
      
      for(int j = 2; j < asset.mAnimations.size(); j++) {
        
        AnimationStatus anim = asset.mAnimations[j];
        
        elapsed = (now - anim.mStart).count();

        if(elapsed < anim.mDuration) {
          if(anim.mLoop) {
            animator->applyAnimation(j-2, anim.mDuration - elapsed);
          } else {
            animator->applyAnimation(j-2, elapsed);
          }
          asset.mAnimating = true;
        } else if(anim.mLoop) {
          animator->applyAnimation(j-2, float(elapsed) ); //% anim.mDuration
          asset.mAnimating = true;
        } else if(elapsed - anim.mDuration < 0.3) { 
          // cross-fade
          animator->applyCrossFade(j-2, anim.mDuration - 0.05, elapsed / 0.3);
          asset.mAnimating = true;
        } else { 
          // stop
          anim.mStart = time_point_t::max();
        }
      }
      asset.mAnimator->updateBoneMatrices();
    }
  }
}

void AssetManager::remove(EntityId entityId) {
  const auto& pos = _assets.find(entityId);
  if(pos == _assets.end()) {
    Log("Couldn't find asset under specified entity id.");
    return;
  }
  auto sceneAsset = pos->second;

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
  _assets.erase(entityId);
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

  const auto& pos = _assets.find(entityId);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return false;
  }
  auto asset = pos->second;

  auto entity = findEntityByName(asset, entityName);
  if(!entity) {
    Log("Warning: failed to find entity %s", entityName);
    return false;
  } 
  RenderableManager &rm = _engine->getRenderableManager();
  auto inst = rm.getInstance(entity);
  
  asset.mMorphAnimationBuffer.mInstance = &inst;
  asset.mMorphAnimationBuffer.mNumFrames = numFrames;
  asset.mMorphAnimationBuffer.mFrameLengthInMs = frameLengthInMs;
  asset.mMorphAnimationBuffer.mFrameData.clear();
  asset.mMorphAnimationBuffer.mFrameData.insert(
    asset.mMorphAnimationBuffer.mFrameData.begin(), 
    morphData,
    morphData + (numFrames * numMorphWeights)
  );

  asset.mMorphAnimationBuffer.mNumMorphWeights = numMorphWeights;
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

  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return false;
  }
  auto asset = pos->second;

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
  const auto& pos = _assets.find(e);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;

  asset.mAnimations[index+2].mStart = high_resolution_clock::now();
  asset.mAnimations[index+2].mLoop = loop;
  asset.mAnimations[index+2].mReverse = reverse;
}

void AssetManager::stopAnimation(EntityId entityId, int index) {
  const auto& pos = _assets.find(entityId);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;
  asset.mAnimations[index+2].mStart = time_point_t::max();
}

void AssetManager::loadTexture(EntityId entity, const char* resourcePath, int renderableIndex) {

  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;

  Log("Loading texture at %s for renderableIndex %d", resourcePath, renderableIndex);

  string rp(resourcePath);

  if(asset.mTexture) {
    _engine->destroy(asset.mTexture);
    asset.mTexture = nullptr;
  }
  
  ResourceBuffer imageResource = _loadResource(rp.c_str());
  
  StreamBufferAdapter sb((char *)imageResource.data, (char *)imageResource.data + imageResource.size);

  istream *inputStream = new std::istream(&sb);

  LinearImage *image = new LinearImage(ImageDecoder::decode(
      *inputStream, rp.c_str(), ImageDecoder::ColorSpace::SRGB));

  if (!image->isValid()) {
    Log("Invalid image : %s", rp.c_str());
    delete inputStream;
    _freeResource(imageResource.id);
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

  _freeResource(imageResource.id);
  
}


void AssetManager::setAnimationFrame(EntityId entity, int animationIndex, int animationFrame) {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;
  auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
  asset.mAnimator->applyAnimation(animationIndex, offset);
  asset.mAnimator->updateBoneMatrices();
}

unique_ptr<vector<string>> AssetManager::getAnimationNames(EntityId entity) {

  const auto& pos = _assets.find(entity);

  unique_ptr<vector<string>> names = make_unique<vector<string>>();

  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity id.");
    return names;
  }
  auto asset = pos->second;

  size_t count = asset.mAnimator->getAnimationCount();


  for (size_t i = 0; i < count; i++) {
    names->push_back(asset.mAnimator->getAnimationName(i));
  }

  return names;
}

unique_ptr<vector<string>> AssetManager::getMorphTargetNames(EntityId entity, const char *meshName) {

  unique_ptr<vector<string>> names = make_unique<vector<string>>();

  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return names;
  }
  auto asset = pos->second;

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
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;

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
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;
  asset.mScale = scale;
  updateTransform(asset);
}

void AssetManager::setPosition(EntityId entity, float x, float y, float z) {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;
  asset.mPosition = math::mat4f::translation(math::float3(x,y,z));
  updateTransform(asset);
}

void AssetManager::setRotation(EntityId entity, float rads, float x, float y, float z) {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return;
  }
  auto asset = pos->second;
  asset.mRotation = math::mat4f::rotation(rads, math::float3(x,y,z));
  updateTransform(asset);
}

const utils::Entity *AssetManager::getCameraEntities(EntityId entity) {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return nullptr;
  }
  auto asset = pos->second;
  return asset.mAsset->getCameraEntities();
}

size_t AssetManager::getCameraEntityCount(EntityId entity) {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return 0;
  }
  auto asset = pos->second;
  return asset.mAsset->getCameraEntityCount();
}

const utils::Entity* AssetManager::getLightEntities(EntityId entity) const noexcept { 
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return nullptr;
  }
  auto asset = pos->second;
  return asset.mAsset->getLightEntities();
}

size_t AssetManager::getLightEntityCount(EntityId entity) const noexcept {
  const auto& pos = _assets.find(entity);
  if(pos == _assets.end()) {
    Log("ERROR: asset not found for entity.");
    return 0;
  }
  auto asset = pos->second;
  return asset.mAsset->getLightEntityCount();
}


} // namespace polyvox
