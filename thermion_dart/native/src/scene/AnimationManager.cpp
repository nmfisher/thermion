#include <memory>
#include <stack>
#include <unordered_set>
#include <vector>

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/RenderableManager.h>

#include <gltfio/Animator.h>

#include <utils/Panic.h>

#include "Log.hpp"

#include "scene/AnimationManager.hpp"

#include "components/GltfAnimationComponentManager.hpp"
#include "components/MorphAnimationComponentManager.hpp"
#include "components/BoneAnimationComponentManager.hpp"

#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAssetInstance.hpp"

namespace thermion
{

    using namespace filament;
    using namespace utils;

    AnimationManager::AnimationManager(Engine *engine) : mEngine(engine)
    {
        auto &transformManager = mEngine->getTransformManager();
        auto &renderableManager = mEngine->getRenderableManager();
        auto &em = EntityManager::get();
        mGltfAnimationComponentManager = std::make_unique<GltfAnimationComponentManager>(em, transformManager, renderableManager);
        mMorphAnimationComponentManager = std::make_unique<MorphAnimationComponentManager>(em, transformManager, renderableManager);
        mBoneAnimationComponentManager = std::make_unique<BoneAnimationComponentManager>(em, transformManager, renderableManager);
    }

    AnimationManager::~AnimationManager()
    {
    }

    bool AnimationManager::setMorphAnimationBuffer(
        utils::Entity entity,
        const float *const morphData,
        const uint32_t *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {

        std::lock_guard lock(mMutex);

        if (!mMorphAnimationComponentManager->hasComponent(entity))
        {
            mMorphAnimationComponentManager->addAnimationComponent(entity);
        }

        auto animationComponentInstance = mMorphAnimationComponentManager->getInstance(entity);
        auto &animationComponent = mMorphAnimationComponentManager->elementAt<0>(animationComponentInstance);
        auto &morphAnimations = animationComponent.animations;

        MorphAnimation morphAnimation;

        morphAnimation.frameData.clear();
        morphAnimation.frameData.insert(
            morphAnimation.frameData.begin(),
            morphData,
            morphData + (numFrames * numMorphTargets));
        morphAnimation.frameLengthInMs = frameLengthInMs;
        morphAnimation.morphIndices.resize(numMorphTargets);
        for (int i = 0; i < numMorphTargets; i++)
        {
            morphAnimation.morphIndices[i] = morphIndices[i];
        }
        morphAnimation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;

        morphAnimation.startTimeInNanos = 0; // Will be set when first update() is called
        morphAnimation.lengthInFrames = numFrames;

        morphAnimations.emplace_back(morphAnimation);

        return true;
    }

    void AnimationManager::clearMorphAnimationBuffer(
        utils::Entity entity)
    {
        std::lock_guard lock(mMutex);

        auto animationComponentInstance = mMorphAnimationComponentManager->getInstance(entity);
        auto &animationComponent = mMorphAnimationComponentManager->elementAt<0>(animationComponentInstance);
        auto &morphAnimations = animationComponent.animations;
        morphAnimations.clear();
    }

    void AnimationManager::resetToRestPose(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);

        auto filamentInstance = instance->getInstance();
        auto skinCount = filamentInstance->getSkinCount();

        TransformManager &transformManager = mEngine->getTransformManager();

        //
        // To reset the skeleton to its rest pose, we could just call animator->resetBoneMatrices(),
        // which sets all bone matrices to the identity matrix. However, any subsequent calls to animator->updateBoneMatrices()
        // may result in unexpected poses, because that method uses each bone's transform to calculate
        // the bone matrices (and resetBoneMatrices does not affect this transform).
        // To "fully" reset the bone, we need to set its local transform (i.e. relative to its parent)
        // to its original orientation in rest pose.
        //
        // This can be calculated as:
        //
        //   auto rest = inverse(parentTransformInModelSpace) * bindMatrix
        //
        // (where bindMatrix is the inverse of the inverseBindMatrix).
        //
        // The only requirement is that parent bone transforms are reset before child bone transforms.
        // glTF/Filament does not guarantee that parent bones are listed before child bones under a FilamentInstance.
        // We ensure that parents are reset before children by:
        // - pushing all bones onto a stack
        // - iterate over the stack
        //      - look at the bone at the top of the stack
        //      - if the bone already been reset, pop and continue iterating over the stack
        //      - otherwise
        //          - if the bone has a parent that has not been reset, push the parent to the top of the stack and continue iterating
        //          - otherwise
        //              - pop the bone, reset its transform and mark it as completed
        for (int skinIndex = 0; skinIndex < skinCount; skinIndex++)
        {
            std::unordered_set<Entity, Entity::Hasher> joints;
            std::unordered_set<Entity, Entity::Hasher> completed;
            std::stack<Entity> stack;

            auto transforms = getBoneRestTranforms(instance, skinIndex);

            for (int i = 0; i < filamentInstance->getJointCountAt(skinIndex); i++)
            {
                auto restTransform = transforms[i];
                const auto &joint = filamentInstance->getJointsAt(skinIndex)[i];
                auto transformInstance = transformManager.getInstance(joint);
                transformManager.setTransform(transformInstance, restTransform);
            }
        }
        filamentInstance->getAnimator()->updateBoneMatrices();
        return;
    }

