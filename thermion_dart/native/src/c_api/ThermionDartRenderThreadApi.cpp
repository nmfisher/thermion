#include <atomic>
#include <functional>
#include <mutex>
#include <shared_mutex>
#include <thread>
#include <stdlib.h>
#include <vector>
#ifdef __EMSCRIPTEN__
#include <unistd.h>
#include <mimalloc.h>
#endif

#include <filament/LightManager.h>

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
#include "c_api/ThermionDartRenderThreadApi.h"

#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include "Log.hpp"

#ifdef __EMSCRIPTEN__
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <emscripten/console.h>
#endif

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>
#include <cinttypes>

#if defined __EMSCRIPTEN__
#define PROXY(call)                                           \
  auto startTime = std::chrono::high_resolution_clock::now(); \
  TRACE("PROXYING");                                          \
  rt->queue.proxySync(rt->outer, [=]() { call; });
#else
#define PROXY(call) call
#endif
extern "C"
{

  // ─────────────────────────────────────────────────────────────────────────
  // Owner-keyed thread registry.
  //
  // Multi-engine web (one engine per viewer) runs each engine on its own
  // RenderThread / pthread / canvas. Every `*RenderThread` function below
  // dispatches to the thread that owns the object it operates on, resolved
  // from g_threadByOwner. Entries are recorded at object-creation tasks
  // (creation runs on the owning thread) and at the direct-API getters via
  // RenderThread_registerOwnerFromOwner.
  //
  // Single-engine apps — and every native build — fall through to
  // `_renderThread` (or the most recently created thread), preserving the
  // historical singleton behavior exactly.
  // ─────────────────────────────────────────────────────────────────────────
  std::unique_ptr<RenderThread> _renderThread;
  std::unordered_map<void *, RenderThread *> g_threadByOwner;
  std::unordered_map<void *, std::unique_ptr<RenderThread>> _renderThreads;
  RenderThread *g_activeThread = nullptr;

  // g_threadByOwner is written from RenderThread worker tasks (object
  // creation registers the new handle on the thread that produced it — see
  // the ~60 `setOwner(...)` sites below) and read from the Dart thread on
  // every dispatch via RT(). std::unordered_map is not concurrency-safe: an
  // unsynchronized find() racing an insert that triggers a rehash on the
  // worker returns garbage, which surfaced as intermittent SEGVs inside
  // addTask() (the dispatch dereferenced a wild pointer). Every access goes
  // through g_ownerMutex.
  std::shared_mutex g_ownerMutex;

  // Resolve the thread for a dispatch. `owner` is the engine/manager/view/
  // ... handle the operation targets; nullptr means "creation-time task" —
  // the most recently created thread, which is the one the Dart side just
  // built for this engine (Dart serialises engine creation).
  RenderThread *RT(void *owner)
  {
    if (owner != nullptr)
    {
      std::shared_lock<std::shared_mutex> lock(g_ownerMutex);
      auto it = g_threadByOwner.find(owner);
      if (it != g_threadByOwner.end())
      {
        return it->second;
      }
    }
    if (g_activeThread != nullptr)
    {
      return g_activeThread;
    }
    return _renderThread.get();
  }

  // Record that `owner` belongs to `rt`. Called from worker-thread creation
  // tasks and from the Dart thread; always under the exclusive lock.
  static void setOwner(void *owner, RenderThread *rt)
  {
    if (owner == nullptr || rt == nullptr)
    {
      return;
    }
    std::lock_guard<std::shared_mutex> lock(g_ownerMutex);
    g_threadByOwner[owner] = rt;
  }

  // Remove every owner registration that maps to `rt`. Call AFTER the thread's
  // worker has been joined (otherwise an in-flight creation task on that worker
  // could re-add an entry pointing at the about-to-be-freed RenderThread, and a
  // recycled handle address would later resolve to freed memory via RT()).
  static void unregisterOwnersOf(void *rt)
  {
    if (rt == nullptr)
    {
      return;
    }
    std::lock_guard<std::shared_mutex> lock(g_ownerMutex);
    for (auto it = g_threadByOwner.begin(); it != g_threadByOwner.end();)
    {
      if (it->second == rt)
      {
        it = g_threadByOwner.erase(it);
      }
      else
      {
        ++it;
      }
    }
  }

  // Record that `owner` (created on the main thread via a direct-API getter,
  // e.g. Engine_getTransformManager) belongs to the thread of `knownOwner`
  // (an engine-scoped handle already in the registry).
  EMSCRIPTEN_KEEPALIVE void RenderThread_registerOwnerFromOwner(void *owner, void *knownOwner)
  {
    if (owner == nullptr || knownOwner == nullptr)
    {
      return;
    }
    RenderThread *rt;
    {
      std::shared_lock<std::shared_mutex> lock(g_ownerMutex);
      auto it = g_threadByOwner.find(knownOwner);
      rt = (it != g_threadByOwner.end()) ? it->second : nullptr;
    }
    // Preserve RT()'s fallback semantics for an unregistered knownOwner.
    if (rt == nullptr)
    {
      rt = g_activeThread != nullptr ? g_activeThread : _renderThread.get();
    }
    if (rt == nullptr)
    {
      return;
    }
    setOwner(owner, rt);
  }

  // Web-only: the CSS selector of the canvas owned by the most recently
  // created RenderThread, used by Engine_create to create the WebGL context
  // on the right canvas.
  EMSCRIPTEN_KEEPALIVE const char *RenderThread_getActiveCanvasSelector()
  {
    RenderThread *rt = g_activeThread != nullptr ? g_activeThread : _renderThread.get();
    return rt != nullptr ? rt->canvasSelector() : "#thermion_canvas";
  }

  EMSCRIPTEN_KEEPALIVE void* RenderThread_create()
  {
    TRACE("RenderThread_create");
    RenderThread *stale = _renderThread ? _renderThread.get() : nullptr;
    if (stale != nullptr)
    {
      Log("WARNING - you are attempting to create a RenderThread when the previous one has not been disposed.");
    }
    auto thread = std::make_unique<RenderThread>();
    if (thread->creationFailed())
    {
      // pthread_create failed on web (e.g. worker pool exhausted); a null
      // handle lets Dart fail loudly instead of hanging on never-run tasks.
      Log("RenderThread worker failed to start; returning null handle");
      return nullptr;
    }
    _renderThread = std::move(thread);
    // The move-assignment above destroyed the previous RenderThread (and joined
    // its worker). Sweep stale owner registrations AFTER the join — the dying
    // worker's last creation task can't then re-add an entry pointing at freed
    // memory, and a recycled handle address can't resolve to it via RT().
    if (stale != nullptr)
    {
      unregisterOwnersOf(stale);
    }
    g_activeThread = _renderThread.get();
    TRACE("RenderThread created");
    return _renderThread.get();
  }

  EMSCRIPTEN_KEEPALIVE void* RenderThread_createForCanvas(const char *canvasSelector)
  {
    TRACE("RenderThread_createForCanvas %s", canvasSelector);
    auto thread = std::make_unique<RenderThread>(canvasSelector);
    if (thread->creationFailed())
    {
      Log("RenderThread worker failed to start for canvas %s; returning null handle", canvasSelector);
      return nullptr;
    }
    auto *raw = thread.get();
    g_activeThread = raw;
    _renderThreads[raw] = std::move(thread);
    TRACE("RenderThread created for canvas %s", canvasSelector);
    return raw;
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_destroy(void *renderThread)
  {
    TRACE("RenderThread_destroy");
    if (renderThread == nullptr)
    {
      return;
    }
    if (renderThread == _renderThread.get())
    {
      _renderThread = nullptr;
    }
    else
    {
      auto it = _renderThreads.find(renderThread);
      if (it != _renderThreads.end())
      {
        _renderThreads.erase(it);
      }
    }
    if (g_activeThread == renderThread)
    {
      g_activeThread = nullptr;
    }
    // _renderThread = nullptr / _renderThreads.erase above already destroyed
    // the RenderThread (and joined its worker), so it's safe to drop any owner
    // registrations that still point at it.
    unregisterOwnersOf(renderThread);
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_addTask(void (*task)())
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          task();
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_attachToRenderThread(TRenderManager *tRenderManager)
  {
#ifdef __EMSCRIPTEN__
    bool ownersEmpty;
    {
      std::shared_lock<std::shared_mutex> lock(g_ownerMutex);
      ownersEmpty = g_threadByOwner.empty();
    }
    if (!_renderThread && ownersEmpty) {
      Log("WARNING - RenderManager_attachToRenderThread called with no RenderThread active.");
      return;
    }
    auto *rm = reinterpret_cast<RenderManager *>(tRenderManager);
    auto *rt = RT(tRenderManager);
    setOwner(tRenderManager, rt);
    rt->setRenderManager(rm);
#else
    (void)tRenderManager; // no-op on native
#endif
  }

  // Inverse of RenderManager_attachToRenderThread. Call before deleting a
  // RenderManager so the worker's iter() doesn't dereference a freed pointer
  // on its next tick.
  EMSCRIPTEN_KEEPALIVE void RenderManager_detachFromRenderThread(TRenderManager *tRenderManager)
  {
#ifdef __EMSCRIPTEN__
    auto *rt = RT(tRenderManager);
    if (rt) {
      rt->setRenderManager(nullptr);
    }
    {
      std::lock_guard<std::shared_mutex> lock(g_ownerMutex);
      g_threadByOwner.erase(tRenderManager);
    }
#else
    (void)tRenderManager; // no-op on native
#endif
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderableRenderThread(
    TRenderManager *tRenderer,
    TSwapChain *tSwapChain,
    TView **tViews,
    uint8_t numViews,
    uint32_t requestId, VoidCallback onComplete) {
    auto *rt = RT(tRenderer);

      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_setRenderable(tRenderer, tSwapChain, tViews, numViews);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);

    }

  EMSCRIPTEN_KEEPALIVE void RenderManager_renderRenderThread(
    TRenderManager *tRenderManager,
    uint64_t frameTimeInNanos,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = RT(tRenderManager);
    auto queuedAt = std::chrono::steady_clock::now();
    rt->addDetachedTask([=]() mutable {
      auto startedAt = std::chrono::steady_clock::now();
      float queueMs = std::chrono::duration_cast<std::chrono::nanoseconds>(startedAt - queuedAt).count() / 1e6f;
      RenderManager_render(tRenderManager, frameTimeInNanos);
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
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManagerRenderThread(
    TRenderManager *tRenderManager,
    TAnimationManager *tAnimationManager,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = RT(tRenderManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_addAnimationManager(tRenderManager, tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManagerRenderThread(
    TRenderManager *tRenderManager,
    TAnimationManager *tAnimationManager,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = RT(tRenderManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_removeAnimationManager(tRenderManager, tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChainRenderThread(
    TRenderManager *tRenderManager,
    TSwapChain *tSwapChain,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = RT(tRenderManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderManager_removeSwapChain(tRenderManager, tSwapChain);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(
      TBackend backend,
      void *platform,
      void *sharedContext,
      uint8_t stereoscopicEyeCount,
      bool disableHandleUseAfterFreeCheck,
      void (*onComplete)(TEngine *))
  {
    auto *rt = RT(nullptr);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *engine = Engine_create(backend, platform, sharedContext, stereoscopicEyeCount, disableHandleUseAfterFreeCheck);

          setOwner(engine, rt);          PROXY(onComplete(engine));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *))
  {
    auto *rt = RT(tEngine);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *renderer = Engine_createRenderer(tEngine);

          setOwner(renderer, rt);          PROXY(onComplete(renderer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createSwapChain(tEngine, window, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createHeadlessSwapChain(tEngine, width, height, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySwapChain(tEngine, tSwapChain);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyRendererRenderThread(TEngine *tEngine, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyRenderer(tEngine, tRenderer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyViewRenderThread(TEngine *tEngine, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyView(tEngine, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySceneRenderThread(TEngine *tEngine, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyScene(tEngine, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine *tEngine, EntityId entityId, void (*onComplete)(TCamera *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto camera = Engine_createCamera(tEngine, entityId);

          setOwner(camera, rt);          PROXY(onComplete(camera));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyCameraRenderThread(TEngine *tEngine, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyCamera(tEngine, tCamera);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *view = Engine_createView(tEngine);

          setOwner(view, rt);          PROXY(onComplete(view));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroy(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture *tTexture, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(engine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyTexture(engine, tTexture);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySkybox(tEngine, tSkybox);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyIndirectLight(tEngine, tIndirectLight);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto material = Engine_buildMaterial(tEngine, materialData, length);

          setOwner(material, rt);          PROXY(onComplete(material));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterial(tEngine, tMaterial);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterialInstance(tEngine, tMaterialInstance);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  // Runs the .mat -> .filamat compile on the engine's render thread (the
  // build uses the engine's JobSystem, so it is serialized with other engine
  // work). Follows the readPixels pattern: the task fills [outData]/[outSize]
  // (the buffer stays allocated until the caller releases it with
  // Engine_freeCompiledMaterial) and then notifies [onComplete] with
  // [requestId]. On failure *outData is set to nullptr and the message is in
  // [outError].
  EMSCRIPTEN_KEEPALIVE void Engine_compileMaterialRenderThread(
      TEngine *tEngine,
      const char *matSource,
      size_t length,
      TMaterialPlatform platform,
      TMaterialTargetApi targetApi,
      TMaterialOptimization optimization,
      const char *definesJson,
      uint8_t embedSource,
      char *outError,
      size_t outErrorCap,
      const uint8_t **outData,
      size_t *outSize,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          size_t size = 0;
          const uint8_t *data = Engine_compileMaterial(
              tEngine, matSource, length, platform, targetApi, optimization, definesJson, embedSource, outError, outErrorCap, &size);
          if (outData != nullptr)
          {
            *outData = data;
          }
          if (outSize != nullptr)
          {
            *outSize = size;
          }
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *fence = Engine_createFence(tEngine);

          setOwner(fence, rt);          PROXY(onComplete(fence));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyRenderThread(TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tFence);
    
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Fence_waitAndDestroy(tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyFence(tEngine, tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_flushAndWait(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_executeRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
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
    auto *rt = RT(nullptr);
#ifdef __EMSCRIPTEN__
    rt->queue.execute();
#endif
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *skybox = Engine_buildSkybox(tEngine, tTexture, showSun, intensity, priority);
          PROXY(onComplete(skybox));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxRenderThread(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *skybox = Engine_buildColoredSkybox(tEngine, r, g, b, a, showSun, intensity, priority);
          PROXY(onComplete(skybox));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureRenderThread(
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    TTexture* tIrradianceTexture,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
    auto *rt = RT(tEngine);
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceTexture(tEngine, tReflectionsTexture, tIrradianceTexture, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = rt->addTask(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsRenderThread(
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    float *harmonics,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
    auto *rt = RT(tEngine);
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceHarmonics(tEngine, tReflectionsTexture, harmonics, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool))
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = Renderer_beginFrame(tRenderer, tSwapChain, frameTimeInNanos);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_endFrame(tRenderer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_render(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_renderStandaloneView(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsRenderThread(
      TRenderer *tRenderer,
      double clearR,
      double clearG,
      double clearB,
      double clearA,
      uint8_t clearStencil,
      bool clear,
      bool discard, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_setClearOptions(tRenderer, clearR, clearG, clearB, clearA, clearStencil, clear, discard);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsRenderThread(
      TRenderer *tRenderer,
      uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
      TRenderTarget *tRenderTarget,
      TPixelDataFormat tPixelBufferFormat,
      TPixelDataType tPixelDataType,
      uint8_t *out,
      size_t outLength,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tRenderer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_readPixels(tRenderer, width, height, xOffset, yOffset, tRenderTarget, tPixelBufferFormat, tPixelDataType, out, outLength);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createImageMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createGizmoMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createSilhouetteMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createSilhouetteMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createEdgeOutlineMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createEdgeOutlineMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createWireframeMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createWireframeMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createTranslationAxisMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createTranslationAxisMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createBoneOverlayMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createBoneOverlayMaterial(tEngine);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *))
  {
    auto *rt = RT(tMaterial);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createInstance(tMaterial);

          setOwner(instance, rt);          PROXY(onComplete(instance));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTextureRenderThread(
      TMaterialInstance *tMaterialInstance,
      const char *propertyName,
      TTexture* tTexture,
      TTextureSampler* tSampler,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tMaterialInstance);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          MaterialInstance_setParameterTexture(tMaterialInstance, propertyName, tTexture, tSampler);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tSceneAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_destroy(tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      TNameComponentManager *tNameComponentManager,
      TFilamentAsset *tFilamentAsset,
      bool rebuildVertices,
      void (*onComplete)(TSceneAsset *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto sceneAsset = SceneAsset_createFromFilamentAsset(tEngine, tAssetLoader, tNameComponentManager, tFilamentAsset, rebuildVertices);

          setOwner(sceneAsset, rt);          PROXY(onComplete(sceneAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromBuffersRenderThread(
      TEngine *tEngine,
      TVertexBuffer *tVertexBuffer,
      TIndexBuffer *tIndexBuffer,
      TMaterialInstance **materialInstances,
      int materialInstanceCount,
      TPrimitiveType tPrimitiveType,
      Aabb3 boundingBox,
      void (*callback)(TSceneAsset *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto sceneAsset = SceneAsset_createFromBuffers(tEngine, tVertexBuffer, tIndexBuffer, materialInstances, materialInstanceCount, tPrimitiveType, boundingBox);

          setOwner(sceneAsset, rt);          PROXY(callback(sceneAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceRenderThread(
      TSceneAsset *asset, TMaterialInstance **tMaterialInstances,
      int materialInstanceCount,
      void (*callback)(TSceneAsset *))
  {
    auto *rt = RT(asset);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto instanceAsset = SceneAsset_createInstance(asset, tMaterialInstances, materialInstanceCount);

          setOwner(instanceAsset, rt);          PROXY(callback(instanceAsset));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceDataRenderThread(
      TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tSceneAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_releaseSourceData(tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShadingRenderThread(
      TSceneAsset *tSceneAsset, bool flatShading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tSceneAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_setFlatShading(tSceneAsset, flatShading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(
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
    auto *rt = RT(tMaterialProvider);
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

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_createRenderThread(void (*onComplete)(TColorGradingBuilder *))
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *builder = ColorGradingBuilder_create();

          setOwner(builder, rt);          PROXY(onComplete(builder));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_buildRenderThread(TColorGradingBuilder *tBuilder, TEngine *tEngine, void (*onComplete)(TColorGrading *))
  {
    auto *rt = RT(tBuilder);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *colorGrading = ColorGradingBuilder_build(tBuilder, tEngine);
          PROXY(onComplete(colorGrading));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroyRenderThread(TColorGradingBuilder *tBuilder, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tBuilder);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          ColorGradingBuilder_destroy(tBuilder);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createLinearRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createLinear(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createACES(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESLegacyRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createACESLegacy(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createFilmicRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createFilmic(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createPBRNeutralRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createPBRNeutral(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createAGX(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXWithLookRenderThread(TEngine *tEngine, int look, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createAGXWithLook(tEngine, look);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createGenericRenderThread(TEngine *tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createGeneric(tEngine, contrast, midGrayIn, midGrayOut, hdrMax);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_createDisplayRangeRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *toneMapper = ToneMapper_createDisplayRange(tEngine);

          setOwner(toneMapper, rt);          PROXY(onComplete(toneMapper));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ToneMapper_destroyRenderThread(TToneMapper *tToneMapper, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tToneMapper);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          ToneMapper_destroy(tToneMapper);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingRenderThread(TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]
        {
          Engine_destroyColorGrading(tEngine, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_pickRenderThread(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback)
  {
    auto *rt = RT(tView);
    auto *view = reinterpret_cast<View *>(tView);
    view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
               { PROXY(callback(requestId, utils::Entity::smuggle(result.renderable), result.depth, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z)); });
  }

  EMSCRIPTEN_KEEPALIVE void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setColorGrading(tView, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBloom(tView, enabled, strength);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setCamera(tView, tCamera);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_getNameRenderThread(TView *tView, void (*onComplete)(const char *))
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          auto name = View_getName(tView);
          PROXY(onComplete(name));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setNameRenderThread(TView *tView, const char *name, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setName(tView, name);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setViewportRenderThread(TView *tView, uint32_t width, uint32_t height, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setViewport(tView, width, height);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setRenderTargetRenderThread(TView *tView, TRenderTarget *tRenderTarget, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setRenderTarget(tView, tRenderTarget);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setAntiAliasingRenderThread(TView *tView, bool msaa, bool fxaa, bool taa, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setAntiAliasing(tView, msaa, fxaa, taa);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setPostProcessingRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setPostProcessing(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFrustumCullingEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setStencilBufferEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setDitheringEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setRenderQualityRenderThread(TView *tView, int qualityLevel, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setRenderQuality(tView, static_cast<TQualityLevel>(qualityLevel));
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setSceneRenderThread(TView *tView, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setScene(tView, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setLayerEnabledRenderThread(TView *tView, int layer, bool visible, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setLayerEnabled(tView, layer, visible);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBlendModeRenderThread(TView *tView, int blendMode, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBlendMode(tView, static_cast<TBlendMode>(blendMode));
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFogOptionsRenderThread(TView *tView, TFogOptions tFogOptions, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFogOptions(tView, tFogOptions);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptionsRenderThread(TView *tView, TAmbientOcclusionOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setAmbientOcclusionOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInvertedRenderThread(TView *tView, bool inverted, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setFrontFaceWindingInverted(tView, inverted);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setShadowsEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setShadowTypeRenderThread(TView *tView, int shadowType, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setShadowType(tView, shadowType);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptionsRenderThread(TView *tView, TSoftShadowOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setSoftShadowOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptionsRenderThread(TView *tView, TVsmShadowOptions options, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setVsmShadowOptions(tView, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tView);
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setTransparentPickingEnabled(tView, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseRenderThread(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = RT(tAnimationManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_resetToRestPose(tAnimationManager, tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, void (*onComplete)(TAnimationManager *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *animationManager = AnimationManager_create(tEngine);

          setOwner(animationManager, rt);          PROXY(onComplete(animationManager));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_destroyRenderThread(TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tAnimationManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_destroy(tAnimationManager);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_updateRenderThread(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = RT(tAnimationManager);
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
  EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationTimeRenderThread(
      TAnimationManager *tAnimationManager,
      TSceneAsset *tSceneAsset,
      int animationIndex,
      float timeInSeconds,
      uint32_t requestId,
      VoidCallback onComplete) {
    auto *rt = RT(tAnimationManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_setGltfAnimationTime(tAnimationManager, tSceneAsset, animationIndex, timeInSeconds);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesRenderThread(
      TAnimationManager *tAnimationManager,
      TSceneAsset *sceneAsset,
      void (*callback)(bool))
  {
    auto *rt = RT(tAnimationManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = AnimationManager_updateBoneMatrices(tAnimationManager, sceneAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsRenderThread(
      TAnimationManager *tAnimationManager,
      EntityId entityId,
      const float *const morphData,
      int numWeights,
      void (*callback)(bool))
  {
    auto *rt = RT(tAnimationManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = AnimationManager_setMorphTargetWeights(tAnimationManager, entityId, morphData, numWeights);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_createEmptyRenderThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *))
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_createEmpty(width, height, channel);

          setOwner(image, rt);          PROXY(onComplete(image));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t *data, size_t length, const char *name, bool alpha, void (*onComplete)(TLinearImage *))
  {
    auto *rt = RT(data);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_decode(data, length, name, alpha);

          setOwner(image, rt);          PROXY(onComplete(image));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *))
  {
    auto *rt = RT(tLinearImage);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto bytes = Image_getBytes(tLinearImage);
          PROXY(onComplete(bytes));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tLinearImage);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Image_destroy(tLinearImage);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = RT(tLinearImage);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto width = Image_getWidth(tLinearImage);
          PROXY(onComplete(width));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = RT(tLinearImage);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto height = Image_getHeight(tLinearImage);
          PROXY(onComplete(height));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    auto *rt = RT(tLinearImage);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto channels = Image_getChannels(tLinearImage);
          PROXY(onComplete(channels));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_buildRenderThread(
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
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *texture = Texture_build(tEngine, width, height, depth, levels, tUsage, import, sampler, format);

          setOwner(texture, rt);          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setExternalImageRenderThread(TEngine *tEngine, TTexture *tTexture, void *externalImage, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Texture_setExternalImage(tEngine, tTexture, externalImage);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsRenderThread(TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete) {
    auto *rt = RT(tTexture);
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
  EMSCRIPTEN_KEEPALIVE void Ktx2Reader_createTextureRenderThread(
    TEngine *tEngine, uint8_t* data, size_t size, void (*onComplete)(TTexture *)) {
    auto *rt = RT(tEngine);
    std::vector<uint8_t> bytes(data, data + size);
    std::packaged_task<void()> lambda(
        [tEngine, bytes = std::move(bytes), onComplete, rt]() mutable
        {
          auto *texture = Ktx2Reader_createTexture(tEngine, bytes.data(), bytes.size());
          setOwner(texture, rt);
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureRenderThread(
    TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *)) {
    auto *rt = RT(tEngine);

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
          setOwner(texture, rt);
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage,
                                                          TPixelDataFormat bufferFormat, TPixelDataType pixelDataType,
                                                          int level,
                                                          void (*onComplete)(bool))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_loadImage(tEngine, tTexture, tImage, bufferFormat, pixelDataType, level);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setImageRenderThread(
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
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_setImage(
              tEngine,
              tTexture,
              level,
              data,
              size,
              x_offset,
              y_offset,
              z_offset,
              width,
              height,
              depth,
              bufferFormat,
              pixelDataType);
          PROXY(onComplete(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *))
  {
    auto *rt = RT(tRenderTarget);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_getColorTexture(tRenderTarget);
          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_createRenderThread(
      TEngine *tEngine,
      TTexture *tColor,
      TTexture *tDepth,
      void (*onComplete)(TRenderTarget *))
  {
    auto *rt = RT(tEngine);
    auto color = reinterpret_cast<filament::Texture *>(tColor);
    auto depth = reinterpret_cast<filament::Texture *>(tDepth);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_create(tEngine, tColor, tDepth);

          setOwner(texture, rt);          PROXY(onComplete(texture));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyRenderThread(
      TEngine *tEngine,
      TRenderTarget *tRenderTarget,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderTarget_destroy(tEngine, tRenderTarget);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler *))
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_create();

          setOwner(sampler, rt);          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringRenderThread(
      TSamplerMinFilter minFilter,
      TSamplerMagFilter magFilter,
      TSamplerWrapMode wrapS,
      TSamplerWrapMode wrapT,
      TSamplerWrapMode wrapR,
      void (*onComplete)(TTextureSampler *))
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithFiltering(minFilter, magFilter, wrapS, wrapT, wrapR);

          setOwner(sampler, rt);          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonRenderThread(
      TSamplerCompareMode compareMode,
      TSamplerCompareFunc compareFunc,
      void (*onComplete)(TTextureSampler *))
  {
    auto *rt = RT(nullptr);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithComparison(compareMode, compareFunc);

          setOwner(sampler, rt);          PROXY(onComplete(sampler));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMinFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMinFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMagFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMagFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeS(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeT(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeR(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyRenderThread(
      TTextureSampler *sampler,
      double anisotropy,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setAnisotropy(sampler, anisotropy);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeRenderThread(
      TTextureSampler *sampler,
      TSamplerCompareMode mode,
      TTextureSamplerCompareFunc func,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setCompareMode(sampler, mode, func);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyRenderThread(
      TTextureSampler *sampler,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(sampler);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_destroy(sampler);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(
    TEngine *tEngine,
    TMaterialProvider *tMaterialProvider,
    TNameComponentManager *tNameComponentManager,
    void (*callback)(TGltfAssetLoader *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_create(tEngine, tMaterialProvider, tNameComponentManager);

          setOwner(loader, rt);        PROXY(callback(loader));
      });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_destroyRenderThread(
    TGltfAssetLoader *tAssetLoader,
    uint32_t requestId,
    VoidCallback onComplete)
  {
    auto *rt = RT(tAssetLoader);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        GltfAssetLoader_destroy(tAssetLoader);
        PROXY(onComplete(requestId));
      });
    auto fut = rt->addTask(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *)) {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfResourceLoader_create(tEngine);

          setOwner(loader, rt);        PROXY(callback(loader));
      });
    auto fut = rt->addTask(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyRenderThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_destroy(tEngine, tResourceLoader);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool))
  {
    auto *rt = RT(tGltfResourceLoader);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_loadResources(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      const char *uri,
      uint8_t *data,
      size_t length,
      uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tGltfResourceLoader);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_addResourceData(tGltfResourceLoader, uri, data, length);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      TFilamentAsset *tFilamentAsset,
      void (*callback)(bool))
  {
    auto *rt = RT(tGltfResourceLoader);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncBeginLoad(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadRenderThread(
      TGltfResourceLoader *tGltfResourceLoader)
  {
    auto *rt = RT(tGltfResourceLoader);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_asyncUpdateLoad(tGltfResourceLoader);
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      void (*callback)(float))
  {
    auto *rt = RT(tGltfResourceLoader);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncGetLoadProgress(tGltfResourceLoader);
          PROXY(callback(result));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      uint8_t *data,
      size_t length,
      uint32_t numInstances,
      void (*callback)(TFilamentAsset *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto loader = GltfAssetLoader_load(tEngine, tAssetLoader, data, length, numInstances);

          setOwner(loader, rt);          PROXY(callback(loader));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene *tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tScene);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_addFilamentAsset(tScene, tAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void FilamentAsset_getWireframeRenderThread(TFilamentAsset *tFilamentAsset, void (*onComplete)(EntityId))
  {
    auto *rt = RT(tFilamentAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto entityId = FilamentAsset_getWireframe(tFilamentAsset);
          PROXY(onComplete(entityId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addEntityRenderThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tScene);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_addEntity(tScene, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_removeEntityRenderThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tScene);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_removeEntity(tScene, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_addToSceneRenderThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tSceneAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_addToScene(tSceneAsset, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromSceneRenderThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tSceneAsset);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_removeFromScene(tSceneAsset, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_setSkyboxRenderThread(TScene *tScene, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tScene);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_setSkybox(tScene, tSkybox);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLightRenderThread(TScene *tScene, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tScene);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_setIndirectLight(tScene, tIndirectLight);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Gizmo_createRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      TGltfResourceLoader *tGltfResourceLoader,
      TNameComponentManager *tNameComponentManager,
      TView *tView,
      TMaterial *tMaterial,
      TGizmoType tGizmoType,
      void (*callback)(TGizmo *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *gizmo = Gizmo_create(tEngine, tAssetLoader, tGltfResourceLoader, tNameComponentManager, tView, tMaterial, tGizmoType);

          setOwner(gizmo, rt);          PROXY(callback(gizmo));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_buildRenderThread(
      TVertexBufferBuilder *tBuilder,
      TEngine *tEngine,
      void (*onComplete)(TVertexBuffer *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *vertexBuffer = VertexBufferBuilder_build(tBuilder, tEngine);

          setOwner(vertexBuffer, rt);          PROXY(onComplete(vertexBuffer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroyRenderThread(
      TEngine *tEngine,
      TVertexBuffer *tBuffer,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          VertexBuffer_destroy(tEngine, tBuffer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAtRenderThread(
      TEngine* tEngine,
      TVertexBuffer* tBuffer,
      uint8_t bufferIndex,
      void* data,
      size_t sizeInBytes,
      uint32_t byteOffset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
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

  EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_buildRenderThread(
      TIndexBufferBuilder *tBuilder,
      TEngine *tEngine,
      void (*onComplete)(TIndexBuffer *))
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *indexBuffer = IndexBufferBuilder_build(tBuilder, tEngine);

          setOwner(indexBuffer, rt);          PROXY(onComplete(indexBuffer));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroyRenderThread(
      TEngine *tEngine,
      TIndexBuffer *tBuffer,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          IndexBuffer_destroy(tEngine, tBuffer);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBufferRenderThread(
      TEngine* tEngine,
      TIndexBuffer* tBuffer,
      void* data,
      size_t sizeInBytes,
      uint32_t byteOffset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tEngine);
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

  EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildRenderThread(
      TRenderableBuilder *tBuilder,
      TEngine *tEngine,
      EntityId entityId,
      void (*onComplete)(int))
  {
    auto *rt = RT(tEngine);
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

  EMSCRIPTEN_KEEPALIVE void EntityManager_createEntityRenderThread(TEntityManager *tEntityManager, void (*onComplete)(EntityId))
  {
    auto *rt = RT(tEntityManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto entityId = EntityManager_createEntity(tEntityManager);
          PROXY(onComplete(entityId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntityRenderThread(TEntityManager *tEntityManager, EntityId entityId, uint32_t requestId, VoidCallback onComplete)
  {
    auto *rt = RT(tEntityManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          EntityManager_destroyEntity(tEntityManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformRenderThread(
      TTransformManager *tTransformManager,
      EntityId entityId,
      double4x4 transform,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tTransformManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_setTransform(tTransformManager, entityId, transform);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_setParentRenderThread(
      TTransformManager *tTransformManager,
      EntityId child,
      EntityId parent,
      bool preserveScaling,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tTransformManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_setParent(tTransformManager, child, parent, preserveScaling);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_createComponentRenderThread(
      TTransformManager *tTransformManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tTransformManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_createComponent(tTransformManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponentRenderThread(
      TTransformManager *tTransformManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tTransformManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TransformManager_removeComponent(tTransformManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntityRenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tRenderableManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_destroyEntity(tRenderableManager, entityId);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4RenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      const float *transforms,
      size_t boneCount,
      size_t offset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tRenderableManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setBonesFromMat4(tRenderableManager, entityId, transforms, boneCount, offset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBoneRenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      const float *bones,
      size_t boneCount,
      size_t offset,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tRenderableManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setBonesFromBone(tRenderableManager, entityId, bones, boneCount, offset);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  // The lambda captures only scalars and pointers to filament-owned objects,
  // so no heap payload is needed: the VertexBuffer handle stays valid because
  // Dart only destroys it through VertexBuffer_destroyRenderThread, which is
  // queued behind this task on the same render thread.
  EMSCRIPTEN_KEEPALIVE void RenderableManager_setGeometryAtNonIndexedRenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      int primitiveIndex,
      uint8_t type,
      TVertexBuffer *tVertices,
      size_t offset,
      size_t count,
      void (*callback)(bool))
  {
    auto *rt = RT(tRenderableManager);
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
  EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadowsRenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tRenderableManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setCastShadows(tRenderableManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadowsRenderThread(
      TRenderableManager *tRenderableManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tRenderableManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderableManager_setReceiveShadows(tRenderableManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCasterRenderThread(
      TLightManager *tLightManager,
      EntityId entityId,
      bool enabled,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tLightManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          LightManager_setShadowCaster(tLightManager, entityId, enabled);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptionsRenderThread(
      TLightManager *tLightManager,
      EntityId entityId,
      TShadowOptions options,
      uint32_t requestId,
      VoidCallback onComplete)
  {
    auto *rt = RT(tLightManager);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          LightManager_setShadowOptions(tLightManager, entityId, options);
          PROXY(onComplete(requestId));
        });
    auto fut = rt->addTask(lambda);
  }

}
