#include <cstdint>
#include <variant>

#include "components/GltfAnimationComponentManager.hpp"

#include "Log.hpp"

namespace thermion
{

    void GltfAnimationComponentManager::addAnimationComponent(FilamentInstance *target) {
        if(!hasComponent(target->getRoot())) {
            EntityInstanceBase::Type componentInstance = addComponent(target->getRoot());
            this->elementAt<0>(componentInstance) = { target };
        }            
    }

    bool GltfAnimationComponentManager::addGltfAnimation(FilamentInstance *target, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset, float speed) {

        EntityInstanceBase::Type componentInstance = getInstance(target->getRoot());

        auto &animationComponent = this->elementAt<0>(componentInstance);

        animationComponent.target = target;

        if (replaceActive)
        {
            if (animationComponent.animations.size() > 0)
            {
                auto &last = animationComponent.animations.back();
                animationComponent.fadeGltfAnimationIndex = last.index;
                animationComponent.fadeDuration = crossfade;
                animationComponent.fadeOutAnimationStart = (float(mLastUpdateTime - last.startTimeInNanos) / 1'000'000'000.0f) / last.durationInSecs;
                animationComponent.animations.clear();
            }
            else
            {
                animationComponent.fadeGltfAnimationIndex = -1;
                animationComponent.fadeDuration = 0.0f;
            }
        }
        else if (crossfade > 0)
        {
            Log("ERROR: crossfade only supported when replaceActive is true.");
            return false;
        }
        else
        {
            animationComponent.fadeGltfAnimationIndex = -1;
            animationComponent.fadeDuration = 0.0f;
        }

        GltfAnimation animation;
        animation.startOffset = startOffset;
        animation.index = index;
        animation.startTimeInNanos = 0; // Will be set by AnimationManager
        animation.loop = loop;
        animation.reverse = reverse;
        animation.durationInSecs = target->getAnimator()->getAnimationDuration(index);
        animation.speed = speed;

        bool found = false;

        // don't play the animation if it's already running
        for (int i = 0; i < animationComponent.animations.size(); i++)
        {
            if (animationComponent.animations[i].index == index)
            {
                found = true;
                break;
            }
        }
        if (!found)
        {
            animationComponent.animations.push_back(animation);
        }
        return true;
    }   

    void GltfAnimationComponentManager::removeAnimationComponent(FilamentInstance *target) {
        if(hasComponent(target->getRoot())) {
            removeComponent(target->getRoot());
            TRACE("Found component, component removed");
        } else {
            TRACE("Component not found, skipping removal");
        }
    }

    void GltfAnimationComponentManager::update(uint64_t frameTimeInNanos) {
 
        TRACE("Updating %d glTF animation components at %lu", getComponentCount(), frameTimeInNanos);
        for (auto it = begin(); it < end(); it++)
        {
            const auto &entity = getEntity(it);

            auto componentInstance = getInstance(entity);
            auto &animationComponent = elementAt<0>(componentInstance);

            auto target = animationComponent.target;
            auto animator = target->getAnimator();
            auto &gltfAnimations = animationComponent.animations;

            for (int i = ((int)gltfAnimations.size()) - 1; i >= 0; i--)
            {
                auto &animationStatus = gltfAnimations[i];

                // Initialize start time on first use
                if (animationStatus.startTimeInNanos == 0) {
                    animationStatus.startTimeInNanos = frameTimeInNanos;
                    continue;
                }

                uint64_t elapsedInNanos = frameTimeInNanos - animationStatus.startTimeInNanos;
                float elapsedInSeconds = float(elapsedInNanos) / 1'000'000'000.0f;
                auto animationTargetTime = (animationStatus.startOffset + elapsedInSeconds) * animationStatus.speed;

                if (!animationStatus.loop && animationTargetTime >= animationStatus.durationInSecs)
                {
                    animator->applyAnimation(animationStatus.index, animationStatus.durationInSecs - 0.001);
                    animator->updateBoneMatrices();
                    gltfAnimations.erase(gltfAnimations.begin() + i);
                    animationComponent.fadeGltfAnimationIndex = -1;
                    continue;
                }
                animator->applyAnimation(animationStatus.index, animationTargetTime);

                if (animationComponent.fadeGltfAnimationIndex != -1 && animationTargetTime < animationComponent.fadeDuration)
                {
                    // cross-fade
                    auto fadeFromTime = animationComponent.fadeOutAnimationStart + elapsedInNanos;
                    auto alpha = animationTargetTime / animationComponent.fadeDuration;
                    animator->applyCrossFade(animationComponent.fadeGltfAnimationIndex, fadeFromTime, alpha);
                }
            }

            animator->updateBoneMatrices();
        }
        mLastUpdateTime = frameTimeInNanos;
    }
}
