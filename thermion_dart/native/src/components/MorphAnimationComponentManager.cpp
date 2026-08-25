#include <cstdint>
#include <variant>

#include "components/MorphAnimationComponentManager.hpp"

#include "Log.hpp"

namespace thermion
{

    void MorphAnimationComponentManager::addAnimationComponent(utils::Entity target)
    {
        if (!hasComponent(target))
        {
            EntityInstanceBase::Type componentInstance = addComponent(target);
            this->elementAt<0>(componentInstance) = MorphAnimationComponent{};
        }
    }

    void MorphAnimationComponentManager::removeAnimationComponent(utils::Entity target)
    {
        if (hasComponent(target))
        {
            removeComponent(target);
        }
    }

    void MorphAnimationComponentManager::update(uint64_t frameTimeInNanos)
    {
        TRACE("Updating %d morph animation components at %lu", getComponentCount(), frameTimeInNanos);
        for (auto it = begin(); it < end(); it++)
        {
            const auto &entity = getEntity(it);

            auto componentInstance = getInstance(entity);

            auto &animationComponent = elementAt<0>(componentInstance);
            auto &animations = animationComponent.animations;

            TRACE("Component has %d morph animations", animations.size());

            // Apply animations in insertion order. If multiple animations
            // target the same morph, the most recently added animation is
            // applied last and therefore has priority.
            for (size_t animationIndex = 0; animationIndex < animations.size();)
            {
                auto &animation = animations[animationIndex];

                // Initialize start time on first use
                if (animation.startTimeInNanos == 0)
                {
                    animation.startTimeInNanos = frameTimeInNanos;
                    animationIndex++;
                    continue;
                }

                uint64_t elapsedInNanos = frameTimeInNanos - animation.startTimeInNanos;
                float elapsedInSeconds = float(elapsedInNanos) / 1'000'000'000.0f;
                auto animationTargetTime = (animation.startOffset + elapsedInSeconds) * animation.speed;

                if (!animation.loop && animationTargetTime >= animation.durationInSecs)
                {
                    animations.erase(animations.begin() + animationIndex);
                    TRACE("Animation %zu completed", animationIndex);
                    continue;
                }

                int frameNumber = static_cast<int>(animationTargetTime * 1000.0f / animation.frameLengthInMs) % animation.lengthInFrames;

                // offset from the end if reverse
                if (animation.reverse)
                {
                    frameNumber = animation.lengthInFrames - 1 - frameNumber;
                }

                auto baseOffset = frameNumber * animation.morphIndices.size();
                for (size_t targetIndex = 0; targetIndex < animation.morphIndices.size(); targetIndex++)
                {
                    auto morphIndex = animation.morphIndices[targetIndex];
                    auto renderableInstance = mRenderableManager.getInstance(entity);

                    mRenderableManager.setMorphWeights(
                        renderableInstance,
                        animation.frameData.data() + baseOffset + targetIndex,
                        1,
                        morphIndex);
                }
                animationIndex++;
            }
        }
    }
}
