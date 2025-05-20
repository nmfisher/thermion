#include <memory>
#include <stack>
#include <unordered_set>
#include <vector>

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/RenderableManager.h>

#include <gltfio/Animator.h>

#include "Log.hpp"

#include "scene/AnimationManager.hpp"
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAssetInstance.hpp"

namespace thermion
{

    using namespace filament;
    using namespace utils;

    AnimationManager::AnimationManager(Engine *engine, Scene *scene) : _engine(engine), _scene(scene)
    {
        auto &transformManager = _engine->getTransformManager();
        auto &renderableManager = _engine->getRenderableManager();
        _gltfAnimationComponentManager = std::make_unique<GltfAnimationComponentManager>(transformManager, renderableManager);
        _morphAnimationComponentManager = std::make_unique<MorphAnimationComponentManager>(transformManager, renderableManager);
        _boneAnimationComponentManager = std::make_unique<BoneAnimationComponentManager>(transformManager, renderableManager);
    }

    bool AnimationManager::setMorphAnimationBuffer(
        utils::Entity entity,
        const float *const morphData,
        const uint32_t *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {

        std::lock_guard lock(_mutex);

        if (!_morphAnimationComponentManager->hasComponent(entity))
        {
            _morphAnimationComponentManager->addAnimationComponent(entity);
        }

        auto animationComponentInstance = _morphAnimationComponentManager->getInstance(entity);
        auto &animationComponent = _morphAnimationComponentManager->elementAt<0>(animationComponentInstance);
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

        morphAnimation.start = high_resolution_clock::now();
        morphAnimation.lengthInFrames = numFrames;

        morphAnimations.emplace_back(morphAnimation);

        auto& foo = morphAnimations[morphAnimations.size() - 1];

        return true;
    }

    void AnimationManager::clearMorphAnimationBuffer(
        utils::Entity entity)
    {
        std::lock_guard lock(_mutex);

        auto animationComponentInstance = _morphAnimationComponentManager->getInstance(entity);
        auto &animationComponent = _morphAnimationComponentManager->elementAt<0>(animationComponentInstance);
        auto &morphAnimations = animationComponent.animations;
        morphAnimations.clear();
    }

    void AnimationManager::resetToRestPose(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(_mutex);

        auto filamentInstance = instance->getInstance();
        auto skinCount = filamentInstance->getSkinCount();

        TransformManager &transformManager = _engine->getTransformManager();

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

        TransformManager &transformManager = _engine->getTransformManager();

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
                                            float maxDelta)
    {
        std::lock_guard lock(_mutex);

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
        animation.start = std::chrono::high_resolution_clock::now();
        animation.reverse = false;
        animation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;
        animation.lengthInFrames = numFrames;
        animation.frameLengthInMs = frameLengthInMs;
        animation.fadeOutInSecs = fadeOutInSecs;
        animation.fadeInInSecs = fadeInInSecs;
        animation.maxDelta = maxDelta;
        animation.skinIndex = skinIndex;
        if (!_boneAnimationComponentManager->hasComponent(instance->getInstance()->getRoot()))
        {
            Log("ERROR: specified entity is not animatable (has no animation component attached).");
            return false;
        }
        auto animationComponentInstance = _boneAnimationComponentManager->getInstance(instance->getInstance()->getRoot());

        auto &animationComponent = _boneAnimationComponentManager->elementAt<0>(animationComponentInstance);
        // auto &boneAnimations = animationComponent.boneAnimations;

        // boneAnimations.emplace_back(animation);

        return true;
    }

    void AnimationManager::playGltfAnimation(GltfSceneAssetInstance *instance, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset)
    {
        std::lock_guard lock(_mutex);

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return;
        }

        _gltfAnimationComponentManager->addGltfAnimation(instance->getInstance(), index, loop, reverse, replaceActive, crossfade, startOffset);
    }

    void AnimationManager::stopGltfAnimation(GltfSceneAssetInstance *instance, int index)
    {

        auto animationComponentInstance = _gltfAnimationComponentManager->getInstance(instance->getEntity());
        auto &animationComponent = _gltfAnimationComponentManager->elementAt<0>(animationComponentInstance);

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
        RenderableManager &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);

        rm.setMorphWeights(
            renderableInstance,
            weights,
            count);
    }

    void AnimationManager::setGltfAnimationFrame(GltfSceneAssetInstance *instance, int animationIndex, int animationFrame)
    {
        auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
        instance->getInstance()->getAnimator()->applyAnimation(animationIndex, offset);
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

    vector<Entity> AnimationManager::getBoneEntities(GltfSceneAssetInstance *instance, int skinIndex)
    {
        auto *joints = instance->getInstance()->getJointsAt(skinIndex);
        auto jointCount = instance->getInstance()->getJointCountAt(skinIndex);
        std::vector<Entity> boneEntities(joints, joints + jointCount);
        return boneEntities;
    }

    void AnimationManager::update(uint64_t frameTimeInNanos)
    {
        std::lock_guard lock(_mutex);
        _gltfAnimationComponentManager->update();
        _morphAnimationComponentManager->update();
        _boneAnimationComponentManager->update();
    }

    math::mat4f AnimationManager::getInverseBindMatrix(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex)
    {
        return instance->getInstance()->getInverseBindMatricesAt(skinIndex)[boneIndex];
    }

    bool AnimationManager::setBoneTransform(GltfSceneAssetInstance *instance, int32_t skinIndex, int boneIndex, math::mat4f transform)
    {
        std::lock_guard lock(_mutex);

        RenderableManager &rm = _engine->getRenderableManager();

        const auto &renderableInstance = rm.getInstance(instance->getEntity());

        if (!renderableInstance.isValid())
        {
            Log("Specified entity is not a renderable. You probably provided the ultimate parent entity of a glTF asset, which is non-renderable. ");
            return false;
        }

        rm.setBones(
            renderableInstance,
            &transform,
            1,
            boneIndex);
        return true;
    }

    bool AnimationManager::addGltfAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(_mutex);
        _gltfAnimationComponentManager->addAnimationComponent(instance->getInstance());
        TRACE("Added glTF animation component");
        return true;
    }

    void AnimationManager::removeGltfAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(_mutex);
        _gltfAnimationComponentManager->removeAnimationComponent(instance->getInstance());
        TRACE("Removed glTF animation component");
    }

    bool AnimationManager::addBoneAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(_mutex);
        _boneAnimationComponentManager->addAnimationComponent(instance->getInstance());
        TRACE("Added bone animation component");
        return true;
    }

    void AnimationManager::removeBoneAnimationComponent(GltfSceneAssetInstance *instance)
    {
        std::lock_guard lock(_mutex);
        _boneAnimationComponentManager->removeAnimationComponent(instance->getInstance());
        TRACE("Removed bone animation component");
    }

    bool AnimationManager::addMorphAnimationComponent(utils::Entity entity)
    {
        std::lock_guard lock(_mutex);
        _morphAnimationComponentManager->addAnimationComponent(entity);
        TRACE("Added morph animation component");
        return true;
    }

    void AnimationManager::removeMorphAnimationComponent(utils::Entity entity)
    {
        std::lock_guard lock(_mutex);
        _morphAnimationComponentManager->removeAnimationComponent(entity);
        TRACE("Removed morph animation component");
    }

}