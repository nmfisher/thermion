#include "AssetManager.hpp"
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
#include <gltfio/math.h>

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

AssetManager::AssetManager(const ResourceLoaderWrapper* const resourceLoaderWrapper,
                           NameComponentManager *ncm,
                           Engine *engine,
                           Scene *scene)
: _resourceLoaderWrapper(resourceLoaderWrapper),
_ncm(ncm),
_engine(engine),
_scene(scene) {
    
    _stbDecoder = createStbProvider(_engine);
    _ktxDecoder = createKtx2Provider(_engine);
    
    _gltfResourceLoader = new ResourceLoader({.engine = _engine,
        .normalizeSkinningWeights = true });
    _ubershaderProvider = gltfio::createUbershaderProvider(
                                                           _engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
    EntityManager &em = EntityManager::get();
    
    //_unlitProvider = new UnlitMaterialProvider(_engine);
    
    // auto rb = _resourceLoaderWrapper->load("file:///mnt/hdd_2tb/home/hydroxide/projects/polyvox/flutter/polyvox_filament/materials/toon.filamat");
    // auto toonProvider = new FileMaterialProvider(_engine, rb.data, (size_t) rb.size);
    
    _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em });
    _gltfResourceLoader->addTextureProvider("image/ktx2", _ktxDecoder);
    _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
    _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);
}

AssetManager::~AssetManager() { 
    _gltfResourceLoader->asyncCancelLoad();
    _ubershaderProvider->destroyMaterials();
    //_unlitProvider->destroyMaterials();
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
    
    const Entity *entities = asset->getEntities();
    
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

bool AssetManager::hide(EntityId entityId, const char* meshName) {
    
    auto asset = getAssetByEntityId(entityId);
    if(!asset) {
        return false;
    }
    
    auto entity = findEntityByName(asset, meshName);
    
    if(entity.isNull()) {
        Log("Mesh %s could not be found", meshName);
        return false;
    }
    _scene->remove(entity);
    return true;
}

bool AssetManager::reveal(EntityId entityId, const char* meshName) {
    auto asset = getAssetByEntityId(entityId);
    if(!asset) {
        Log("No asset found under entity ID");
        return false;
    }
    
    auto entity = findEntityByName(asset, meshName);
    
    RenderableManager &rm = _engine->getRenderableManager();
    
    if(entity.isNull()) {
        Log("Mesh %s could not be found", meshName);
        return false;
    }
    _scene->addEntity(entity);
    return true;
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
        
        vector<AnimationStatus> completed;
        for(auto& anim : asset.mAnimations) {
            
            auto elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - anim.mStart).count()) / 1000.0f;
            
            if(anim.mLoop || elapsed < anim.mDuration) {
                
                switch(anim.type) {
                    case AnimationType::GLTF: {
                        asset.mAnimator->applyAnimation(anim.gltfIndex, elapsed);
                        if(asset.fadeGltfAnimationIndex != -1 && elapsed < asset.fadeDuration) {
                            // cross-fade
                            auto fadeFromTime = asset.fadeOutAnimationStart + elapsed;
                            auto alpha = elapsed / asset.fadeDuration;
                            asset.mAnimator->applyCrossFade(asset.fadeGltfAnimationIndex, fadeFromTime, alpha);
                        }
                        break;
                    }
                    case AnimationType::MORPH: {
                        int lengthInFrames = static_cast<int>(
                                                              anim.mDuration * 1000.0f /
                                                              asset.mMorphAnimationBuffer.mFrameLengthInMs
                                                              );
                        int frameNumber = static_cast<int>(elapsed * 1000.0f / asset.mMorphAnimationBuffer.mFrameLengthInMs) % lengthInFrames;
                        // offset from the end if reverse
                        if(anim.mReverse) {
                            frameNumber = lengthInFrames - frameNumber;
                        }
                        auto baseOffset = frameNumber * asset.mMorphAnimationBuffer.mMorphIndices.size();
                        for(int i = 0; i < asset.mMorphAnimationBuffer.mMorphIndices.size(); i++) {
                            auto morphIndex = asset.mMorphAnimationBuffer.mMorphIndices[i];
                            // set the weights appropriately
                            rm.setMorphWeights(
                                               rm.getInstance(asset.mMorphAnimationBuffer.mMeshTarget),
                                               asset.mMorphAnimationBuffer.mFrameData.data() + baseOffset + i,
                                               1,
                                               morphIndex
                                               );
                        }
                        break;
                    }
                    case AnimationType::BONE: {
                        int lengthInFrames = static_cast<int>(
                                                              anim.mDuration * 1000.0f /
                                                              asset.mBoneAnimationBuffer.mFrameLengthInMs
                                                              );
                        int frameNumber = static_cast<int>(elapsed * 1000.0f / asset.mBoneAnimationBuffer.mFrameLengthInMs) % lengthInFrames;
                        
                        // offset from the end if reverse
                        if(anim.mReverse) {
                            frameNumber = lengthInFrames - frameNumber;
                        }
                        setBoneTransform(
                                         asset,
                                         frameNumber
                                         );
                        break;
                    }
                }
                // animation has completed
            } else {
                completed.push_back(anim);
                asset.fadeGltfAnimationIndex = -1;
            }
            asset.mAnimator->updateBoneMatrices();
        }
    }
}

