#include <array>
#include <algorithm>
#include <atomic>
#include <cstring>
#include <math/mat4.h>
#include <functional>
#include <mutex>
#include <memory>
#include <unordered_map>
#include <thread>
#include <stdlib.h>
#include <vector>
#ifdef __EMSCRIPTEN__
#include <unistd.h>
#include <mimalloc.h>
#endif

#include <filament/LightManager.h>
#include <filament/BufferObject.h>

#include "c_api/APIBoundaryTypes.h"
#include "c_api/TAnimationManager.h"
#include "c_api/TEngine.h"
#include "c_api/TRenderableManager.h"
#include "c_api/TTransformManager.h"
#include "c_api/TGizmo.h"
#include "c_api/TGltfAssetLoader.h"
#include "c_api/TGltfResourceLoader.h"
#include "c_api/TRenderer.h"
#include "c_api/TRenderManager.h"
#include "c_api/TRenderTarget.h"
#include "c_api/TScene.h"
#include "c_api/TSceneAsset.h"
#include "c_api/TFilamentAsset.h"
#include "c_api/TTexture.h"
#include "c_api/TView.h"
#include "c_api/TVertexBuffer.h"
#include "c_api/TIndexBuffer.h"
#include "c_api/TBufferObject.h"
#include "c_api/ThermionDartJobThreadApi.h"

#include "rendering/JobThread.hpp"
#include "rendering/RenderManager.hpp"
#include "Log.hpp"
#include "MathUtils.hpp"

#ifdef __EMSCRIPTEN__
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <emscripten/console.h>
#endif

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>
#include <cinttypes>

