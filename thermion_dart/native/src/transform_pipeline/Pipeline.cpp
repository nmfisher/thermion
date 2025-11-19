#include "Log.hpp"

#include "transform_pipeline/Pipeline.hpp"
#include "transform_pipeline/InputEventManager.hpp"
#include "transform_pipeline/MovementIntentCalculator.hpp"

namespace thermion::plugin::input {

    // Global pipeline instance
    static std::unique_ptr<Pipeline> g_pipeline_instance = std::make_unique<Pipeline>();

    Pipeline::Pipeline()
        : mEventManager(std::make_unique<InputEventManager>()), mCalculator(std::make_unique<MovementIntentCalculator>())
    {
        TRACE("[Pipeline] Pipeline created with event manager and intent calculator");
    }

    Pipeline::~Pipeline() {
        TRACE("[Pipeline] Pipeline destructor called");
        cleanup();
    }

    void Pipeline::update(uint64_t frameTimeInNanos) {
        TRACE("[Pipeline] update called with frame time: %llu nanoseconds", frameTimeInNanos);

        if (!mEventManager || !mCalculator || !mEngine) {
            TRACE("[Pipeline] No event manager, calculator, or engine available for update");
            return;
        }

        // Calculate delta time in nanoseconds to maintain precision
        uint64_t deltaTimeInNanos = 16'666'666; // Default to 16ms (60 FPS) in nanoseconds
        if (mFirstUpdate) {
            mLastFrameTime = frameTimeInNanos;
            mFirstUpdate = false;
            TRACE("[Pipeline] First update, initializing frame time tracking");
        } else {
            deltaTimeInNanos = frameTimeInNanos - mLastFrameTime;
            mLastFrameTime = frameTimeInNanos;
        }
        TRACE("[Pipeline] Calculated delta time: %llu nanoseconds (%.6f seconds)", deltaTimeInNanos, deltaTimeInNanos / 1'000'000'000.0f);
        TRACE("[Pipeline] DELTA_TIME_DEBUG: frame_time=%llu, delta_time=%llu", frameTimeInNanos, deltaTimeInNanos);

        // Process input events
        mEventManager->update();
        TRACE("[Pipeline] Event manager update completed");

        // Create input state for the calculator
        InputState inputState = {
            mEventManager->getCurrentPressedKeys(),
            mEventManager->getCurrentMouseDelta()
        };

        // Calculate movement intent using the calculator
        MovementIntent intent = mCalculator->calculate(inputState, deltaTimeInNanos);
        TRACE("[Pipeline] Calculator completed, intent has movement: %s, rotation: %s",
              intent.hasMovementIntent() ? "yes" : "no",
              intent.hasRotationIntent() ? "yes" : "no");

        // First, run all registered pipeline stages
        // This is currently disabled in favour of using a movement executor directly for physics
        // I'm unsure if we even need a concept of "PipelineStage"
        if(false) {
            for (auto* stage : mPipelineStages) {
                stage->update(deltaTimeInNanos);
                TRACE("[Pipeline] Executed pipeline stage: %s", stage->getName());
            }
        }

        // Process movement intent for all registered executors
        for (auto* executor : mMovementIntentExecutors) {
            executor->process(intent, deltaTimeInNanos);
            TRACE("[Pipeline] Processed movement intent in executor");
        }

        // Reset mouse delta after all executors have consumed it
        if (mEventManager) {
            mEventManager->resetMouseDelta();
            TRACE("[Pipeline] Reset mouse delta after processing");
        }

        TRACE("[Pipeline] Pipeline update completed");
    }

    const char* Pipeline::getName() const {
        return "InputHandlerPipeline";
    }

    void Pipeline::cleanup() {
        TRACE("[Pipeline] Cleanup called");

        if (mEventManager) {
            mEventManager->cleanup();
        }

        mMovementIntentExecutors.clear();
        mPipelineStages.clear();
        mEngine = nullptr;

        TRACE("[Pipeline] Cleanup completed");
    }

    void Pipeline::setEngine(filament::Engine* engine) {
        bool g_pipeline_registered = thermion::plugin::RegisterPlugin(
        "InputHandlerPipeline", this);
        TRACE("[Pipeline] REGISTERED!");
        mEngine = engine;
        TRACE("[Pipeline] Engine set for pipeline (calculator and event manager don't need engine)");
    }

    void Pipeline::registerMovementIntentExecutor(MovementIntentExecutor* executor) {
        if (executor && std::find(mMovementIntentExecutors.begin(), mMovementIntentExecutors.end(), executor) == mMovementIntentExecutors.end()) {
            mMovementIntentExecutors.push_back(executor);
            TRACE("[Pipeline] Registered movement intent executor (total: %zu)", mMovementIntentExecutors.size());
        }
    }

    void Pipeline::unregisterMovementIntentExecutor(MovementIntentExecutor* executor) {
        auto it = std::find(mMovementIntentExecutors.begin(), mMovementIntentExecutors.end(), executor);
        if (it != mMovementIntentExecutors.end()) {
            mMovementIntentExecutors.erase(it);
            TRACE("[Pipeline] Unregistered movement intent executor (total: %zu)", mMovementIntentExecutors.size());
        }
    }

    void Pipeline::registerPipelineStage(PipelineStage* stage) {
        if (stage && std::find(mPipelineStages.begin(), mPipelineStages.end(), stage) == mPipelineStages.end()) {
            mPipelineStages.push_back(stage);
            TRACE("[Pipeline] Registered pipeline stage: %s (total: %zu)", stage->getName(), mPipelineStages.size());
        }
    }

    void Pipeline::unregisterPipelineStage(PipelineStage* stage) {
        auto it = std::find(mPipelineStages.begin(), mPipelineStages.end(), stage);
        if (it != mPipelineStages.end()) {
            mPipelineStages.erase(it);
            TRACE("[Pipeline] Unregistered pipeline stage: %s (total: %zu)", stage->getName(), mPipelineStages.size());
        }
    }

    Pipeline* getPipeline() {
        return g_pipeline_instance.get();
    }

} // namespace thermion::plugin::input