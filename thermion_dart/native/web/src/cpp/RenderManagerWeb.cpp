#include "rendering/RenderManager.hpp"
#include <algorithm>
#include <chrono>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/eventloop.h>

namespace thermion {

void RenderManager::startFrameLoop() {
#ifndef THERMION_WEB_MAIN_THREAD
    if (mFrameLoopRunning) return;
    mFrameLoopRunning = true;
    mNextFrameTimeMs = 0;
    // Emscripten's previous main loop used a timer on workers without rAF.
    // Keep that fallback when scheduling frames directly.
    mFrameLoopUsesTimeout = EM_ASM_INT(return typeof requestAnimationFrame !== 'function');
    requestNextFrame();
#endif
}

void RenderManager::stopFrameLoop() {
#ifndef THERMION_WEB_MAIN_THREAD
    mFrameLoopRunning = false;
    if (mAnimationFrameRequest != -1) {
        if (mFrameLoopUsesTimeout) emscripten_clear_timeout(mAnimationFrameRequest);
        else emscripten_cancel_animation_frame(mAnimationFrameRequest);
        mAnimationFrameRequest = -1;
    }
#endif
}

#ifndef THERMION_WEB_MAIN_THREAD
void RenderManager::requestNextFrame() {
    if (mFrameLoopUsesTimeout) {
        // Keep Emscripten's 60 Hz timer cadence, including time spent rendering.
        const double now = emscripten_get_now();
        constexpr double interval = 1000.0 / 60.0;
        if (mNextFrameTimeMs == 0) mNextFrameTimeMs = now + interval;
        while (now + 2 >= mNextFrameTimeMs) mNextFrameTimeMs += interval;
        mAnimationFrameRequest = emscripten_set_timeout(
            onFrameTimeout, std::max(mNextFrameTimeMs - now, 0.0), this);
    } else {
        mAnimationFrameRequest = emscripten_request_animation_frame(onAnimationFrame, this);
    }
}

void RenderManager::onFrameTimeout(void* manager) {
    onAnimationFrame(0, manager);
}

bool RenderManager::onAnimationFrame(double, void* manager) {
    auto* self = static_cast<RenderManager*>(manager);
    self->mAnimationFrameRequest = -1;
    // Use the same native steady clock as the other frame schedulers.
    const auto now = std::chrono::steady_clock::now();
    self->tick(std::chrono::duration_cast<std::chrono::nanoseconds>(
        now.time_since_epoch()).count());
    if (self->mFrameLoopRunning) {
        self->requestNextFrame();
    }
    return false;
}
#endif

} // namespace thermion
