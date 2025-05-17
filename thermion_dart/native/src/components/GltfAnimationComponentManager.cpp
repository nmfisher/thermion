#include <chrono>
#include <variant>

#include "components/AnimationComponentManager.hpp"

#include "Log.hpp"

namespace thermion
{

    void GltfAnimationComponentManager::addAnimationComponent(FilamentInstance *target) {
        if(!hasComponent(target->getRoot())) {
            EntityInstanceBase::Type componentInstance = addComponent(target->getRoot());
            this->elementAt<0>(componentInstance) = { target };
        }            
    }

    void GltfAnimationComponentManager::removeAnimationComponent(FilamentInstance *target) {
        if(hasComponent(target->getRoot())) {
            removeComponent(target->getRoot());
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

                auto elapsedInSecs = animationStatus.startOffset + float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

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

    // void AnimationComponentManager::addGltfAnimationComponent(FilamentInstance *target) {
    //     if(!hasComponent(target->getRoot())) {
    //         EntityInstanceBase::Type componentInstance;
    //         componentInstance = addComponent(instance->getRoot());
    //         this->elementAt<0>(componentInstance) = GltfAnimationComponent animationComponent { target };
    //     }
    // }
    //     //     }
    //     //     else
    //     //     {
    //     //         auto entity = std::get<Entity>(target);
    //     //         if(!hasComponent(entity)) {
    //     //             componentInstance = addComponent(entity);
    //     //             this->elementAt<0>(componentInstance) = animationComponent;
    //     //         }
    //     //     }
    //     // }


    //     void AnimationComponentManager::removeAnimationComponent(std::variant<FilamentInstance *, Entity> target)
    //     {
    //         AnimationComponent animationComponent;
    //         animationComponent.target = target;
    //         EntityInstanceBase::Type componentInstance;
    //         if (std::holds_alternative<FilamentInstance *>(target))
    //         {
    //             auto instance = std::get<FilamentInstance *>(target);
    //             if(hasComponent(instance->getRoot())) {
    //                 removeComponent(instance->getRoot());
    //             }
    //         } else {
    //             auto entity = std::get<Entity>(target);
    //             if(hasComponent(entity)) {
    //                 removeComponent(entity);
    //             }
    //         }
    //     }

    //     void AnimationComponentManager::update()
    //     {

    //         for (auto it = begin(); it < end(); it++)
    //         {
    //             const auto &entity = getEntity(it);

    //             auto componentInstance = getInstance(entity);
    //             auto &animationComponent = elementAt<0>(componentInstance);

    //             auto &morphAnimations = animationComponent.morphAnimations;

    //             if (std::holds_alternative<FilamentInstance *>(animationComponent.target))
    //             {
    //                 auto target = std::get<FilamentInstance *>(animationComponent.target);
    //                 auto animator = target->getAnimator();
    //                 auto &gltfAnimations = animationComponent.gltfAnimations;
    //                 auto &boneAnimations = animationComponent.boneAnimations;

    //                 if(gltfAnimations.size() > 0) {
    //                     for (int i = ((int)gltfAnimations.size()) - 1; i >= 0; i--)
    //                     {
    //                         auto now = high_resolution_clock::now();

    //                         auto animationStatus = animationComponent.gltfAnimations[i];

    //                         auto elapsedInSecs = animationStatus.startOffset + float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

    //                         if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
    //                         {
    //                             animator->applyAnimation(animationStatus.index, animationStatus.durationInSecs - 0.001);
    //                             animator->updateBoneMatrices();
    //                             gltfAnimations.erase(gltfAnimations.begin() + i);
    //                             animationComponent.fadeGltfAnimationIndex = -1;
    //                             continue;
    //                         }
    //                         animator->applyAnimation(animationStatus.index, elapsedInSecs);

    //                         if (animationComponent.fadeGltfAnimationIndex != -1 && elapsedInSecs < animationComponent.fadeDuration)
    //                         {
    //                             // cross-fade
    //                             auto fadeFromTime = animationComponent.fadeOutAnimationStart + elapsedInSecs;
    //                             auto alpha = elapsedInSecs / animationComponent.fadeDuration;
    //                             animator->applyCrossFade(animationComponent.fadeGltfAnimationIndex, fadeFromTime, alpha);
    //                         }
    //                     }

    //                     animator->updateBoneMatrices();
    //                 }

    //                 ///
    //                 /// When fading in/out, interpolate between the "current" transform (which has possibly been set by the glTF animation loop above)
    //                 /// and the first (for fading in) or last (for fading out) frame. 
    //                 ///                    
    //                 for (int i = (int)boneAnimations.size() - 1; i >= 0; i--)
    //                 {
    //                     auto animationStatus = boneAnimations[i];

    //                     auto now = high_resolution_clock::now();

    //                     auto elapsedInMillis = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count());
    //                     auto elapsedInSecs = elapsedInMillis / 1000.0f;

    //                     // if we're not looping and the amount of time elapsed is greater than the animation duration plus the fade-in/out buffer,
    //                     // then the animation is completed and we can delete it
    //                     if (elapsedInSecs >= (animationStatus.durationInSecs + animationStatus.fadeInInSecs + animationStatus.fadeOutInSecs))
    //                     {
    //                         if(!animationStatus.loop) {
    //                             boneAnimations.erase(boneAnimations.begin() + i);
    //                             continue;
    //                         }
    //                     }

    //                     // if we're fading in, treat elapsedFrames is zero (and fading out, treat elapsedFrames as lengthInFrames)
    //                     float elapsedInFrames = (elapsedInMillis - (1000 * animationStatus.fadeInInSecs)) / animationStatus.frameLengthInMs;
    //                     int currFrame = std::floor(elapsedInFrames);
    //                     int nextFrame = currFrame;

    //                     // offset from the end if reverse
    //                     if (animationStatus.reverse)
    //                     {
    //                         currFrame = animationStatus.lengthInFrames - currFrame;
    //                         if (currFrame > 0)
    //                         {
    //                             nextFrame = currFrame - 1;
    //                         }
    //                         else
    //                         {
    //                             nextFrame = 0;
    //                         }
    //                     }
    //                     else
    //                     {
    //                         if (currFrame < animationStatus.lengthInFrames - 1)
    //                         {
    //                             nextFrame = currFrame + 1;
    //                         }
    //                         else
    //                         {
    //                             nextFrame = currFrame;
    //                         }
    //                     }
    //                     currFrame = std::clamp(currFrame, 0, animationStatus.lengthInFrames - 1);
    //                     nextFrame = std::clamp(nextFrame, 0, animationStatus.lengthInFrames - 1);

    //                     float frameDelta = elapsedInFrames - currFrame;

    //                     // linearly interpolate this animation between its last/current frames 
    //                     // this is to avoid jerky animations when the animation framerate is slower than our tick rate                        

    //                     math::float3 currScale, newScale;
    //                     math::quatf currRotation, newRotation;
    //                     math::float3 currTranslation, newTranslation;
    //                     math::mat4f curr = animationStatus.frameData[currFrame];
    //                     decomposeMatrix(curr, &currTranslation, &currRotation, &currScale);
                        
    //                     if(frameDelta > 0) {
    //                         math::mat4f next = animationStatus.frameData[nextFrame];
    //                         decomposeMatrix(next, &newTranslation, &newRotation, &newScale);                            
    //                         newScale = mix(currScale, newScale, frameDelta);
    //                         newRotation = slerp(currRotation, newRotation, frameDelta);
    //                         newTranslation = mix(currTranslation, newTranslation, frameDelta);
    //                     } else { 
    //                         newScale = currScale;
    //                         newRotation = currRotation;
    //                         newTranslation = currTranslation;
    //                     }

    //                     const Entity joint = target->getJointsAt(animationStatus.skinIndex)[animationStatus.boneIndex];

    //                     // now calculate the fade out/in delta
    //                     // if we're fading in, this will be 0.0 at the start of the fade and 1.0 at the end
    //                     auto fadeDelta = elapsedInSecs / animationStatus.fadeInInSecs;
                        
    //                     // // if we're fading out, this will be 1.0 at the start of the fade and 0.0 at the end
    //                     if(fadeDelta > 1.0f) {
    //                         fadeDelta = 1 - ((elapsedInSecs - animationStatus.durationInSecs - animationStatus.fadeInInSecs) / animationStatus.fadeOutInSecs);
    //                     }

    //                     fadeDelta = std::clamp(fadeDelta, 0.0f, animationStatus.maxDelta);

    //                     auto jointTransform = _transformManager.getInstance(joint);

    //                     // linearly interpolate this animation between its current (interpolated) frame and the current transform (i.e. as set by the gltf frame)
    //                     // // if we are fading in or out, apply a delta
    //                     if (fadeDelta >= 0.0f && fadeDelta <= 1.0f) {
    //                         math::float3 fadeScale;
    //                         math::quatf fadeRotation;
    //                         math::float3 fadeTranslation;
    //                         auto currentTransform = _transformManager.getTransform(jointTransform);
    //                         decomposeMatrix(currentTransform, &fadeTranslation, &fadeRotation, &fadeScale);
    //                         newScale = mix(fadeScale, newScale, fadeDelta);
    //                         newRotation = slerp(fadeRotation, newRotation, fadeDelta);
    //                         newTranslation = mix(fadeTranslation, newTranslation, fadeDelta);
    //                     }

    //                     _transformManager.setTransform(jointTransform, composeMatrix(newTranslation, newRotation, newScale));

    //                     animator->updateBoneMatrices();

    //                     if (animationStatus.loop && elapsedInSecs >= (animationStatus.durationInSecs + animationStatus.fadeInInSecs + animationStatus.fadeOutInSecs))
    //                     {
    //                         animationStatus.start = now;
    //                     }
    //                 }
    //             }
    //             for (int i = (int)morphAnimations.size() - 1; i >= 0; i--)
    //             {

    //                 auto now = high_resolution_clock::now();

    //                 auto animationStatus = morphAnimations[i];

    //                 auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

    //                 if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
    //                 {
    //                     morphAnimations.erase(morphAnimations.begin() + i);
    //                     continue;
    //                 }

    //                 int frameNumber = static_cast<int>(elapsedInSecs * 1000.0f / animationStatus.frameLengthInMs) % animationStatus.lengthInFrames;
    //                 // offset from the end if reverse
    //                 if (animationStatus.reverse)
    //                 {
    //                     frameNumber = animationStatus.lengthInFrames - frameNumber;
    //                 }
    //                 auto baseOffset = frameNumber * animationStatus.morphIndices.size();
    //                 for (int i = 0; i < animationStatus.morphIndices.size(); i++)
    //                 {
    //                     auto morphIndex = animationStatus.morphIndices[i];
    //                     // set the weights appropriately
    //                     _renderableManager.setMorphWeights(
    //                         _renderableManager.getInstance(animationStatus.meshTarget),
    //                         animationStatus.frameData.data() + baseOffset + i,
    //                         1,
    //                         morphIndex);
    //                 }
    //             }
    //     }
    // };
// }
