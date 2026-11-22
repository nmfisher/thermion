#if __APPLE__
#include "TargetConditionals.h"
#endif

#ifdef _WIN32
#pragma comment(lib, "Ws2_32.lib")
#endif

#include <math/mat4.h>
#include <utils/EntityManager.h>
#include <utils/Panic.h>
#include <utils/Systrace.h>
#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#endif
#include <filament/Box.h>
#include <filament/Camera.h>
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndexBuffer.h>
#include <filament/IndirectLight.h>
#include <filament/LightManager.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <limits>
#include <map>

#include <backend/CallbackHandler.h>
#include <backend/PixelBufferDescriptor.h>

#include "Log.hpp"
#include "rendering/RenderManager.hpp"
#include "PluginAPI.hpp"

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace utils;

  using std::string;

  MaterialInstance *RenderManager::findMaterialOverrideLocked(const View *view) const
  {
    if (!view || mMaterialOverrides.empty()) {
      return nullptr;
    }
    for (const auto &entry : mMaterialOverrides) {
      if (entry.first == view) {
        return entry.second;
      }
    }
    return nullptr;
  }

  void RenderManager::setMaterialOverride(View *view, MaterialInstance *materialInstance)
  {
    if (!view) {
      return;
    }
    std::lock_guard lock(mMutex);
    auto it = std::find_if(mMaterialOverrides.begin(), mMaterialOverrides.end(),
                           [view](const std::pair<View *, MaterialInstance *> &entry)
                           { return entry.first == view; });
    if (materialInstance) {
      if (it != mMaterialOverrides.end()) {
        it->second = materialInstance;
      } else {
        mMaterialOverrides.emplace_back(view, materialInstance);
      }
    } else if (it != mMaterialOverrides.end()) {
      mMaterialOverrides.erase(it);
    }

    for (auto &va : mViewAttachments) {
      for (auto &slot : va.views) {
        if (slot.view == view) {
          slot.materialOverride = materialInstance;
        }
      }
    }
  }

  void RenderManager::renderViewWithMaterialOverrideLocked(
      View *view,
      MaterialInstance *materialOverride,
      bool standalone)
  {
    Scene *scene = view ? view->getScene() : nullptr;
    if (!mEngine || !mRenderer || !view || !scene || !materialOverride) {
      if (mRenderer && view) {
        if (standalone) {
          mRenderer->renderStandaloneView(view);
        } else {
          mRenderer->render(view);
        }
      }
      return;
    }

    auto &rm = mEngine->getRenderableManager();
    mSavedMaterials.clear();

    scene->forEach([&](utils::Entity entity) {
      if (!rm.hasComponent(entity)) {
        return;
      }
      auto ri = rm.getInstance(entity);
      if (!ri) {
        return;
      }
      const size_t primitiveCount = rm.getPrimitiveCount(ri);
      for (size_t p = 0; p < primitiveCount; ++p) {
        auto *original = rm.getMaterialInstanceAt(ri, p);
        if (original && std::strcmp(original->getMaterial()->getName(), "Skybox") == 0) {
          continue;
        }
        mSavedMaterials.push_back({ri, p, original});
        rm.setMaterialInstanceAt(ri, p, materialOverride);
      }
    });

    if (standalone) {
      mRenderer->renderStandaloneView(view);
    } else {
      mRenderer->render(view);
    }

    for (const auto &s : mSavedMaterials) {
      if (s.original) {
        rm.setMaterialInstanceAt(s.instance, s.primitiveIndex, s.original);
      } else {
        rm.clearMaterialInstanceAt(s.instance, s.primitiveIndex);
      }
    }
    mSavedMaterials.clear();
  }

  void RenderManager::renderView(View *view, bool standalone)
  {
    if (!mRenderer || !view) {
      return;
    }
    std::lock_guard lock(mMutex);
    if (auto *overrideMaterial = findMaterialOverrideLocked(view)) {
      renderViewWithMaterialOverrideLocked(view, overrideMaterial, standalone);
    } else if (standalone) {
      mRenderer->renderStandaloneView(view);
    } else {
      mRenderer->render(view);
    }
  }

  namespace
  {
    struct CaptureCompletionState
    {
      std::unique_ptr<RenderManager::CaptureResult> result;
      std::atomic<size_t> remaining{0};
      std::function<void(std::unique_ptr<RenderManager::CaptureResult>)> onComplete;
      std::shared_ptr<RenderManager::CapturePumpState> pumpState;
    };

    class CaptureReadbackHandler final : public filament::backend::CallbackHandler
    {
    public:
      explicit CaptureReadbackHandler(std::shared_ptr<CaptureCompletionState> state)
          : mState(std::move(state))
      {
      }

      ~CaptureReadbackHandler() override = default;

      void post(void *user, Callback callback) override
      {
        callback(user);
      }

      static void onBufferReady(void *, size_t, void *user)
      {
        std::shared_ptr<CaptureCompletionState> state;
        {
          std::unique_ptr<CaptureReadbackHandler> self(
              static_cast<CaptureReadbackHandler *>(user));
          if (self)
          {
            state = std::move(self->mState);
          }
        }
        if (!state)
        {
          return;
        }
        if (state->pumpState)
        {
          state->pumpState->pendingReadbacks.fetch_sub(1, std::memory_order_acq_rel);
        }
        if (state->remaining.fetch_sub(1, std::memory_order_acq_rel) == 1)
        {
          if (state->onComplete)
          {
            state->onComplete(std::move(state->result));
          }
        }
      }

    private:
      std::shared_ptr<CaptureCompletionState> mState;
    };
  } // namespace

  void RenderManager::removeSwapChain(SwapChain *swapChain)
  {
    std::lock_guard lock(mMutex);
    auto it = std::remove_if(mViewAttachments.begin(), mViewAttachments.end(),
                             [swapChain](const ViewAttachment &va)
                             { return va.swapChain == swapChain; });
    mViewAttachments.erase(it, mViewAttachments.end());
  }

  void RenderManager::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews)
  {
    std::lock_guard lock(mMutex);

    // Find existing entry for this swapchain
    ViewAttachment *attachment = nullptr;
    for (auto &va : mViewAttachments)
    {
      if (va.swapChain == swapChain)
      {
        attachment = &va;
        break;
      }
    }

    // Create new entry if not found
    if (!attachment)
    {
      mViewAttachments.push_back(ViewAttachment{});
      attachment = &mViewAttachments.back();
      attachment->swapChain = swapChain;
    }

    // Update views
    attachment->views.clear();
    if (views && numViews > 0)
    {
      attachment->views.reserve(numViews);
      for (size_t i = 0; i < numViews; i++)
      {
        if (!views[i])
        {
          LOG_ERROR("View attachment at %zu is nullptr, this is not expected", i);
          continue;
        }
        attachment->views.push_back({views[i], findMaterialOverrideLocked(views[i])});
      }
    }
    TRACE("Set %u view attachments for swapchain", numViews);
  }

  void RenderManager::updateAnimationsAndPlugins(uint64_t frameTimeInNanos)
  {
    for (auto animationManager : mAnimationManagers)
    {
      animationManager->update(frameTimeInNanos);
    }
    thermion::plugin::UpdatePlugins(frameTimeInNanos);
  }

  bool RenderManager::renderSwapChainAt(size_t index, uint64_t frameTimeInNanos)
  {
    if (index >= mViewAttachments.size()) return false;
    auto &attachment = mViewAttachments[index];
    if (!attachment.swapChain)
    {
      Log("No swapchain, ignoring");
      return false;
    }

    // Skip the entire begin/render/end cycle if no views are
    // attached. setRendering(false) and detach(view) both remove the
    // view from this entry's view list but leave the swap chain
    // entry behind for later reattachment, so we can land in this
    // function with the swap chain still in `mViewAttachments` but
    // nothing to render. Calling beginFrame / endFrame on a swap
    // chain that has no work is wasteful in single-viewer apps and
    // dangerous in multi-viewer ones: Filament's Renderer is
    // documented as one-Renderer-per-one-window, but Thermion shares
    // a single Renderer across every swap chain in the engine, so
    // its `mSwapChain` member gets set/cleared rapidly across the
    // iteration. An empty-views begin/end fires the same internal
    // state machine as a real frame, opening a window for the
    // SwapChain validity assertion at endFrame:490 to trip during
    // dispose / mount transitions.
    if (attachment.views.empty())
    {
      return false;
    }

    auto beforeBegin = std::chrono::high_resolution_clock::now();
    bool beginFrame = mRenderer->beginFrame(attachment.swapChain, frameTimeInNanos);
#ifdef __EMSCRIPTEN__
    // Filament 1.77.2 flushes its queued backend poll after rejecting admission.
    // Its single-threaded flush executes that work, so one retry can use fresh
    // fence state. Each attempt advances Filament's internal frame bookkeeping.
    if (!beginFrame) {
      beginFrame = mRenderer->beginFrame(attachment.swapChain, frameTimeInNanos);
    }
#endif
    auto afterBegin = std::chrono::high_resolution_clock::now();
    float beginMs = std::chrono::duration_cast<std::chrono::nanoseconds>(afterBegin - beforeBegin).count() / 1e6f;

    if (!beginFrame)
    {
      float sinceLastMs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                              std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
      TRACE("Skipping frame for swapchain %zu (%.3f ms since last endFrame())", index, sinceLastMs);
      (void)beginMs;
      return false;
    }

    float sinceLastMs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Beginning frame for swapchain %zu (%.3f ms since last endFrame())", index, sinceLastMs);

    int numRendered = 0;
    for (const auto &slot : attachment.views)
    {
      if (!slot.view) continue;
      numRendered++;
      if (slot.materialOverride) {
        renderViewWithMaterialOverrideLocked(slot.view, slot.materialOverride, false);
      } else {
        mRenderer->render(slot.view);
      }
    }

    auto beforeEnd = std::chrono::high_resolution_clock::now();
    mRenderer->endFrame();
    mLastRender = std::chrono::high_resolution_clock::now();
    float endFrameMs = std::chrono::duration_cast<std::chrono::nanoseconds>(mLastRender - beforeEnd).count() / 1e6f;

    TRACE("%d views rendered for swapchain %zu", numRendered, index);

    if (endFrameMs > 5.0f) {
      TRACE( "[RENDER] endFrame() took %.1fms (GPU stall?)\n", endFrameMs);
    }

    return numRendered > 0;
  }

  bool RenderManager::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();

    std::lock_guard lock(mMutex);

    updateAnimationsAndPlugins(frameTimeInNanos);

    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Updated animations in %.3f ms", durationNs);

    bool rendered = false;
    int skippedCount = 0;
    for (size_t i = 0; i < mViewAttachments.size(); i++)
    {
      if (renderSwapChainAt(i, frameTimeInNanos)) {
        rendered = true;
      } else if (mViewAttachments[i].swapChain) {
        skippedCount++;
      }
    }

    #ifdef __EMSCRIPTEN__
        mEngine->execute();
    #endif

    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time for %zu swapchains: %.3f ms", mViewAttachments.size(), durationMs);

    static int renderCount = 0;
    static int totalSkips = 0;
    static float maxRenderMs = 0;
    static float sumRenderMs = 0;
    renderCount++;
    totalSkips += skippedCount;
    if (durationMs > maxRenderMs) maxRenderMs = durationMs;
    sumRenderMs += durationMs;

    if (renderCount <= 3 || renderCount % 120 == 0) {
      float avgMs = sumRenderMs / (renderCount <= 3 ? renderCount : 120);
      TRACE( "[RENDER] #%d %.1fms (avg=%.1fms max=%.1fms) skips=%d rendered=%d\n",
              renderCount, durationMs, avgMs, maxRenderMs, totalSkips, rendered);
      if (renderCount > 3) {
        maxRenderMs = 0;
        sumRenderMs = 0;
        totalSkips = 0;
      }
    }
    return rendered;
  }

  void RenderManager::setPaused(bool paused)
  {
    // tick() resets the FPS gate. Pausing must not wait for mMutex.
    if (mRenderPaused.exchange(paused, std::memory_order_relaxed) != paused) {
      mResetFrameRateGate.store(true, std::memory_order_release);
    }
  }

  void RenderManager::setTargetFps(int fps)
  {
    mTargetFps.store(fps > 0 ? fps : 0, std::memory_order_relaxed);
  }

  void RenderManager::flushCommands()
  {
#ifdef __EMSCRIPTEN__
    mEngine->flush();
    mEngine->execute();
    mEngine->pumpMessageQueues();
#endif
  }

  bool RenderManager::tick(uint64_t frameTimeInNanos)
  {
    std::lock_guard<std::mutex> lock(mMutex);

    // Render unconditionally on every worker rAF. Dart's main-thread _tick
    // and this worker's mainLoop are independent rAFs that aren't
    // phase-locked. Gating on a main-thread request
    // drops ~5-10 fps whenever the worker rAF fires before Dart has had a
    // chance to set it.
    // Match pre-refactor RenderTicker semantics: render all swapchains
    // synchronously and ALWAYS call mEngine->execute() — even if every
    // beginFrame rejected or we're paused. Filament's WebGL backend queues
    // commands in an internal buffer that needs to be drained every rAF,
    // independent of whether a visible frame was produced. Skipping
    // execute() stalls the backend and causes a burst on resume.
    if (mResetFrameRateGate.exchange(false, std::memory_order_acquire)) {
      mFrameRateGate.reset();
    }
    bool anyRendered = false;
    if (!mRenderPaused.load(std::memory_order_relaxed) &&
        mFrameRateGate.admit(frameTimeInNanos, mTargetFps.load(std::memory_order_relaxed))) {
      updateAnimationsAndPlugins(frameTimeInNanos);

      for (size_t i = 0; i < mViewAttachments.size(); i++)
      {
        if (!mViewAttachments[i].swapChain) continue;
        if (renderSwapChainAt(i, frameTimeInNanos)) {
          anyRendered = true;
        }
      }
    }

#ifdef __EMSCRIPTEN__
    // Without a rendered frame there is no endFrame() to submit uploads.
    // Submit them before draining the backend, then deliver their release
    // callbacks even when no visible frame was rendered.
    if (!anyRendered) {
      mEngine->flush();
    }
    mEngine->execute();
    // TODO should this be called for non-web platforms too? Otherwise we need to wait for a frame to render
    // to handle user callbacks, which is risky when an application is paused as messages can pile up.
    mEngine->pumpMessageQueues();
#endif

    return anyRendered;
  }

  void RenderManager::addAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    mAnimationManagers.push_back(animationManager);
  }

  void RenderManager::removeAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    auto it = std::find(mAnimationManagers.begin(), mAnimationManagers.end(), animationManager);
    if (it != mAnimationManagers.end())
    {
      mAnimationManagers.erase(it);
    }
  }

  bool RenderManager::capture(
      SwapChain *swapChain,
      uint64_t frameTimeInNanos,
      bool render,
      const std::vector<CaptureViewRequest> &views,
      std::function<void(std::unique_ptr<CaptureResult>)> onComplete)
  {
    if (!mEngine || !mRenderer || !swapChain || views.empty())
    {
      return false;
    }

    std::vector<size_t> byteSizes;
    byteSizes.reserve(views.size());
    for (const auto &req : views)
    {
      if (!req.view || req.width == 0 || req.height == 0)
      {
        return false;
      }
      const size_t bpp = Texture::PixelBufferDescriptor::computePixelSize(req.format, req.type);
      if (bpp == 0)
      {
        return false;
      }
      const size_t w = static_cast<size_t>(req.width);
      const size_t h = static_cast<size_t>(req.height);
      if (w > std::numeric_limits<size_t>::max() / h)
      {
        return false;
      }
      const size_t pixelCount = w * h;
      if (pixelCount > std::numeric_limits<size_t>::max() / bpp)
      {
        return false;
      }
      const size_t totalBytes = pixelCount * bpp;
      if (totalBytes > std::numeric_limits<uint32_t>::max())
      {
        return false;
      }
      byteSizes.push_back(totalBytes);
    }

    auto state = std::make_shared<CaptureCompletionState>();
    state->result = std::make_unique<CaptureResult>();
    state->result->buffers.resize(views.size());
    for (size_t i = 0; i < views.size(); ++i)
    {
      state->result->buffers[i].resize(byteSizes[i]);
    }
    // Keep one extra count until after unlock() and initial pump so synchronous
    // readPixels completion cannot invoke onComplete while mMutex is held.
    state->remaining.store(views.size() + 1, std::memory_order_release);
    state->onComplete = std::move(onComplete);
    state->pumpState = mCapturePumpState;

    std::unique_lock<std::mutex> lock(mMutex);

    bool beginFrame = mRenderer->beginFrame(swapChain, frameTimeInNanos);
#ifdef __EMSCRIPTEN__
    if (!beginFrame)
    {
      beginFrame = mRenderer->beginFrame(swapChain, frameTimeInNanos);
    }
#endif
    if (!beginFrame)
    {
      return false;
    }

    mCapturePumpState->pendingReadbacks.fetch_add(
        static_cast<uint32_t>(views.size()), std::memory_order_acq_rel);

    for (size_t i = 0; i < views.size(); ++i)
    {
      const auto &req = views[i];
      if (render)
      {
        if (auto *overrideMaterial = findMaterialOverrideLocked(req.view))
        {
          renderViewWithMaterialOverrideLocked(req.view, overrideMaterial, false);
        }
        else
        {
          mRenderer->render(req.view);
        }
      }

      auto *handler = new CaptureReadbackHandler(state);
      auto pbd = Texture::PixelBufferDescriptor(
          state->result->buffers[i].data(),
          state->result->buffers[i].size(),
          req.format,
          req.type,
          1,
          0,
          0,
          0,
          handler,
          &CaptureReadbackHandler::onBufferReady,
          handler);

      if (req.renderTarget)
      {
        mRenderer->readPixels(req.renderTarget, 0, 0, req.width, req.height, std::move(pbd));
      }
      else
      {
        mRenderer->readPixels(0, 0, req.width, req.height, std::move(pbd));
      }
    }

    mRenderer->endFrame();
    mLastRender = std::chrono::high_resolution_clock::now();
    lock.unlock();

#ifdef __EMSCRIPTEN__
    mEngine->flush();
    mEngine->execute();
    mEngine->pumpMessageQueues();
#else
#if defined(THERMION_SUPPORTS_WEBGPU)
    // The WebGPU backend completes readPixels through Dawn buffer-map
    // callbacks, which only fire when Dawn processes its events. On native
    // (non-Emscripten) builds nothing pumps Dawn between frames — the
    // engine thread blocks in waitForCommands() after executing the frame —
    // so the readback below would stay pending forever and the capture
    // would never complete (observed as a hang on llvmpipe/lavapipe).
    //
    // Engine::flushAndWait() is the sanctioned pump: it dispatches
    // WebGPUDriver::finish(), which loops wgpuInstanceProcessEvents() until
    // every pending readback map has completed, then drains the scheduled
    // readback callbacks via Driver::purge(). By the time it returns, each
    // CaptureReadbackHandler::onBufferReady has run.
    if (state->remaining.load(std::memory_order_acquire) > 1)
    {
      mEngine->flushAndWait();
    }
#endif
#endif

    if (state->remaining.fetch_sub(1, std::memory_order_acq_rel) == 1)
    {
      if (state->onComplete)
      {
        state->onComplete(std::move(state->result));
      }
    }
#ifdef __EMSCRIPTEN__
    else if (mCapturePumpState->pendingReadbacks.load(std::memory_order_acquire) > 0)
    {
      scheduleCapturePump(0.0);
    }
#endif

    return true;
  }

  RenderManager::~RenderManager() {
    mCapturePumpState->alive.store(false, std::memory_order_release);
#ifdef __EMSCRIPTEN__
    stopFrameLoop();
    stopCapturePump();
#endif
  }

} // namespace thermion
