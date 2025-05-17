#pragma once

#include <chrono>
#include <variant>

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

template class std::vector<float>;
namespace thermion
{
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std::chrono;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;

    struct Animation
    {
        time_point_t start = time_point_t::max();
        float startOffset;
        bool loop = false;
        bool reverse = false;
        float durationInSecs = 0;
    };

    /// @brief 
    /// The status of an animation embedded in a glTF object.
    /// @param index refers to the index of the animation in the animations property of the underlying object.
    ///
    struct GltfAnimation : Animation
    {
        int index = -1;
    };

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

    struct BoneAnimation : Animation {
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
        FilamentInstance * target;
        std::vector<BoneAnimation> animations;
    };

    /// @brief 
    ///
    ///
    struct MorphAnimationComponent
    {
        std::vector<MorphAnimation> animations;
    };

    /// @brief 
    ///
    ///
    struct GltfAnimationComponent
    {
        FilamentInstance * target;
        // the index of the last active glTF animation,
        // used to cross-fade
        int fadeGltfAnimationIndex = -1;
        float fadeDuration = 0.0f;
        float fadeOutAnimationStart = 0.0f;
        std::vector<GltfAnimation> animations;
    };


    class GltfAnimationComponentManager : public utils::SingleInstanceComponentManager<GltfAnimationComponent> {
        public:
            GltfAnimationComponentManager(
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) : 
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~GltfAnimationComponentManager() = default;
            void addAnimationComponent(FilamentInstance *target);
            void removeAnimationComponent(FilamentInstance *target);
            void update(); 

        private:
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
    };

    class BoneAnimationComponentManager : public utils::SingleInstanceComponentManager<BoneAnimationComponent> {
        public:
            BoneAnimationComponentManager(
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) : 
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~BoneAnimationComponentManager() {};
            
            void addAnimationComponent(FilamentInstance *target);
            void removeAnimationComponent(FilamentInstance *target);
            void update(); 

        private:
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
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
