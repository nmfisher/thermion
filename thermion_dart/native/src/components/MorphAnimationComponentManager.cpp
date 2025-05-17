#include <chrono>
#include <variant>

#include "components/AnimationComponentManager.hpp"

#include "Log.hpp"

namespace thermion
{

    void MorphAnimationComponentManager::addAnimationComponent(utils::Entity target) {
        if(!hasComponent(target)) {
            EntityInstanceBase::Type componentInstance = addComponent(target);
            this->elementAt<0>(componentInstance) = MorphAnimationComponent {  };
        }            
    }

    void MorphAnimationComponentManager::removeAnimationComponent(utils::Entity target) {
        if(hasComponent(target)) {
            removeComponent(target);
        }
    }

    void MorphAnimationComponentManager::update() {
        TRACE("Updating %d morph animation components", getComponentCount());
         for (auto it = begin(); it < end(); it++)
        {
            const auto &entity = getEntity(it);
            
            auto componentInstance = getInstance(entity);
            
            auto &animationComponent = elementAt<0>(componentInstance);
            auto &animations = animationComponent.animations;

            TRACE("Component has %d animations", animations.size());           

            for (int i = (int)animations.size() - 1; i >= 0; i--)
                {

                    auto now = high_resolution_clock::now();

                    auto &animation = animationComponent.animations[i];

                    auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animation.start).count()) / 1000.0f;

                    if (!animation.loop && elapsedInSecs >= animation.durationInSecs)
                    {
                        animations.erase(animations.begin() + i);
                        TRACE("Animation %d completed", i);
                        continue;
                    }

                    int frameNumber = static_cast<int>(elapsedInSecs * 1000.0f / animation.frameLengthInMs) % animation.lengthInFrames;
                    // offset from the end if reverse
                    if (animation.reverse)
                    {
                        frameNumber = animation.lengthInFrames - frameNumber;
                    }
                    
                    auto baseOffset = frameNumber * animation.morphIndices.size();
                    for (int i = 0; i < animation.morphIndices.size(); i++)
                    {
                        auto morphIndex = animation.morphIndices[i];
                        auto renderableInstance = mRenderableManager.getInstance(entity);
                        
                        mRenderableManager.setMorphWeights(
                            renderableInstance,
                            animation.frameData.data() + baseOffset + i,
                            1,
                            morphIndex);
                            
                    }
                }
        }
    }
}