    std::vector<math::mat4f> AnimationManager::getBoneRestTranforms(GltfSceneAssetInstance *instance, int skinIndex)
    {

        std::vector<math::mat4f> transforms;

        auto filamentInstance = instance->getInstance();
        auto skinCount = filamentInstance->getSkinCount();

        TransformManager &transformManager = mEngine->getTransformManager();

        transforms.resize(filamentInstance->getJointCountAt(skinIndex));

        //
        // To reset the skeleton to its rest pose, we could just call animator->resetBoneMatrices(),
        // which sets all bone matrices to the identity matrix. However, any subsequent calls to animator->updateBoneMatrices()
        // may result in unexpected poses, because that method uses each bone's transform to calculate
        // the bone matrices (and resetBoneMatrices does not affect this transform).
        // To "fully" reset the bone, we need to set its local transform (i.e. relative to its parent)
        // to its original orientation in rest pose.
        //
        // This can be calculated as:
        //
        //   auto rest = inverse(parentTransformInModelSpace) * bindMatrix
        //
        // (where bindMatrix is the inverse of the inverseBindMatrix).
        //
        // The only requirement is that parent bone transforms are reset before child bone transforms.
        // glTF/Filament does not guarantee that parent bones are listed before child bones under a FilamentInstance.
        // We ensure that parents are reset before children by:
        // - pushing all bones onto a stack
        // - iterate over the stack
        //      - look at the bone at the top of the stack
        //      - if the bone already been reset, pop and continue iterating over the stack
        //      - otherwise
        //          - if the bone has a parent that has not been reset, push the parent to the top of the stack and continue iterating
        //          - otherwise
        //              - pop the bone, reset its transform and mark it as completed
        std::vector<Entity> joints;
        std::unordered_set<Entity, Entity::Hasher> completed;
        std::stack<Entity> stack;

        for (int i = 0; i < filamentInstance->getJointCountAt(skinIndex); i++)
        {
            const auto &joint = filamentInstance->getJointsAt(skinIndex)[i];
            joints.push_back(joint);
            stack.push(joint);
        }

        while (!stack.empty())
        {
            const auto &joint = stack.top();

            // if we've already handled this node previously (e.g. when we encountered it as a parent), then skip
            if (completed.find(joint) != completed.end())
            {
                stack.pop();
                continue;
            }

            const auto transformInstance = transformManager.getInstance(joint);
            auto parent = transformManager.getParent(transformInstance);

            // we need to handle parent joints before handling their children
            // therefore, if this joint has a parent that hasn't been handled yet,
            // push the parent to the top of the stack and start the loop again
            const auto &jointIter = std::find(joints.begin(), joints.end(), joint);
            auto parentIter = std::find(joints.begin(), joints.end(), parent);

            if (parentIter != joints.end() && completed.find(parent) == completed.end())
            {
                stack.push(parent);
                continue;
            }

            // otherwise let's get the inverse bind matrix for the joint
            math::mat4f inverseBindMatrix;
            bool found = false;
            for (int i = 0; i < filamentInstance->getJointCountAt(skinIndex); i++)
            {
                if (filamentInstance->getJointsAt(skinIndex)[i] == joint)
                {
                    inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(skinIndex)[i];
                    found = true;
                    break;
                }
            }
            ASSERT_PRECONDITION(found, "Failed to find inverse bind matrix for joint %d", joint);

            // now we need to ascend back up the hierarchy to calculate the modelSpaceTransform
            math::mat4f modelSpaceTransform;
            while (parentIter != joints.end())
            {
                const auto transformInstance = transformManager.getInstance(parent);
                const auto parentIndex = distance(joints.begin(), parentIter);
                const auto transform = transforms[parentIndex];
                modelSpaceTransform = transform * modelSpaceTransform;
                parent = transformManager.getParent(transformInstance);
                parentIter = std::find(joints.begin(), joints.end(), parent);
            }

            const auto bindMatrix = inverse(inverseBindMatrix);

            const auto inverseModelSpaceTransform = inverse(modelSpaceTransform);

            const auto jointIndex = distance(joints.begin(), jointIter);
            transforms[jointIndex] = inverseModelSpaceTransform * bindMatrix;
            completed.insert(joint);
            stack.pop();
        }
        return transforms;
    }

