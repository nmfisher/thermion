#pragma once

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TransformManager.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <gltfio/Animator.h>
#include <gltfio/math.h>

#include <utils/SingleInstanceComponentManager.h>

#include "Log.hpp"
#include "scene/AnimationComponentBase.hpp"

namespace thermion
{
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;

    struct BoneAnimation : AnimationComponentBase {
        int lengthInFrames;
        size_t boneIndex;
        size_t skinIndex = 0;
        float frameLengthInMs = 0;
        std::vector<math::mat4f> frameData;
        float fadeOutInSecs = 0;
        float fadeInInSecs = 0;
        float maxDelta = 1.0f;
    };

    /// @brief 
    ///
    ///
    struct BoneAnimationComponent 
    {
        filament::gltfio::FilamentInstance * target;
        std::vector<BoneAnimation> animations;
    };
    
    class BoneAnimationComponentManager : public utils::SingleInstanceComponentManager<BoneAnimationComponent> {
        public:
            BoneAnimationComponentManager(
                utils::EntityManager &em,
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) :
                    utils::SingleInstanceComponentManager<BoneAnimationComponent>(em, "BoneAnimationComponentManager"),
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~BoneAnimationComponentManager() {};
            
            void addAnimationComponent(FilamentInstance *target);
            void removeAnimationComponent(FilamentInstance *target);
            void update(uint64_t frameTimeInNanos); 

        private:
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
    };

   

}
