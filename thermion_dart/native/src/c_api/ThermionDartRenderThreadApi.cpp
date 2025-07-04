#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#include <filament/LightManager.h>

#include "c_api/APIBoundaryTypes.h"
#include "c_api/TAnimationManager.h"
#include "c_api/TEngine.h"
#include "c_api/TGizmo.h"
#include "c_api/TGltfAssetLoader.h"
#include "c_api/TGltfResourceLoader.h"
#include "c_api/TRenderer.h"
#include "c_api/TRenderTicker.h"
#include "c_api/TRenderTarget.h"
#include "c_api/TScene.h"
#include "c_api/TSceneAsset.h"
#include "c_api/TTexture.h"
#include "c_api/TView.h"
#include "c_api/ThermionDartRenderThreadApi.h"

#include "rendering/RenderThread.hpp"
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
//auto innerStartTime = std::chrono::high_resolution_clock::now();\
  //Log("inner proxy start time time: % " PRId64 "ms", std::chrono::duration_cast<std::chrono::milliseconds>(innerStartTime.time_since_epoch()).count());\
//auto endTime = std::chrono::high_resolution_clock::now(); \
//auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();\
//float durationMs = durationNs / 1e6f;\
//Log("proxySync time: %.3f ms", durationMs);\
//startTime = std::chrono::high_resolution_clock::now(); \
//_renderThread->queue.execute(); \
//endTime = std::chrono::high_resolution_clock::now(); \
//durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();\
//durationMs = durationNs / 1e6f;\
//TRACE("queue execute time: %.3f ms", durationMs);
//auto innerEndTime = std::chrono::high_resolution_clock::now(); \
  //auto innerDurationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(innerEndTime - innerStartTime).count();\
  //float innerDurationMs = innerDurationNs / 1e6f;\
  //Log("inner proxy fn time: %.3f ms", innerDurationMs);\

#if defined __EMSCRIPTEN__
#define PROXY(call)                                           \
  auto startTime = std::chrono::high_resolution_clock::now(); \
  TRACE("PROXYING");                                          \
  _renderThread->queue.proxySync(_renderThread->outer, [=]() { call; });
