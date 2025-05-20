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
#include "components/Animation.hpp"

namespace thermion
{
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std::chrono;

    //
    // The status of a morph target animation created dynamically at runtime (not glTF embedded).
    //
    struct MorphAnimation : Animation
    {
        int lengthInFrames;
        float frameLengthInMs = 0;
        std::vector<float> frameData;
        std::vector<int> morphIndices; 
    };


    /// @brief 
    ///
    ///
    struct MorphAnimationComponent
    {
        std::vector<MorphAnimation> animations;
    };

    class MorphAnimationComponentManager : public utils::SingleInstanceComponentManager<MorphAnimationComponent> {
        public:
            MorphAnimationComponentManager(
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) : 
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~MorphAnimationComponentManager() {};
            
            void addAnimationComponent(Entity entity);
            void removeAnimationComponent(Entity entity);
            void update(); 

        private:
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
    };

}
