#pragma once

#include <memory>
#include <vector>
#include <functional>

#include <Plugin.hpp>
#include <filament/Engine.h>
#include "MovementIntentExecutor.hpp"
#include "MovementIntentCalculator.hpp"
#include "PipelineStage.hpp"

namespace thermion::plugin::input {

    // Forward declarations
    class InputEventManager;
    class PipelineStage;

    /**
     * Pipeline class that implements the Plugin interface and coordinates
     * between InputEventManager, MovementIntentCalculator and MovementIntentExecutors.
     *
     * This class separates plugin lifecycle management from component management,
     * allowing for cleaner architecture and better separation of concerns.
     */
    class Pipeline : public thermion::plugin::Plugin {
    public:
        Pipeline();
        ~Pipeline();

        // Plugin interface implementation
        void update(uint64_t frameTimeInNanos) override;
        const char* getName() const override;
        void cleanup() override;

        // Engine management
        void setEngine(filament::Engine* engine);

        // Manager access methods
        InputEventManager* getEventManager() const { return mEventManager.get(); }
        MovementIntentCalculator* getCalculator() const { return mCalculator.get(); }

        // Movement configuration management
        MovementConfig& getMovementConfig() { return mMovementConfig; }
        const MovementConfig& getMovementConfig() const { return mMovementConfig; }

        // Movement intent processor management
        void registerMovementIntentExecutor(MovementIntentExecutor* processor);
        void unregisterMovementIntentExecutor(MovementIntentExecutor* processor);

        // Pipeline stage management (physics, animation, etc.)
        void registerPipelineStage(PipelineStage* stage);
        void unregisterPipelineStage(PipelineStage* stage);

    private:
        // Core components
        std::unique_ptr<InputEventManager> mEventManager;
        std::unique_ptr<MovementIntentCalculator> mCalculator;
        std::vector<MovementIntentExecutor*> mMovementIntentExecutors;

        // Movement configuration (could be loaded from config file, UI, etc.)
        MovementConfig mMovementConfig;

        // Pipeline stages (physics, animation, etc.)
        std::vector<PipelineStage*> mPipelineStages;

        // Engine reference
        filament::Engine* mEngine = nullptr;

        // Frame time tracking for delta time calculation
        uint64_t mLastFrameTime = 0;
        bool mFirstUpdate = true;
    };

    // Global access to the pipeline instance
    Pipeline* getPipeline();

} // namespace thermion::plugin::input