void AssetManager::setBoneTransform(SceneAsset& asset, int frameNumber) {
    
    RenderableManager& rm = _engine->getRenderableManager();
    
    const auto& filamentInstance = asset.mAsset->getInstance();
    
    TransformManager &transformManager = _engine->getTransformManager();
    
    int skinIndex = 0;
    
    for(int i = 0; i < asset.mBoneAnimationBuffer.mBones.size(); i++) {
        auto mBoneIndex = asset.mBoneAnimationBuffer.mBones[i];
        auto frameDataOffset = (frameNumber * asset.mBoneAnimationBuffer.mBones.size() * 7) + (i * 7);
        
        utils::Entity joint = filamentInstance->getJointsAt(skinIndex)[mBoneIndex];
        if(joint.isNull()) {
            Log("ERROR : joint not found");
            continue;
        }
        
        vector<float>& fd = asset.mBoneAnimationBuffer.mFrameData;
        
        math::mat4f localTransform(math::quatf {
            fd[frameDataOffset+3],
            fd[frameDataOffset+4],
            fd[frameDataOffset+5],
            fd[frameDataOffset+6],
        });
        
        auto jointInstance = transformManager.getInstance(joint);
        
        auto xform = asset.mBoneAnimationBuffer.mBaseTransforms[i];
        
        transformManager.setTransform(jointInstance, xform * localTransform);
        
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
    sceneAsset.mAsset = nullptr; // still need to remove sceneAsset somewhere...
}

void AssetManager::setMorphTargetWeights(EntityId entityId, const char* const entityName, const float* const weights, const int count) {
    const auto& pos = _entityIdLookup.find(entityId);
    if(pos == _entityIdLookup.end()) {
        Log("ERROR: asset not found for entity.");
        return;
    }
    auto& asset = _assets[pos->second];
    
    auto entity = findEntityByName(asset, entityName);
    if(!entity) {
        Log("Warning: failed to find entity %s", entityName);
        return;
    }
    
    RenderableManager &rm = _engine->getRenderableManager();
    
    rm.setMorphWeights(
                       rm.getInstance(entity),
                       weights,
                       count
                       );
}

utils::Entity AssetManager::findEntityByName(SceneAsset asset, const char* entityName) {
    utils::Entity entity;
    for (size_t i = 0, c = asset.mAsset->getEntityCount(); i != c; ++i) {
        auto entity = asset.mAsset->getEntities()[i];
        auto nameInstance = _ncm->getInstance(entity);
        if(!nameInstance.isValid()) {
            continue;
        }
        auto name = _ncm->getName(nameInstance);
        if(!name) {
            continue;
        }
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
                                           const int* const morphIndices,
                                           int numMorphTargets,
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
                                                  morphData + (numFrames * numMorphTargets)
                                                  );
    asset.mMorphAnimationBuffer.mFrameLengthInMs = frameLengthInMs;
    asset.mMorphAnimationBuffer.mMorphIndices.resize(numMorphTargets);
    for(int i =0; i< numMorphTargets; i++) {
        asset.mMorphAnimationBuffer.mMorphIndices[i] = morphIndices[i];
    }
    
    AnimationStatus animation;
    animation.mDuration = (frameLengthInMs * numFrames) / 1000.0f;
    animation.mStart = high_resolution_clock::now();
    animation.type = AnimationType::MORPH;
    asset.mAnimations.push_back(animation);
    return true;
}

bool AssetManager::setMaterialColor(EntityId entityId, const char* meshName, int materialIndex, const float r, const float g, const float b, const float a) {
    
    const auto& pos = _entityIdLookup.find(entityId);
    if(pos == _entityIdLookup.end()) {
        Log("ERROR: asset not found for entity.");
        return false;
    }
    auto& asset = _assets[pos->second];
    auto entity = findEntityByName(asset, meshName);
    
    RenderableManager& rm = _engine->getRenderableManager();
    
    auto renderable = rm.getInstance(entity);
    
    if(!renderable.isValid()) {
        Log("Renderable not valid, was the entity id correct?");

        return false;
    }
    
    MaterialInstance* mi = rm.getMaterialInstanceAt(renderable, materialIndex);
    
    if(!mi) {
        Log("ERROR: material index must be less than number of material instances");
        return false;
    }
    mi->setParameter("baseColorFactor", RgbaType::sRGB, math::float4(r, g, b, a));
    Log("Set baseColorFactor for entity %d to %f %f %f %f",entityId, r,g,b,a);
    return true;
}


bool AssetManager::setBoneAnimationBuffer(
                                          EntityId entityId,
                                          const float* const frameData,
                                          int numFrames,
                                          int numBones,
                                          const char** const boneNames,
                                          const char** const meshNames,
                                          int numMeshTargets,
                                          float frameLengthInMs) {
    
    const auto& pos = _entityIdLookup.find(entityId);
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
    
    TransformManager &transformManager = _engine->getTransformManager();
    
    int skinIndex = 0;
    const utils::Entity* joints = filamentInstance->getJointsAt(skinIndex);
    size_t numJoints = filamentInstance->getJointCountAt(skinIndex);
    
    BoneAnimationBuffer& animationBuffer = asset.mBoneAnimationBuffer;
    
    // if an animation has already been set,  reset the transform for the respective bones
    for(int i = 0; i < animationBuffer.mBones.size(); i++) {
        auto boneIndex = animationBuffer.mBones[i];
        auto jointInstance = transformManager.getInstance(joints[boneIndex]);
        transformManager.setTransform(jointInstance, animationBuffer.mBaseTransforms[i]);
    }
    
    asset.mAnimator->resetBoneMatrices();
    
    animationBuffer.mBones.resize(numBones);
    animationBuffer.mBaseTransforms.resize(numBones);
    
    for(int i = 0; i < numBones; i++) {
        for(int j = 0; j < numJoints; j++) {
            const char* jointName = _ncm->getName(_ncm->getInstance(joints[j]));
            if(strcmp(jointName, boneNames[i]) == 0) {
                auto jointInstance = transformManager.getInstance(joints[j]);
                // auto currentXform = ;
                auto baseTransform = transformManager.getTransform(jointInstance); // inverse(filamentInstance->getInverseBindMatricesAt(skinIndex)[j]);
                animationBuffer.mBaseTransforms[i] = baseTransform;
                animationBuffer.mBones[i] = j;
                break;
            }
        }
    }
    
    if(animationBuffer.mBones.size() != numBones) {
        Log("Failed to find one or more bone indices");
        return false;
    }
    
    animationBuffer.mFrameData.clear();
    // 7 == locX, locY, locZ, rotW, rotX, rotY, rotZ
    animationBuffer.mFrameData.resize(numFrames * numBones * 7);
    animationBuffer.mFrameData.insert(
                                      animationBuffer.mFrameData.begin(),
                                      frameData,
                                      frameData + numFrames * numBones * 7
                                      );
    
    animationBuffer.mFrameLengthInMs = frameLengthInMs;
    animationBuffer.mNumFrames = numFrames;
    
    animationBuffer.mMeshTargets.clear();
    for(int i = 0; i < numMeshTargets; i++) {
        auto entity = findEntityByName(asset, meshNames[i]);
        if(!entity) {
            Log("Mesh target %s for bone animation could not be found", meshNames[i]);
            return false;
        }
        Log("Added mesh target %s", meshNames[i]);
        animationBuffer.mMeshTargets.push_back(entity);
    }
    
    AnimationStatus animation;
    animation.mStart = std::chrono::high_resolution_clock::now();
    animation.mReverse = false;
    animation.mDuration = (frameLengthInMs * numFrames) / 1000.0f;
    animation.type = AnimationType::BONE;
    asset.mAnimations.push_back(animation);
    
    return true;
}


void AssetManager::playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade) {
    if(index < 0) {
        Log("ERROR: glTF animation index must be greater than zero.");
        return;
    }
    const auto& pos = _entityIdLookup.find(e);
    if(pos == _entityIdLookup.end()) {
        Log("ERROR: asset not found for entity.");
        return;
    }
    auto& asset = _assets[pos->second];
    
    if(replaceActive) {
        vector<int> active;
        for(int i = 0; i < asset.mAnimations.size(); i++) {
            if(asset.mAnimations[i].type == AnimationType::GLTF) {
                active.push_back(i);
            }
        }
        if(active.size() > 0) {
            auto& last = asset.mAnimations[active.back()];
            asset.fadeGltfAnimationIndex = last.gltfIndex;
            asset.fadeDuration = crossfade;
            auto now = high_resolution_clock::now();
            auto elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last.mStart).count()) / 1000.0f;
            asset.fadeOutAnimationStart = elapsed;
            for(int j = active.size() - 1; j >= 0; j--) {
                asset.mAnimations.erase(asset.mAnimations.begin() + active[j]);
            }
        } else {
            asset.fadeGltfAnimationIndex = -1;
            asset.fadeDuration = 0.0f;
        }
    } else if(crossfade > 0) {
        Log("ERROR: crossfade only supported when replaceActive is true.");
        return;
    } else {
        asset.fadeGltfAnimationIndex = -1;
        asset.fadeDuration = 0.0f;
    }
    
    AnimationStatus animation;
    animation.gltfIndex = index;
    animation.mStart = std::chrono::high_resolution_clock::now();
    animation.mLoop = loop;
    animation.mReverse = reverse;
    animation.type = AnimationType::GLTF;
    animation.mDuration = asset.mAnimator->getAnimationDuration(index);
    
    asset.mAnimations.push_back(animation);
}