#ifdef __EMSCRIPTEN__
#define PROXY(call) rt->dispatchCallback([=]() { call; })
#else
#define PROXY(call) call
#endif
extern "C"
{

  // The app keeps this handle alive until its resources and queued jobs finish.
  // This map owns the threads. Resource handles are never used to choose a thread.
  std::unordered_map<TJobThread*, std::unique_ptr<JobThread>> _jobThreads;

  EMSCRIPTEN_KEEPALIVE TJobThread* JobThread_create()
  {
    auto thread = JobThread::create();
    if (!thread) {
      Log("JobThread worker failed to start; returning null handle");
      return nullptr;
    }
    auto* handle = reinterpret_cast<TJobThread*>(thread.get());
    _jobThreads[handle] = std::move(thread);
    return handle;
  }

  EMSCRIPTEN_KEEPALIVE TJobThread* JobThread_createForCanvas(const char *canvasSelector)
  {
    auto thread = JobThread::create(canvasSelector);
    if (!thread) {
      Log("JobThread worker failed to start for canvas %s; returning null handle", canvasSelector);
      return nullptr;
    }
    auto* handle = reinterpret_cast<TJobThread*>(thread.get());
    _jobThreads[handle] = std::move(thread);
    return handle;
  }

  EMSCRIPTEN_KEEPALIVE void JobThread_destroy(TJobThread *jobThread)
  {
    auto it = _jobThreads.find(jobThread);
    if (it != _jobThreads.end()) {
      auto thread = std::move(it->second);
      _jobThreads.erase(it);
      JobThread::destroy(std::move(thread));
    }
  }

  EMSCRIPTEN_KEEPALIVE void JobThread_addTask(TJobThread *jobThread, void (*task)())
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          task();
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_attachToJobThread(TJobThread *jobThread, TRenderManager *tRenderManager)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
#ifdef __EMSCRIPTEN__
    auto *rm = reinterpret_cast<RenderManager *>(tRenderManager);
    rt->addDetachedTask([rt, rm] {
      rt->setAfterBatchCallback([rm] { rm->flushCommands(); });
      rm->startFrameLoop();
    });
#endif
  }

  // Queue detachment without deleting the manager. Await queued destruction
  // before freeing engine resources used by the manager.
  EMSCRIPTEN_KEEPALIVE void RenderManager_detachFromJobThread(TJobThread *jobThread, TRenderManager *tRenderManager)
  {
#ifdef __EMSCRIPTEN__
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    if (rt) {
      auto* rm = reinterpret_cast<RenderManager*>(tRenderManager);
      rt->addDetachedTask([rt, rm] {
        rm->stopFrameLoop();
        rt->setAfterBatchCallback({});
      });
    }
#else
    (void)jobThread;
    (void)tRenderManager; // no-op on native
#endif
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_destroyJobThread(TJobThread *jobThread,
      TRenderManager* manager, uint32_t requestId, VoidCallback onComplete)
  {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    rt->addDetachedTask([=] {
#ifdef __EMSCRIPTEN__
      rt->setAfterBatchCallback({});
#endif
      RenderManager_destroy(manager);
      PROXY(onComplete(requestId));
    });
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderableJobThread(TJobThread *jobThread,
    TRenderManager *tRenderer,
    TSwapChain *tSwapChain,
    TView **tViews,
    uint8_t numViews,
    uint32_t requestId, VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);

      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_setRenderable(tRenderer, tSwapChain, tViews, numViews);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);

    }

  EMSCRIPTEN_KEEPALIVE void RenderManager_renderJobThread(TJobThread *jobThread,
    TRenderManager *tRenderManager,
    uint64_t frameTimeInNanos,
    uint32_t requestId,
    VoidCallback onComplete)
  {
#if defined(__EMSCRIPTEN__) && !defined(THERMION_WEB_MAIN_THREAD)
    // The worker already draws on its own rAF. Preserve the web render()
    // no-op without putting another frame or callback on its task queue.
    onComplete(requestId);
#else
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    auto queuedAt = std::chrono::steady_clock::now();
    rt->addDetachedTask([=]() mutable {
      auto startedAt = std::chrono::steady_clock::now();
      float queueMs = std::chrono::duration_cast<std::chrono::nanoseconds>(startedAt - queuedAt).count() / 1e6f;
#if defined(__EMSCRIPTEN__) && defined(THERMION_WEB_MAIN_THREAD)
      reinterpret_cast<RenderManager*>(tRenderManager)->tick(frameTimeInNanos);
#else
      RenderManager_render(tRenderManager, frameTimeInNanos);
#endif
      static int cbCount = 0;
      cbCount++;
      if (queueMs > 5.0f) {
        TRACE("[QUEUE] render waited %.1fms in queue\n", queueMs);
      }
      if (cbCount <= 3 || cbCount % 300 == 0) {
        TRACE("[RenderCB] #%d completing requestId=%u queueWait=%.1fms\n", cbCount, requestId, queueMs);
      }
      PROXY(onComplete(requestId));
    });
#endif
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManagerJobThread(TJobThread *jobThread,
    TRenderManager *tRenderManager,
    TAnimationManager *tAnimationManager,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_addAnimationManager(tRenderManager, tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManagerJobThread(TJobThread *jobThread,
    TRenderManager *tRenderManager,
    TAnimationManager *tAnimationManager,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_removeAnimationManager(tRenderManager, tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChainJobThread(TJobThread *jobThread,
    TRenderManager *tRenderManager,
    TSwapChain *tSwapChain,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_removeSwapChain(tRenderManager, tSwapChain);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createJobThread(TJobThread *jobThread,
      TBackend backend,
      void *platform,
      void *sharedContext,
      uint8_t stereoscopicEyeCount,
      bool disableHandleUseAfterFreeCheck,
      void (*onComplete)(TEngine *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *engine = Engine_create(backend, platform, sharedContext, stereoscopicEyeCount, disableHandleUseAfterFreeCheck);

          PROXY(onComplete(engine));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRendererJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TRenderer *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *renderer = Engine_createRenderer(tEngine);

          PROXY(onComplete(renderer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createSwapChain(tEngine, window, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createHeadlessSwapChain(tEngine, width, height, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySwapChain(tEngine, tSwapChain);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyRendererJobThread(TJobThread *jobThread, TEngine *tEngine, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyRenderer(tEngine, tRenderer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyViewJobThread(TJobThread *jobThread, TEngine *tEngine, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyView(tEngine, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySceneJobThread(TJobThread *jobThread, TEngine *tEngine, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyScene(tEngine, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createCameraJobThread(TJobThread *jobThread, TEngine *tEngine, EntityId entityId, void (*onComplete)(TCamera *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto camera = Engine_createCamera(tEngine, entityId);

          PROXY(onComplete(camera));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyCameraJobThread(TJobThread *jobThread, TEngine *tEngine, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyCamera(tEngine, tCamera);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createViewJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TView *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *view = Engine_createView(tEngine);

          PROXY(onComplete(view));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroy(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureJobThread(TJobThread *jobThread, TEngine *engine, TTexture *tTexture, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyTexture(engine, tTexture);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySkybox(tEngine, tSkybox);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightJobThread(TJobThread *jobThread, TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyIndirectLight(tEngine, tIndirectLight);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Snapshot borrowed FFI storage before returning to Dart. The task owns it.
    std::vector<uint8_t> owned;
    if (length != 0) owned.assign(materialData, materialData + length);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          auto material = Engine_buildMaterial(tEngine, owned.data(), length);

          if (material) {
          }
          PROXY(onComplete(material));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterial(tEngine, tMaterial);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceJobThread(TJobThread *jobThread, TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterialInstance(tEngine, tMaterialInstance);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createFenceJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TFence *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *fence = Engine_createFence(tEngine);

          PROXY(onComplete(fence));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyJobThread(TJobThread *jobThread, TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Fence_waitAndDestroy(tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceJobThread(TJobThread *jobThread, TEngine *tEngine, TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyFence(tEngine, tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_flushAndWait(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_executeJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_execute(tEngine);
          std::packaged_task<void()> callback(
          [=]() mutable
          { 
            PROXY(onComplete(requestId));
          });
          rt->addTask(callback);
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void execute_queue()
  {
#ifdef __EMSCRIPTEN__
    JobThread::executeCallbacks();
#endif
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *skybox = Engine_buildSkybox(tEngine, tTexture, showSun, intensity, priority);
          PROXY(onComplete(skybox));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *skybox = Engine_buildColoredSkybox(tEngine, r, g, b, a, showSun, intensity, priority);
          PROXY(onComplete(skybox));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureJobThread(TJobThread *jobThread,
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    TTexture* tIrradianceTexture,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceTexture(tEngine, tReflectionsTexture, tIrradianceTexture, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = rt->addTask(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsJobThread(TJobThread *jobThread,
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    float *harmonics,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
      // Nine RGB coefficients fit in the task itself; no heap buffer is needed.
      std::array<float, 27> owned{};
      const bool hasHarmonics = harmonics != nullptr;
      if (hasHarmonics) std::copy_n(harmonics, owned.size(), owned.data());
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceHarmonics(tEngine, tReflectionsTexture, hasHarmonics ? owned.data() : nullptr, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameJobThread(TJobThread *jobThread, TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = Renderer_beginFrame(tRenderer, tSwapChain, frameTimeInNanos);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void Renderer_endFrameJobThread(TJobThread *jobThread, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_endFrame(tRenderer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderJobThread(TJobThread *jobThread, TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_render(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewJobThread(TJobThread *jobThread, TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_renderStandaloneView(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsJobThread(TJobThread *jobThread,
      TRenderer *tRenderer,
      double clearR,
      double clearG,
      double clearB,
      double clearA,
      uint8_t clearStencil,
      bool clear,
      bool discard, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_setClearOptions(tRenderer, clearR, clearG, clearB, clearA, clearStencil, clear, discard);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsJobThread(TJobThread *jobThread,
      TRenderer *tRenderer,
      uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
      TRenderTarget *tRenderTarget,
      TPixelDataFormat tPixelBufferFormat,
      TPixelDataType tPixelDataType,
      uint8_t *out,
      size_t outLength,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_readPixels(tRenderer, width, height, xOffset, yOffset, tRenderTarget, tPixelBufferFormat, tPixelDataType, out, outLength);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createImageMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createGizmoMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createSilhouetteMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createSilhouetteMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createEdgeOutlineMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createEdgeOutlineMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createWireframeMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createWireframeMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createTranslationAxisMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createTranslationAxisMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createBoneOverlayMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createBoneOverlayMaterial(tEngine);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createInstanceJobThread(TJobThread *jobThread, TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createInstance(tMaterial);

          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTextureJobThread(TJobThread *jobThread,
      TMaterialInstance *tMaterialInstance,
      const char *propertyName,
      TTexture* tTexture,
      TTextureSampler* tSampler,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          MaterialInstance_setParameterTexture(tMaterialInstance, propertyName, tTexture, tSampler);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_destroy(tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      TNameComponentManager *tNameComponentManager,
      TFilamentAsset *tFilamentAsset,
      uint32_t requiredGeometryCapabilities,
      void (*onComplete)(TSceneAsset *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto sceneAsset = SceneAsset_createFromFilamentAsset(
              tEngine, tAssetLoader, tNameComponentManager, tFilamentAsset,
              requiredGeometryCapabilities);

          PROXY(onComplete(sceneAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromBuffersJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TVertexBuffer *tVertexBuffer,
      TIndexBuffer *tIndexBuffer,
      TMaterialInstance **materialInstances,
      int materialInstanceCount,
      TPrimitiveType tPrimitiveType,
      TVertexBufferStorageMode vertexBufferStorageMode,
      Aabb3 boundingBox,
      void (*callback)(TSceneAsset *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy the handle array; the native objects retain their existing lifetimes.
    std::vector<TMaterialInstance*> owned;
    if (materialInstanceCount > 0) owned.assign(materialInstances, materialInstances + materialInstanceCount);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          auto sceneAsset = SceneAsset_createFromBuffers(
              tEngine,
              tVertexBuffer,
              tIndexBuffer,
              owned.data(),
              materialInstanceCount,
              tPrimitiveType,
              vertexBufferStorageMode,
              boundingBox);

          PROXY(callback(sceneAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceJobThread(TJobThread *jobThread,
      TSceneAsset *asset, TMaterialInstance **tMaterialInstances,
      int materialInstanceCount,
      void (*callback)(TSceneAsset *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy the handle array; the native objects retain their existing lifetimes.
    std::vector<TMaterialInstance*> owned;
    if (materialInstanceCount > 0) owned.assign(tMaterialInstances, tMaterialInstances + materialInstanceCount);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          auto instanceAsset = SceneAsset_createInstance(asset, owned.data(), materialInstanceCount);

          PROXY(callback(instanceAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceDataJobThread(TJobThread *jobThread,
      TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_releaseSourceData(tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShadingJobThread(TJobThread *jobThread,
      TSceneAsset *tSceneAsset, bool flatShading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_setFlatShading(tSceneAsset, flatShading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceJobThread(TJobThread *jobThread,
      TMaterialProvider *tMaterialProvider,
      bool doubleSided,
      bool unlit,
      bool hasVertexColors,
      bool hasBaseColorTexture,
      bool hasNormalTexture,
      bool hasOcclusionTexture,
      bool hasEmissiveTexture,
      bool useSpecularGlossiness,
      int alphaMode,
      bool enableDiagnostics,
      bool hasMetallicRoughnessTexture,
      uint8_t metallicRoughnessUV,
      bool hasSpecularGlossinessTexture,
      uint8_t specularGlossinessUV,
      uint8_t baseColorUV,
      bool hasClearCoatTexture,
      uint8_t clearCoatUV,
      bool hasClearCoatRoughnessTexture,
      uint8_t clearCoatRoughnessUV,
      bool hasClearCoatNormalTexture,
      uint8_t clearCoatNormalUV,
      bool hasClearCoat,
      bool hasTransmission,
      bool hasTextureTransforms,
      uint8_t emissiveUV,
      uint8_t aoUV,
      uint8_t normalUV,
      bool hasTransmissionTexture,
      uint8_t transmissionUV,
      bool hasSheenColorTexture,
      uint8_t sheenColorUV,
      bool hasSheenRoughnessTexture,
      uint8_t sheenRoughnessUV,
      bool hasVolumeThicknessTexture,
      uint8_t volumeThicknessUV,
      bool hasSheen,
      bool hasIOR,
      bool hasVolume,
      void (*callback)(TMaterialInstance *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto materialInstance = MaterialProvider_createMaterialInstance(
              tMaterialProvider,
              doubleSided,
              unlit,
              hasVertexColors,
              hasBaseColorTexture,
              hasNormalTexture,
              hasOcclusionTexture,
              hasEmissiveTexture,
              useSpecularGlossiness,
              alphaMode,
              enableDiagnostics,
              hasMetallicRoughnessTexture,
              metallicRoughnessUV,
              hasSpecularGlossinessTexture,
              specularGlossinessUV,
              baseColorUV,
              hasClearCoatTexture,
              clearCoatUV,
              hasClearCoatRoughnessTexture,
              clearCoatRoughnessUV,
              hasClearCoatNormalTexture,
              clearCoatNormalUV,
              hasClearCoat,
              hasTransmission,
              hasTextureTransforms,
              emissiveUV,
              aoUV,
              normalUV,
              hasTransmissionTexture,
              transmissionUV,
              hasSheenColorTexture,
              sheenColorUV,
              hasSheenRoughnessTexture,
              sheenRoughnessUV,
              hasVolumeThicknessTexture,
              volumeThicknessUV,
              hasSheen,
              hasIOR,
              hasVolume);
          PROXY(callback(materialInstance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_createJobThread(TJobThread *jobThread, void (*onComplete)(TColorGradingBuilder *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *builder = ColorGradingBuilder_create();

          PROXY(onComplete(builder));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_buildJobThread(TJobThread *jobThread, TColorGradingBuilder *tBuilder, TEngine *tEngine, void (*onComplete)(TColorGrading *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *colorGrading = ColorGradingBuilder_build(tBuilder, tEngine);
          PROXY(onComplete(colorGrading));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroyJobThread(TJobThread *jobThread, TColorGradingBuilder *tBuilder, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          ColorGradingBuilder_destroy(tBuilder);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createLinearJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createLinear(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createACES(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESLegacyJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createACESLegacy(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createFilmicJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createFilmic(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createPBRNeutralJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createPBRNeutral(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createAGX(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXWithLookJobThread(TJobThread *jobThread, TEngine *tEngine, int look, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createAGXWithLook(tEngine, look);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createGenericJobThread(TJobThread *jobThread, TEngine *tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createGeneric(tEngine, contrast, midGrayIn, midGrayOut, hdrMax);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createDisplayRangeJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createDisplayRange(tEngine);

          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_destroyJobThread(TJobThread *jobThread, TToneMapper *tToneMapper, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          ToneMapper_destroy(tToneMapper);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingJobThread(TJobThread *jobThread, TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          Engine_destroyColorGrading(tEngine, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_pickJobThread(TJobThread *jobThread, TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    auto *view = reinterpret_cast<View *>(tView);
    view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
               { PROXY(callback(requestId, utils::Entity::smuggle(result.renderable), result.depth, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z)); });
  }

  EMSCRIPTEN_KEEPALIVE void View_setColorGradingJobThread(TJobThread *jobThread, TView *tView, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setColorGrading(tView, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBloomJobThread(TJobThread *jobThread, TView *tView, bool enabled, double strength, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBloom(tView, enabled, strength);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setCameraJobThread(TJobThread *jobThread, TView *tView, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setCamera(tView, tCamera);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_getNameJobThread(TJobThread *jobThread, TView *tView, char *buffer, size_t capacity, void (*onComplete)(size_t))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          const auto *name = View_getName(tView);
          size_t requiredBytes = 0;
          if (name != nullptr) {
            requiredBytes = std::strlen(name) + 1;
            if (capacity >= requiredBytes) {
              std::memcpy(buffer, name, requiredBytes);
            }
          }
          PROXY(onComplete(requiredBytes));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setNameJobThread(TJobThread *jobThread, TView *tView, const char *name, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setName(tView, name);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setViewportJobThread(TJobThread *jobThread, TView *tView, uint32_t width, uint32_t height, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setViewport(tView, width, height);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setRenderTargetJobThread(TJobThread *jobThread, TView *tView, TRenderTarget *tRenderTarget, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setRenderTarget(tView, tRenderTarget);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setAntiAliasingJobThread(TJobThread *jobThread, TView *tView, bool msaa, bool fxaa, bool taa, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setAntiAliasing(tView, msaa, fxaa, taa);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setPostProcessingJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setPostProcessing(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFrustumCullingEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setStencilBufferEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setDitheringEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setRenderQualityJobThread(TJobThread *jobThread, TView *tView, int qualityLevel, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setRenderQuality(tView, static_cast<TQualityLevel>(qualityLevel));
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setSceneJobThread(TJobThread *jobThread, TView *tView, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setScene(tView, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setLayerEnabledJobThread(TJobThread *jobThread, TView *tView, int layer, bool visible, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setLayerEnabled(tView, layer, visible);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBlendModeJobThread(TJobThread *jobThread, TView *tView, int blendMode, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBlendMode(tView, static_cast<TBlendMode>(blendMode));
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFogOptionsJobThread(TJobThread *jobThread, TView *tView, TFogOptions tFogOptions, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFogOptions(tView, tFogOptions);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptionsJobThread(TJobThread *jobThread, TView *tView, TAmbientOcclusionOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setAmbientOcclusionOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInvertedJobThread(TJobThread *jobThread, TView *tView, bool inverted, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFrontFaceWindingInverted(tView, inverted);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setShadowsEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setShadowTypeJobThread(TJobThread *jobThread, TView *tView, int shadowType, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setShadowType(tView, shadowType);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptionsJobThread(TJobThread *jobThread, TView *tView, TSoftShadowOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setSoftShadowOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptionsJobThread(TJobThread *jobThread, TView *tView, TVsmShadowOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setVsmShadowOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setTransparentPickingEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_resetToRestPose(tAnimationManager, tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_createJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TAnimationManager *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *animationManager = AnimationManager_create(tEngine);

          PROXY(onComplete(animationManager));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_destroyJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_destroy(tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_updateJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_update(tAnimationManager, frameTimeInNanos);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  // setGltfAnimationTime applies morph-target channels via the backend
  // CommandStream, which asserts it runs on the render thread. Unlike every
  // sibling animation mutator, the plain AnimationManager_setGltfAnimationTime
  // dispatched synchronously on the caller's thread and panicked for morph
  // animations — this wrapper runs it on the render thread like the others.
  EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationTimeJobThread(TJobThread *jobThread,
      TAnimationManager *tAnimationManager,
      TSceneAsset *tSceneAsset,
      int animationIndex,
      float timeInSeconds,
      uint32_t requestId,
      VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_setGltfAnimationTime(tAnimationManager, tSceneAsset, animationIndex, timeInSeconds);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesJobThread(TJobThread *jobThread,
      TAnimationManager *tAnimationManager,
      TSceneAsset *sceneAsset,
      void (*callback)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = AnimationManager_updateBoneMatrices(tAnimationManager, sceneAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsJobThread(TJobThread *jobThread,
      TAnimationManager *tAnimationManager,
      EntityId entityId,
      const float *const morphData,
      int numWeights,
      void (*callback)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    const bool valid = numWeights >= 0 && (numWeights == 0 || morphData != nullptr);
    std::vector<float> weights;
    if (valid && numWeights > 0) {
      weights.assign(morphData, morphData + numWeights);
    }
    std::packaged_task<void()> lambda(
        [=, weights = std::move(weights)]() mutable
        {
          const bool result = valid && (weights.empty() ||
              AnimationManager_setMorphTargetWeights(
                  tAnimationManager, entityId, weights.data(), static_cast<int>(weights.size())));
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_createEmptyJobThread(TJobThread *jobThread, uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_createEmpty(width, height, channel);

          PROXY(onComplete(image));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_decodeJobThread(TJobThread *jobThread, uint8_t *data, size_t length, const char *name, bool alpha, void (*onComplete)(TLinearImage *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_decode(data, length, name, alpha);

          PROXY(onComplete(image));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getBytesJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(float *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto bytes = Image_getBytes(tLinearImage);
          PROXY(onComplete(bytes));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_destroyJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Image_destroy(tLinearImage);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getWidthJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto width = Image_getWidth(tLinearImage);
          PROXY(onComplete(width));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getHeightJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto height = Image_getHeight(tLinearImage);
          PROXY(onComplete(height));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getChannelsJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto channels = Image_getChannels(tLinearImage);
          PROXY(onComplete(channels));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_buildJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      uint32_t width,
      uint32_t height,
      uint32_t depth,
      uint8_t levels,
      uint16_t tUsage,
      intptr_t import,
      TTextureSamplerType sampler,
      TTextureFormat format, void (*onComplete)(TTexture *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *texture = Texture_build(tEngine, width, height, depth, levels, tUsage, import, sampler, format);

          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setExternalImageJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tTexture, void *externalImage, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Texture_setExternalImage(tEngine, tTexture, externalImage);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsJobThread(TJobThread *jobThread, TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Texture_generateMipMaps(tTexture, tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  #ifdef EMSCRIPTEN
  static std::unordered_map<uint32_t, std::function<void(int32_t)>> _emscriptenWrappers;

  EMSCRIPTEN_KEEPALIVE static void Emscripten_voidCallback(int32_t requestId) {
      Log("Emscripten_voidCallback: requestId %d", requestId);

      auto it = _emscriptenWrappers.find(requestId);
      if (it != _emscriptenWrappers.end()) {
          it->second(requestId);
          _emscriptenWrappers.erase(it);
      } else {
        Log("SEVERE: failed to find request id %d", requestId);
      }
  }
  #endif

  
  // Web callers must go through this variant — Ktx2Reader::load reaches into
  // Filament Engine state (Texture::Builder().build, internal job queues) and
  // those calls assert / abort when invoked from anywhere except the engine's
  // render thread. We also copy the input bytes synchronously here so the
  // lambda doesn't dangle when data was stack-allocated by the caller (the
  // ffigen_js Uint8List.address path uses stackAlloc for buffers < 32KB).
  EMSCRIPTEN_KEEPALIVE void Ktx2Reader_createTextureJobThread(TJobThread *jobThread,
    TEngine *tEngine, uint8_t* data, size_t size, void (*onComplete)(TTexture *)) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::vector<uint8_t> bytes(data, data + size);
    std::packaged_task<void()> lambda(
        [tEngine, bytes = std::move(bytes), onComplete, rt]() mutable
        {
          auto *texture = Ktx2Reader_createTexture(tEngine, bytes.data(), bytes.size());
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureJobThread(TJobThread *jobThread,
    TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *)) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);

      #ifdef EMSCRIPTEN
        if(onTextureUploadComplete) {
            _emscriptenWrappers[requestId] = [=](int32_t requestId) {
                PROXY(onTextureUploadComplete(requestId));
            };
        }
      #endif
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          #ifdef EMSCRIPTEN
            auto *texture = Ktx1Reader_createTexture(tEngine, tBundle, requestId, onTextureUploadComplete ? Emscripten_voidCallback : nullptr);
          #else
            auto *texture = Ktx1Reader_createTexture(tEngine, tBundle, requestId, onTextureUploadComplete);
          #endif
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Texture_loadImageJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage,
                                                          TPixelDataFormat bufferFormat, TPixelDataType pixelDataType,
                                                          int level,
                                                          void (*onComplete)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_loadImage(tEngine, tTexture, tImage, bufferFormat, pixelDataType, level);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setImageJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TTexture *tTexture,
      uint32_t level,
      uint8_t *data,
      size_t size,
      uint32_t x_offset,
      uint32_t y_offset,
      uint32_t z_offset,
      uint32_t width,
      uint32_t height,
      uint32_t depth,
      uint32_t bufferFormat,
      uint32_t pixelDataType,
      void (*onComplete)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy borrowed Dart pixels once, before returning from this FFI call.
    auto *buffer = new uint8_t[size];
    if (size != 0) std::copy_n(data, size, buffer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_setImage(
              tEngine,
              tTexture,
              level,
              buffer,
              size,
              x_offset,
              y_offset,
              z_offset,
              width,
              height,
              depth,
              bufferFormat,
              pixelDataType,
              [](void *pixels, size_t, void *) {
                delete[] static_cast<uint8_t*>(pixels);
              }, nullptr);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureJobThread(TJobThread *jobThread, TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_getColorTexture(tRenderTarget);
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_createJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TTexture *tColor,
      TTexture *tDepth,
      void (*onComplete)(TRenderTarget *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    auto color = reinterpret_cast<filament::Texture *>(tColor);
    auto depth = reinterpret_cast<filament::Texture *>(tDepth);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_create(tEngine, tColor, tDepth);

          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TRenderTarget *tRenderTarget,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderTarget_destroy(tEngine, tRenderTarget);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createJobThread(TJobThread *jobThread, void (*onComplete)(TTextureSampler *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_create();

          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringJobThread(TJobThread *jobThread,
      TSamplerMinFilter minFilter,
      TSamplerMagFilter magFilter,
      TSamplerWrapMode wrapS,
      TSamplerWrapMode wrapT,
      TSamplerWrapMode wrapR,
      void (*onComplete)(TTextureSampler *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithFiltering(minFilter, magFilter, wrapS, wrapT, wrapR);

          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonJobThread(TJobThread *jobThread,
      TSamplerCompareMode compareMode,
      TSamplerCompareFunc compareFunc,
      void (*onComplete)(TTextureSampler *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithComparison(compareMode, compareFunc);

          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerMinFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMinFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerMagFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMagFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeS(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeT(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeR(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      double anisotropy,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setAnisotropy(sampler, anisotropy);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      TSamplerCompareMode mode,
      TTextureSamplerCompareFunc func,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setCompareMode(sampler, mode, func);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyJobThread(TJobThread *jobThread,
      TTextureSampler *sampler,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_destroy(sampler);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createJobThread(TJobThread *jobThread,
    TEngine *tEngine,
    TMaterialProvider *tMaterialProvider,
    TNameComponentManager *tNameComponentManager,
    void (*callback)(TGltfAssetLoader *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_create(tEngine, tMaterialProvider, tNameComponentManager);

          PROXY(callback(loader));
      });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_destroyJobThread(TJobThread *jobThread,
    TGltfAssetLoader *tAssetLoader,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        GltfAssetLoader_destroy(tAssetLoader);
        PROXY(onComplete(requestId));
      });
    auto fut = rt->addTask(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createJobThread(TJobThread *jobThread, TEngine *tEngine, void (*callback)(TGltfResourceLoader *)) {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfResourceLoader_create(tEngine);

          PROXY(callback(loader));
      });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyJobThread(TJobThread *jobThread, TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_destroy(tEngine, tResourceLoader);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_loadResources(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataJobThread(TJobThread *jobThread,
      TGltfResourceLoader *tGltfResourceLoader,
      const char *uri,
      uint8_t *data,
      size_t length,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy borrowed Dart bytes before returning from this FFI call.
    std::vector<uint8_t> owned(data, data + length);
    std::string ownedUri(uri);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned), ownedUri = std::move(ownedUri)]() mutable
        {
          // Move the snapshot into storage that outlives this task. Filament's
          // release callback deletes it when Filament releases the resource bytes.
          auto *buffer = new std::vector<uint8_t>(std::move(owned));
          GltfResourceLoader_addResourceData(
              tGltfResourceLoader, ownedUri.c_str(), buffer->data(), buffer->size(),
              [](void *, size_t, void *userData) {
                delete static_cast<std::vector<uint8_t>*>(userData);
              }, buffer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadJobThread(TJobThread *jobThread,
      TGltfResourceLoader *tGltfResourceLoader,
      TFilamentAsset *tFilamentAsset,
      void (*callback)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncBeginLoad(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadJobThread(TJobThread *jobThread,
      TGltfResourceLoader *tGltfResourceLoader)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_asyncUpdateLoad(tGltfResourceLoader);
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressJobThread(TJobThread *jobThread,
      TGltfResourceLoader *tGltfResourceLoader,
      void (*callback)(float))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncGetLoadProgress(tGltfResourceLoader);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      uint8_t *data,
      size_t length,
      uint32_t numInstances,
      void (*callback)(TFilamentAsset *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Snapshot borrowed FFI storage before returning to Dart. The task owns it.
    std::vector<uint8_t> owned;
    if (length != 0) owned.assign(data, data + length);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          auto loader = GltfAssetLoader_load(tEngine, tAssetLoader, owned.data(), length, numInstances);

          PROXY(callback(loader));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetJobThread(TJobThread *jobThread, TScene *tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_addFilamentAsset(tScene, tAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void FilamentAsset_getWireframeJobThread(TJobThread *jobThread, TFilamentAsset *tFilamentAsset, void (*onComplete)(EntityId))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto entityId = FilamentAsset_getWireframe(tFilamentAsset);
          PROXY(onComplete(entityId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addEntityJobThread(TJobThread *jobThread, TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_addEntity(tScene, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_removeEntityJobThread(TJobThread *jobThread, TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_removeEntity(tScene, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_addToSceneJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_addToScene(tSceneAsset, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromSceneJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_removeFromScene(tSceneAsset, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_setSkyboxJobThread(TJobThread *jobThread, TScene *tScene, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_setSkybox(tScene, tSkybox);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLightJobThread(TJobThread *jobThread, TScene *tScene, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_setIndirectLight(tScene, tIndirectLight);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Gizmo_createJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      TGltfResourceLoader *tGltfResourceLoader,
      TNameComponentManager *tNameComponentManager,
      TView *tView,
      TMaterial *tMaterial,
      TGizmoType tGizmoType,
      void (*callback)(TGizmo *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *gizmo = Gizmo_create(tEngine, tAssetLoader, tGltfResourceLoader, tNameComponentManager, tView, tMaterial, tGizmoType);

          PROXY(callback(gizmo));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_buildJobThread(TJobThread *jobThread,
      TVertexBufferBuilder *tBuilder,
      TEngine *tEngine,
      void (*onComplete)(TVertexBuffer *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *vertexBuffer = VertexBufferBuilder_build(tBuilder, tEngine);

          PROXY(onComplete(vertexBuffer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroyJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TVertexBuffer *tBuffer,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          VertexBuffer_destroy(tEngine, tBuffer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAtJobThread(TJobThread *jobThread,
      TEngine* tEngine,
      TVertexBuffer* tBuffer,
      uint8_t bufferIndex,
      void* data,
      size_t sizeInBytes,
      uint32_t byteOffset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy data using std::vector to ensure it remains valid after the function returns
    auto *buffer = new std::vector<uint8_t>(sizeInBytes);
    std::copy(static_cast<uint8_t*>(data), static_cast<uint8_t*>(data) + sizeInBytes, buffer->begin());

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          // Create a BufferDescriptor with a callback to delete the vector
          VertexBuffer::BufferDescriptor bufferDescriptor(
              buffer->data(),
              buffer->size(),
              [](void* buffer, size_t size, void* user) {
                delete reinterpret_cast<std::vector<uint8_t>*>(user);
              },
              buffer
          );

          // Call the original setBufferAt with our BufferDescriptor
          auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
          auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);
          vertexBuffer->setBufferAt(*engine, bufferIndex, std::move(bufferDescriptor), byteOffset);

          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferObjectAtJobThread(TJobThread *jobThread,
      TEngine* tEngine,
      TVertexBuffer* tBuffer,
      uint8_t bufferIndex,
      TBufferObject* tBufferObject,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda([=]() mutable {
      VertexBuffer_setBufferObjectAt(tEngine, tBuffer, bufferIndex, tBufferObject);
      PROXY(onComplete(requestId));
    });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_buildJobThread(TJobThread *jobThread,
      TBufferObjectBuilder* tBuilder,
      TEngine* tEngine,
      void (*onComplete)(TBufferObject*))
  {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda([=]() mutable {
      auto* buffer = BufferObjectBuilder_build(tBuilder, tEngine);
      PROXY(onComplete(buffer));
    });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void BufferObject_setBufferJobThread(TJobThread *jobThread,
      TEngine* tEngine,
      TBufferObject* tBuffer,
      void* data,
      size_t sizeInBytes,
      uint32_t byteOffset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    auto* copy = new std::vector<uint8_t>(sizeInBytes);
    std::copy(static_cast<uint8_t*>(data), static_cast<uint8_t*>(data) + sizeInBytes, copy->begin());
    std::packaged_task<void()> lambda([=]() mutable {
      auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
      auto* buffer = reinterpret_cast<filament::BufferObject*>(tBuffer);
      buffer->setBuffer(
          *engine,
          filament::BufferObject::BufferDescriptor(
              copy->data(),
              copy->size(),
              [](void*, size_t, void* user) {
                delete reinterpret_cast<std::vector<uint8_t>*>(user);
              },
              copy),
          byteOffset);
      PROXY(onComplete(requestId));
    });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void BufferObject_destroyJobThread(TJobThread *jobThread,
      TEngine* tEngine,
      TBufferObject* tBuffer,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda([=]() mutable {
      BufferObject_destroy(tEngine, tBuffer);
      PROXY(onComplete(requestId));
    });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_buildJobThread(TJobThread *jobThread,
      TIndexBufferBuilder *tBuilder,
      TEngine *tEngine,
      void (*onComplete)(TIndexBuffer *))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *indexBuffer = IndexBufferBuilder_build(tBuilder, tEngine);

          PROXY(onComplete(indexBuffer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroyJobThread(TJobThread *jobThread,
      TEngine *tEngine,
      TIndexBuffer *tBuffer,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          IndexBuffer_destroy(tEngine, tBuffer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBufferJobThread(TJobThread *jobThread,
      TEngine* tEngine,
      TIndexBuffer* tBuffer,
      void* data,
      size_t sizeInBytes,
      uint32_t byteOffset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Copy data using std::vector to ensure it remains valid after the function returns
    auto *buffer = new std::vector<uint8_t>(sizeInBytes);
    std::copy(static_cast<uint8_t*>(data), static_cast<uint8_t*>(data) + sizeInBytes, buffer->begin());

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          // Create a BufferDescriptor with a callback to delete the vector
          IndexBuffer::BufferDescriptor bufferDescriptor(
              buffer->data(),
              buffer->size(),
              [](void* buffer, size_t size, void* user) {
                delete reinterpret_cast<std::vector<uint8_t>*>(user);
              },
              buffer
          );

          // Call the original setBuffer with our BufferDescriptor
          auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
          auto* indexBuffer = reinterpret_cast<filament::IndexBuffer*>(tBuffer);
          indexBuffer->setBuffer(*engine, std::move(bufferDescriptor), byteOffset);

          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildJobThread(TJobThread *jobThread,
      TRenderableBuilder *tBuilder,
      TEngine *tEngine,
      EntityId entityId,
      void (*onComplete)(int))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
          auto *engine = reinterpret_cast<filament::Engine*>(tEngine);
          const auto &entity = utils::Entity::import(entityId);

          auto result = builder->build(*engine, entity);
          PROXY(onComplete(static_cast<int>(result)));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildWithSkinningJobThread(TJobThread *jobThread,
      TRenderableBuilder *tBuilder,
      TEngine *tEngine,
      EntityId entityId,
      size_t boneCount,
      const float *data,
      bool boneData,
      void (*onComplete)(int))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Use typed storage for Filament's alignment requirements. Only the selected
    // representation allocates; Dart's borrowed pointer is consumed here.
    std::vector<filament::math::mat4f> matrices(boneData ? 0 : boneCount);
    std::vector<filament::RenderableManager::Bone> bones(boneData ? boneCount : 0);
    if (!matrices.empty()) std::memcpy(matrices.data(), data, matrices.size() * sizeof(matrices[0]));
    if (!bones.empty()) std::memcpy(bones.data(), data, bones.size() * sizeof(bones[0]));
    std::packaged_task<void()> lambda(
        [=, matrices = std::move(matrices), bones = std::move(bones)]() mutable
        {
          auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
          if (boneData) {
            builder->skinning(boneCount, bones.data());
          } else {
            builder->skinning(boneCount, matrices.data());
          }
          // Filament reads the pointers during build(), while the task owns them.
          auto result = RenderableBuilder_build(tBuilder, tEngine, entityId);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void EntityManager_createEntityJobThread(TJobThread *jobThread, TEntityManager *tEntityManager, void (*onComplete)(EntityId))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto entityId = EntityManager_createEntity(tEntityManager);
          PROXY(onComplete(entityId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntityJobThread(TJobThread *jobThread, TEntityManager *tEntityManager, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          EntityManager_destroyEntity(tEntityManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformJobThread(TJobThread *jobThread,
      TTransformManager *tTransformManager,
      EntityId entityId,
      double4x4 transform,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_setTransform(tTransformManager, entityId, transform);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformNativeJobThread(TJobThread *jobThread,
      TTransformManager *manager, EntityId entity, TMat4 *matrix,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // The caller owns this matrix until the completion callback runs.
    const auto *transform = reinterpret_cast<const filament::math::mat4 *>(matrix);
    rt->addDetachedTask([=] {
      auto *tm = reinterpret_cast<filament::TransformManager *>(manager);
      auto instance = tm->getInstance(utils::Entity::import(entity));
      if (instance) tm->setTransform(instance, *transform);
      PROXY(onComplete(requestId));
    });
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformFromBufferJobThread(TJobThread *jobThread,
      TTransformManager *manager, EntityId entity, const double *matrix16,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Snapshot before returning to Dart; the queued task owns a real mat4 and
    // can pass it directly to Filament without reconstructing it on execution.
    const auto snapshot = load_mat4(matrix16);
    rt->addDetachedTask([=] {
      auto *tm = reinterpret_cast<filament::TransformManager *>(manager);
      auto instance = tm->getInstance(utils::Entity::import(entity));
      if (instance) tm->setTransform(instance, snapshot);
      PROXY(onComplete(requestId));
    });
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setParentJobThread(TJobThread *jobThread,
      TTransformManager *tTransformManager,
      EntityId child,
      EntityId parent,
      bool preserveScaling,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_setParent(tTransformManager, child, parent, preserveScaling);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_createComponentJobThread(TJobThread *jobThread,
      TTransformManager *tTransformManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_createComponent(tTransformManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponentJobThread(TJobThread *jobThread,
      TTransformManager *tTransformManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_removeComponent(tTransformManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntityJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_destroyEntity(tRenderableManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  // Copy the caller-owned payload before returning across the FFI boundary.
  // Native Dart typed data is pinned only for the duration of the leaf call,
  // and ffigen_js uses Emscripten stack storage for makeFloat32List().
  EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeightsJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      const float *weights,
      size_t count,
      size_t offset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::vector<float> ownedWeights;
    if (count > 0) {
      ownedWeights.assign(weights, weights + count);
    }
    std::packaged_task<void()> lambda(
        [=, ownedWeights = std::move(ownedWeights)]() mutable
        {
          if (!ownedWeights.empty()) {
            RenderableManager_setMorphWeights(
                tRenderableManager, entityId, ownedWeights.data(), ownedWeights.size(), offset);
          }
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4JobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      const float *transforms,
      size_t boneCount,
      size_t offset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Snapshot borrowed FFI storage before returning to Dart. The task owns it.
    std::vector<float> owned;
    if (boneCount != 0) owned.assign(transforms, transforms + boneCount * 16);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          RenderableManager_setBonesFromMat4(tRenderableManager, entityId, owned.data(), boneCount, offset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBoneJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      const float *bones,
      size_t boneCount,
      size_t offset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    // Snapshot borrowed FFI storage before returning to Dart. The task owns it.
    std::vector<float> owned;
    if (boneCount != 0) owned.assign(bones, bones + boneCount * 8);
    std::packaged_task<void()> lambda(
        [=, owned = std::move(owned)]() mutable
        {
          RenderableManager_setBonesFromBone(tRenderableManager, entityId, owned.data(), boneCount, offset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  // The lambda captures only scalars and pointers to filament-owned objects,
  // so no heap payload is needed: the VertexBuffer handle stays valid because
  // Dart only destroys it through VertexBuffer_destroyJobThread, which is
  // queued behind this task on the same render thread.
  EMSCRIPTEN_KEEPALIVE void RenderableManager_setGeometryAtNonIndexedJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      int primitiveIndex,
      uint8_t type,
      TVertexBuffer *tVertices,
      size_t offset,
      size_t count,
      void (*callback)(bool))
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = RenderableManager_setGeometryAtNonIndexed(
              tRenderableManager, entityId, primitiveIndex, type, tVertices, offset, count);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  // Shadow flags MUST be applied on the render thread — Filament's
  // RenderableManager/LightManager are not concurrency-safe, so the
  // non-render-thread setters race the renderer and the flags don't take
  // (realtime shadows never appear).
  EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadowsJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setCastShadows(tRenderableManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadowsJobThread(TJobThread *jobThread,
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setReceiveShadows(tRenderableManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCasterJobThread(TJobThread *jobThread,
      TLightManager *tLightManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          LightManager_setShadowCaster(tLightManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptionsJobThread(TJobThread *jobThread,
      TLightManager *tLightManager,
      EntityId entityId,
      TShadowOptions options,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = reinterpret_cast<JobThread*>(jobThread);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          LightManager_setShadowOptions(tLightManager, entityId, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

}
