#include <chrono>
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
                auto now = high_resolution_clock::now();
                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last.start).count()) / 1000.0f;
                animationComponent.fadeOutAnimationStart = elapsedInSecs;
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
        animation.start = std::chrono::high_resolution_clock::now();
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

    void GltfAnimationComponentManager::update() {
        TRACE("Updating with %d components", getComponentCount());
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
                auto now = high_resolution_clock::now();

                auto animationStatus = gltfAnimations[i];

                auto elapsedInSecs = (animationStatus.startOffset + float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f) * animationStatus.speed;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    animator->applyAnimation(animationStatus.index, animationStatus.durationInSecs - 0.001);
                    animator->updateBoneMatrices();
                    gltfAnimations.erase(gltfAnimations.begin() + i);
                    animationComponent.fadeGltfAnimationIndex = -1;
                    continue;
                }
                animator->applyAnimation(animationStatus.index, elapsedInSecs);

                if (animationComponent.fadeGltfAnimationIndex != -1 && elapsedInSecs < animationComponent.fadeDuration)
                {
                    // cross-fade
                    auto fadeFromTime = animationComponent.fadeOutAnimationStart + elapsedInSecs;
                    auto alpha = elapsedInSecs / animationComponent.fadeDuration;
                    animator->applyCrossFade(animationComponent.fadeGltfAnimationIndex, fadeFromTime, alpha);
                }
            }

            animator->updateBoneMatrices();
        }
    }
}
