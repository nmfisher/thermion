#pragma once

#include <string>

namespace thermion::plugin::input {

    /**
     * Interface for pipeline stages that run before input processing.
     *
     * This provides a clean, type-safe way for systems like physics
     * to integrate with the input pipeline's pre-update phase.
     *
     * Classes implementing this interface can be registered with
     * the Pipeline and will be called each frame before input processing.
     */
    class PipelineStage {
    public:
        virtual ~PipelineStage() = default;

        /**
         * Called during pipeline pre-update phase.
         *
         * @param deltaTimeInNanos Time elapsed since last frame in nanoseconds
         */
        virtual void update(uint64_t deltaTimeInNanos) = 0;

        /**
         * Get the name of this pipeline stage for debugging and logging.
         *
         * @return Human-readable stage name
         */
        virtual const char* getName() const = 0;

    };

} // namespace thermion::plugin::input