    void AnimationManager::updateBoneMatrices(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);
        instance->getInstance()->getAnimator()->updateBoneMatrices();
    }

    bool AnimationManager::addBoneAnimation(GltfSceneAssetInstance *instance,
                                            int skinIndex,
                                            int boneIndex,
                                            const float *const frameData,
                                            int numFrames,
                                            float frameLengthInMs,
                                            float fadeOutInSecs,
                                            float fadeInInSecs,
                                            float maxDelta,
                                            bool loop)
    {
        std::lock_guard lock(mMutex);

        BoneAnimation animation;
        animation.boneIndex = boneIndex;
        animation.frameData.clear();

        const auto &inverseBindMatrix = instance->getInstance()->getInverseBindMatricesAt(skinIndex)[boneIndex];
        for (int i = 0; i < numFrames; i++)
        {
            math::mat4f frame(
                frameData[i * 16],
                frameData[(i * 16) + 1],
                frameData[(i * 16) + 2],
                frameData[(i * 16) + 3],
                frameData[(i * 16) + 4],
                frameData[(i * 16) + 5],
                frameData[(i * 16) + 6],
                frameData[(i * 16) + 7],
                frameData[(i * 16) + 8],
                frameData[(i * 16) + 9],
                frameData[(i * 16) + 10],
                frameData[(i * 16) + 11],
                frameData[(i * 16) + 12],
                frameData[(i * 16) + 13],
                frameData[(i * 16) + 14],
                frameData[(i * 16) + 15]);

            animation.frameData.push_back(frame);
        }

        animation.frameLengthInMs = frameLengthInMs;
        animation.startTimeInNanos = 0; // Will be set when first update() is called
        animation.startOffset = 0.0f;
        animation.reverse = false;
        animation.loop = loop;
        animation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;
        animation.lengthInFrames = numFrames;
        animation.frameLengthInMs = frameLengthInMs;
        animation.fadeOutInSecs = fadeOutInSecs;
        animation.fadeInInSecs = fadeInInSecs;
        animation.maxDelta = maxDelta;
        animation.skinIndex = skinIndex;
        if (!mBoneAnimationComponentManager->hasComponent(instance->getInstance()->getRoot()))
        {
            Log("ERROR: specified entity is not animatable (has no animation component attached).");
            return false;
        }
        auto animationComponentInstance = mBoneAnimationComponentManager->getInstance(instance->getInstance()->getRoot());

        auto &animationComponent = mBoneAnimationComponentManager->elementAt<0>(animationComponentInstance);
        auto &boneAnimations = animationComponent.animations;

        boneAnimations.emplace_back(animation);

        return true;
    }

    void AnimationManager::playGltfAnimation(GltfSceneAssetInstance *instance, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset, float speed)
    {
        std::lock_guard lock(mMutex);

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return;
        }

        mGltfAnimationComponentManager->addGltfAnimation(instance->getInstance(), index, loop, reverse, replaceActive, crossfade, startOffset, speed);
    }

    void AnimationManager::stopGltfAnimation(GltfSceneAssetInstance *instance, int index)
    {
        std::lock_guard lock(mMutex);
        auto animationComponentInstance = mGltfAnimationComponentManager->getInstance(instance->getEntity());
        auto &animationComponent = mGltfAnimationComponentManager->elementAt<0>(animationComponentInstance);

        auto erased = std::remove_if(animationComponent.animations.begin(),
                                     animationComponent.animations.end(),
                                     [=](GltfAnimation &anim)
                                     { return anim.index == index; });
        animationComponent.animations.erase(erased,
                                            animationComponent.animations.end());
        return;
    }

    void AnimationManager::setMorphTargetWeights(utils::Entity entity, const float *const weights, const int count)
    {
        std::lock_guard lock(mMutex);
        RenderableManager &rm = mEngine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);

        rm.setMorphWeights(
            renderableInstance,
            weights,
            count);
    }

    void AnimationManager::setGltfAnimationTime(GltfSceneAssetInstance *instance, int animationIndex, float timeInSeconds)
    {
        std::lock_guard lock(mMutex);
        instance->getInstance()->getAnimator()->applyAnimation(animationIndex, timeInSeconds);
        instance->getInstance()->getAnimator()->updateBoneMatrices();
        return;
    }

    float AnimationManager::getGltfAnimationDuration(GltfSceneAssetInstance *instance, int animationIndex)
    {
        return instance->getInstance()->getAnimator()->getAnimationDuration(animationIndex);
    }

    std::vector<std::string> AnimationManager::getGltfAnimationNames(GltfSceneAssetInstance *instance)
    {
        std::vector<std::string> names;

        size_t count = instance->getInstance()->getAnimator()->getAnimationCount();

        for (size_t i = 0; i < count; i++)
        {
            names.push_back(instance->getInstance()->getAnimator()->getAnimationName(i));
        }
        return names;
    }

    std::vector<std::string> AnimationManager::getMorphTargetNames(GltfSceneAsset *asset, EntityId childEntity)
    {
        std::vector<std::string> names;

        auto filamentAsset = asset->getAsset();

        const utils::Entity targetEntity = utils::Entity::import(childEntity);

        size_t count = filamentAsset->getMorphTargetCountAt(targetEntity);
        for (int j = 0; j < count; j++)
        {
            const char *morphName = filamentAsset->getMorphTargetNameAt(targetEntity, j);
            names.push_back(morphName);
        }
        return names;
    }

    void AnimationManager::update(uint64_t frameTimeInNanos)
    {
        std::lock_guard lock(mMutex);
        mGltfAnimationComponentManager->update(frameTimeInNanos);
        mMorphAnimationComponentManager->update(frameTimeInNanos);
        mBoneAnimationComponentManager->update(frameTimeInNanos);
        mLastUpdateTime = frameTimeInNanos;
    }

    math::mat4f AnimationManager::getInverseBindMatrix(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex)
    {
        return instance->getInstance()->getInverseBindMatricesAt(skinIndex)[boneIndex];
    }

    bool AnimationManager::addGltfAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);
        mGltfAnimationComponentManager->addAnimationComponent(instance->getInstance());
        TRACE("Added glTF animation component");
        return true;
    }

    void AnimationManager::removeGltfAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);
        mGltfAnimationComponentManager->removeAnimationComponent(instance->getInstance());
        TRACE("Removed glTF animation component");
    }

    bool AnimationManager::addBoneAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);
        mBoneAnimationComponentManager->addAnimationComponent(instance->getInstance());
        TRACE("Added bone animation component");
        return true;
    }

    void AnimationManager::removeBoneAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(mMutex);
        mBoneAnimationComponentManager->removeAnimationComponent(instance->getInstance());
        TRACE("Removed bone animation component");
    }

    bool AnimationManager::addMorphAnimationComponent(utils::Entity entity)
    {
        std::lock_guard lock(mMutex);
        mMorphAnimationComponentManager->addAnimationComponent(entity);
        TRACE("Added morph animation component");
        return true;
    }

    void AnimationManager::removeMorphAnimationComponent(utils::Entity entity)
    {
        std::lock_guard lock(mMutex);
        mMorphAnimationComponentManager->removeAnimationComponent(entity);
        TRACE("Removed morph animation component");
    }

}