void AssetManager::stopAnimation(EntityId entityId, int index) {
    const auto& pos = _entityIdLookup.find(entityId);
    if(pos == _entityIdLookup.end()) {
        Log("ERROR: asset not found for entity.");
        return;
    }
    auto& asset = _assets[pos->second];
    
    asset.mAnimations.erase(std::remove_if(asset.mAnimations.begin(),
                                           asset.mAnimations.end(),
                                           [=](AnimationStatus& anim) { return anim.gltfIndex == index; }),
                            asset.mAnimations.end());
    
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

float AssetManager::getAnimationDuration(EntityId entity, int animationIndex) {
    const auto& pos = _entityIdLookup.find(entity);
    
    unique_ptr<vector<string>> names = make_unique<vector<string>>();
    
    if(pos == _entityIdLookup.end()) {
        Log("ERROR: asset not found for entity id.");
        return -1.0f;
    }
    
    auto& asset = _assets[pos->second];
    return asset.mAnimator->getAnimationDuration(animationIndex);
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
        
        if (name && strcmp(name, meshName) == 0) {
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

void AssetManager::updateTransform(SceneAsset& asset) {
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


// auto& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(skinIndex)[mBoneIndex];

// auto globalJointTransform = transformManager.getWorldTransform(jointInstance);

// for(auto& target : asset.mBoneAnimationBuffer.mMeshTargets) {

// auto inverseGlobalTransform = inverse(
//   transformManager.getWorldTransform(
//       transformManager.getInstance(target)
//       )
//   );

// auto boneTransform = inverseGlobalTransform * globalJointTransform  * localTransform * inverseBindMatrix;
// auto renderable = rm.getInstance(target);
// rm.setBones(
//       renderable,
//       &boneTransform,
//       1,
//       mBoneIndex
//   );
// }



//   1.0f, 0.0f, 0.0f, 0.0f,
//   0.0f, 0.0f, 1.0f, 0.0f,
//   0.0f, -1.0f, 0.0f, 0.0f,
//   0.0f, 0.0f, 0.0f, 1.0f
// };
// Log("TRANSFORM");
// Log("%f %f %f %f", localTransform[0][0], localTransform[1][0], localTransform[2][0], localTransform[3][0] ) ;
// Log("%f %f %f %f", localTransform[0][1], localTransform[1][1], localTransform[2][1], localTransform[3][1] ) ;
// Log("%f %f %f %f", localTransform[0][2], localTransform[1][2], localTransform[2][2], localTransform[3][2] ) ;
// Log("%f %f %f %f", localTransform[0][3], localTransform[1][3], localTransform[2][3], localTransform[3][3] ) ;
//  transformManager.getTransform(jointInstance);