#else
#define PROXY(call) call
#endif
extern "C"
{

  static std::unique_ptr<RenderThread> _renderThread;

  EMSCRIPTEN_KEEPALIVE void RenderThread_create()
  {
    TRACE("RenderThread_create");
    if (_renderThread)
    {
      Log("WARNING - you are attempting to create a RenderThread when the previous one has not been disposed.");
    }
    _renderThread = std::make_unique<RenderThread>();
    TRACE("RenderThread created");
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_destroy()
  {
    TRACE("RenderThread_destroy");
    if (_renderThread)
    {
      _renderThread = nullptr;
    }
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_addTask(void (*task)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          task();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_setRenderTicker(TRenderTicker *tRenderTicker)
  {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    _renderThread->setRenderTicker(renderTicker);
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_requestFrameAsync()
  {
    _renderThread->requestFrame();
  }

  EMSCRIPTEN_KEEPALIVE void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderTicker_render(tRenderTicker, frameTimeInNanos);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(
      TBackend backend,
      void *platform,
      void *sharedContext,
      uint8_t stereoscopicEyeCount,
      bool disableHandleUseAfterFreeCheck,
      void (*onComplete)(TEngine *))
  {

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *engine = Engine_create(backend, platform, sharedContext, stereoscopicEyeCount, disableHandleUseAfterFreeCheck);
          PROXY(onComplete(engine));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *))
  {

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *renderer = Engine_createRenderer(tEngine);
          PROXY(onComplete(renderer));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createSwapChain(tEngine, window, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto swapChain = Engine_createHeadlessSwapChain(tEngine, width, height, flags);
          PROXY(onComplete(swapChain));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySwapChain(tEngine, tSwapChain);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyViewRenderThread(TEngine *tEngine, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyView(tEngine, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySceneRenderThread(TEngine *tEngine, TScene *tScene, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyScene(tEngine, tScene);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine *tEngine, void (*onComplete)(TCamera *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto camera = Engine_createCamera(tEngine);
          PROXY(onComplete(camera));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *view = Engine_createView(tEngine);
          PROXY(onComplete(view));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroy(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture *tTexture, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyTexture(engine, tTexture);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySkybox(tEngine, tSkybox);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyIndirectLight(tEngine, tIndirectLight);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto material = Engine_buildMaterial(tEngine, materialData, length);
          PROXY(onComplete(material));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterial(tEngine, tMaterial);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterialInstance(tEngine, tMaterialInstance);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *fence = Engine_createFence(tEngine);
          PROXY(onComplete(fence));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyRenderThread(TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Fence_waitAndDestroy(tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyFence(tEngine, tFence);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_flushAndWait(tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_executeRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_execute(tEngine);
          std::packaged_task<void()> callback(
          [=]() mutable
          { 
            PROXY(onComplete(requestId));
          });
          _renderThread->add_task(callback);
          _renderThread->restart();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void execute_queue()
  {
#ifdef __EMSCRIPTEN__
    _renderThread->queue.execute();
#endif
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, TTexture *tTexture, void (*onComplete)(TSkybox *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *skybox = Engine_buildSkybox(tEngine, tTexture);
          PROXY(onComplete(skybox));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureRenderThread(
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    TTexture* tIrradianceTexture,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceTexture(tEngine, tReflectionsTexture, tIrradianceTexture, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsRenderThread(
    TEngine *tEngine,
    TTexture *tReflectionsTexture,
    float *harmonics,
    float intensity,
    void (*onComplete)(TIndirectLight *)) {
      std::packaged_task<void()> lambda(
          [=]() mutable
          {
            auto *indirectLight = Engine_buildIndirectLightFromIrradianceHarmonics(tEngine, tReflectionsTexture, harmonics, intensity);
            PROXY(onComplete(indirectLight));
          });
      auto fut = _renderThread->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = Renderer_beginFrame(tRenderer, tSwapChain, frameTimeInNanos);
          PROXY(onComplete(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_endFrame(tRenderer);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_render(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_renderStandaloneView(tRenderer, tView);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
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
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_setClearOptions(tRenderer, clearR, clearG, clearB, clearA, clearStencil, clear, discard);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
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
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_readPixels(tRenderer, width, height, xOffset, yOffset, tRenderTarget, tPixelBufferFormat, tPixelDataType, out, outLength);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createImageMaterial(tEngine);
          PROXY(onComplete(instance));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createGizmoMaterial(tEngine);
          PROXY(onComplete(instance));
        });
    auto fut = _renderThread->add_task(lambda);
  }

    EMSCRIPTEN_KEEPALIVE void Material_createOutlineMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createOutlineMaterial(tEngine);
          PROXY(onComplete(instance));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createInstance(tMaterial);
          PROXY(onComplete(instance));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createGridRenderThread(TEngine *tEngine, TMaterial * tMaterial, void (*onComplete)(TSceneAsset *)) {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *asset = SceneAsset_createGrid(tEngine, tMaterial);
          PROXY(onComplete(asset));
        });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneAsset_destroy(tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createGeometryRenderThread(
      TEngine *tEngine,
      float *vertices,
      uint32_t numVertices,
      float *normals,
      uint32_t numNormals,
      float *uvs,
      uint32_t numUvs,
      uint16_t *indices,
      uint32_t numIndices,
      TPrimitiveType tPrimitiveType,
      TMaterialInstance **materialInstances,
      int materialInstanceCount,
      void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto sceneAsset = SceneAsset_createGeometry(tEngine, vertices, numVertices, normals, numNormals, uvs, numUvs, indices, numIndices, tPrimitiveType, materialInstances, materialInstanceCount);
          PROXY(callback(sceneAsset));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      TNameComponentManager *tNameComponentManager,
      TFilamentAsset *tFilamentAsset,
      void (*onComplete)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto sceneAsset = SceneAsset_createFromFilamentAsset(tEngine, tAssetLoader, tNameComponentManager, tFilamentAsset);
          PROXY(onComplete(sceneAsset));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceRenderThread(
      TSceneAsset *asset, TMaterialInstance **tMaterialInstances,
      int materialInstanceCount,
      void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto instanceAsset = SceneAsset_createInstance(asset, tMaterialInstances, materialInstanceCount);
          PROXY(callback(instanceAsset));
        });
    auto fut = _renderThread->add_task(lambda);
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
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ColorGrading_createRenderThread(TEngine *tEngine, TToneMapping toneMapping, void (*callback)(TColorGrading *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto cg = ColorGrading_create(tEngine, toneMapping);
          PROXY(callback(cg));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingRenderThread(TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          Engine_destroyColorGrading(tEngine, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_pickRenderThread(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback)
  {
    auto *view = reinterpret_cast<View *>(tView);
    view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
               { PROXY(callback(requestId, utils::Entity::smuggle(result.renderable), result.depth, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z)); });
  }

  EMSCRIPTEN_KEEPALIVE void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setColorGrading(tView, tColorGrading);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBloom(tView, enabled, strength);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setCamera(tView, tCamera);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseRenderThread(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete) {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          AnimationManager_resetToRestPose(tAnimationManager, tSceneAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)(TAnimationManager *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *animationManager = AnimationManager_create(tEngine, tScene);
          PROXY(onComplete(animationManager));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesRenderThread(
      TAnimationManager *tAnimationManager,
      TSceneAsset *sceneAsset,
      void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = AnimationManager_updateBoneMatrices(tAnimationManager, sceneAsset);
          PROXY(callback(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsRenderThread(
      TAnimationManager *tAnimationManager,
      EntityId entityId,
      const float *const morphData,
      int numWeights,
      void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = AnimationManager_setMorphTargetWeights(tAnimationManager, entityId, morphData, numWeights);
          PROXY(callback(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_createEmptyRenderThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_createEmpty(width, height, channel);
          PROXY(onComplete(image));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t *data, size_t length, const char *name, bool alpha, void (*onComplete)(TLinearImage *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_decode(data, length, name, alpha);
          PROXY(onComplete(image));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto bytes = Image_getBytes(tLinearImage);
          PROXY(onComplete(bytes));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Image_destroy(tLinearImage);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto width = Image_getWidth(tLinearImage);
          PROXY(onComplete(width));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto height = Image_getHeight(tLinearImage);
          PROXY(onComplete(height));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto channels = Image_getChannels(tLinearImage);
          PROXY(onComplete(channels));
        });
    auto fut = _renderThread->add_task(lambda);
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
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *texture = Texture_build(tEngine, width, height, depth, levels, tUsage, import, sampler, format);
          PROXY(onComplete(texture));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsRenderThread(TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete) {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Texture_generateMipMaps(tTexture, tEngine);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
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

  
  EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureRenderThread(
    TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *)) {

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
    auto fut = _renderThread->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage,
                                                          TPixelDataFormat bufferFormat, TPixelDataType pixelDataType,
                                                          int level,
                                                          void (*onComplete)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_loadImage(tEngine, tTexture, tImage, bufferFormat, pixelDataType, level);
          PROXY(onComplete(result));
        });
    auto fut = _renderThread->add_task(lambda);
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
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_getColorTexture(tRenderTarget);
          PROXY(onComplete(texture));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_createRenderThread(
      TEngine *tEngine,
      uint32_t width,
      uint32_t height,
      TTexture *tColor,
      TTexture *tDepth,
      void (*onComplete)(TRenderTarget *))
  {
    auto color = reinterpret_cast<filament::Texture *>(tColor);
    auto depth = reinterpret_cast<filament::Texture *>(tDepth);

    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_create(tEngine, width, height, tColor, tDepth);
          PROXY(onComplete(texture));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyRenderThread(
      TEngine *tEngine,
      TRenderTarget *tRenderTarget,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          RenderTarget_destroy(tEngine, tRenderTarget);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_create();
          PROXY(onComplete(sampler));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringRenderThread(
      TSamplerMinFilter minFilter,
      TSamplerMagFilter magFilter,
      TSamplerWrapMode wrapS,
      TSamplerWrapMode wrapT,
      TSamplerWrapMode wrapR,
      void (*onComplete)(TTextureSampler *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithFiltering(minFilter, magFilter, wrapS, wrapT, wrapR);
          PROXY(onComplete(sampler));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonRenderThread(
      TSamplerCompareMode compareMode,
      TSamplerCompareFunc compareFunc,
      void (*onComplete)(TTextureSampler *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_createWithComparison(compareMode, compareFunc);
          PROXY(onComplete(sampler));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMinFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMinFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMagFilter filter,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMagFilter(sampler, filter);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeS(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeT(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeR(sampler, mode);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyRenderThread(
      TTextureSampler *sampler,
      double anisotropy,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setAnisotropy(sampler, anisotropy);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeRenderThread(
      TTextureSampler *sampler,
      TSamplerCompareMode mode,
      TTextureSamplerCompareFunc func,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setCompareMode(sampler, mode, func);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyRenderThread(
      TTextureSampler *sampler,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_destroy(sampler);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(
    TEngine *tEngine,
    TMaterialProvider *tMaterialProvider,
    TNameComponentManager *tNameComponentManager,
    void (*callback)(TGltfAssetLoader *))
  {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_create(tEngine, tMaterialProvider, tNameComponentManager);
        PROXY(callback(loader));
      });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfResourceLoader_create(tEngine);
        PROXY(callback(loader));
      });
    auto fut = _renderThread->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyRenderThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_destroy(tEngine, tResourceLoader);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_loadResources(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      const char *uri,
      uint8_t *data,
      size_t length,
      uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_addResourceData(tGltfResourceLoader, uri, data, length);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      TFilamentAsset *tFilamentAsset,
      void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncBeginLoad(tGltfResourceLoader, tFilamentAsset);
          PROXY(callback(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadRenderThread(
      TGltfResourceLoader *tGltfResourceLoader)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          GltfResourceLoader_asyncUpdateLoad(tGltfResourceLoader);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressRenderThread(
      TGltfResourceLoader *tGltfResourceLoader,
      void (*callback)(float))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto result = GltfResourceLoader_asyncGetLoadProgress(tGltfResourceLoader);
          PROXY(callback(result));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      uint8_t *data,
      size_t length,
      uint8_t numInstances,
      void (*callback)(TFilamentAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto loader = GltfAssetLoader_load(tEngine, tAssetLoader, data, length, numInstances);
          PROXY(callback(loader));
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene *tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Scene_addFilamentAsset(tScene, tAsset);
          PROXY(onComplete(requestId));
        });
    auto fut = _renderThread->add_task(lambda);
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
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *gizmo = Gizmo_create(tEngine, tAssetLoader, tGltfResourceLoader, tNameComponentManager, tView, tMaterial, tGizmoType);
          PROXY(callback(gizmo));
        });
    auto fut = _renderThread->add_task(lambda);
  }
}
