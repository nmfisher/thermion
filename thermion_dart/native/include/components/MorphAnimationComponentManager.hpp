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
    using namespace std::chrono;

    // The status of a morph target animation created dynamically at runtime (not glTF embedded).
    //
    struct MorphAnimation : AnimationComponentBase
    {
        int lengthInFrames;
        float frameLengthInMs = 0;
        std::vector<float> frameData;
        std::vector<int> morphIndices;
    };


    ///
    ///
    struct MorphAnimationComponent
    {
        std::vector<MorphAnimation> animations;
    };

    class MorphAnimationComponentManager : public utils::SingleInstanceComponentManager<MorphAnimationComponent> {
        public:
            MorphAnimationComponentManager(
                utils::EntityManager &em,
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) :
                    utils::SingleInstanceComponentManager<MorphAnimationComponent>(em, "MorphAnimationComponentManager"),
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~MorphAnimationComponentManager() {};
            
            void addAnimationComponent(Entity entity);
            void removeAnimationComponent(Entity entity);
            void update(uint64_t frameTimeInNanos); 

        private:
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
    };

}
