#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#include <filament/LightManager.h>

#include "c_api/APIBoundaryTypes.h"
#include "c_api/TAnimationManager.h"
#include "c_api/TEngine.h"
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

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>

extern "C"
{

  static std::unique_ptr<RenderThread> _renderThread;

  EMSCRIPTEN_KEEPALIVE void RenderThread_create() {
    TRACE("RenderThread_create");
    if (_renderThread)
    {
      Log("WARNING - you are attempting to create a RenderThread when the previous one has not been disposed.");
    }
    _renderThread = std::make_unique<RenderThread>();
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_destroy() {
    TRACE("RenderThread_destroy");
    if (_renderThread)
    {
      _renderThread = nullptr;
    }
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_addTask(void (*task)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        task();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_setRenderTicker(TRenderTicker *tRenderTicker) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    _renderThread->setRenderTicker(renderTicker);
  }

  EMSCRIPTEN_KEEPALIVE void RenderThread_requestAnimationFrame(void (*onComplete)()) {
    _renderThread->requestFrame(onComplete);
  }

  
  EMSCRIPTEN_KEEPALIVE void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        RenderTicker_render(tRenderTicker, frameTimeInNanos);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(
    TBackend backend,
    void* platform,
    void* sharedContext,
    uint8_t stereoscopicEyeCount,
    bool disableHandleUseAfterFreeCheck,
    void (*onComplete)(TEngine *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto engine = Engine_create(backend, platform, sharedContext, stereoscopicEyeCount, disableHandleUseAfterFreeCheck);
        onComplete(engine);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto renderer = Engine_createRenderer(tEngine);
        onComplete(renderer);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto swapChain = Engine_createSwapChain(tEngine, window, flags);
        onComplete(swapChain);
      });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto swapChain = Engine_createHeadlessSwapChain(tEngine, width, height, flags);
        onComplete(swapChain);
      });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroySwapChain(tEngine, tSwapChain);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyViewRenderThread(TEngine *tEngine, TView *tView, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyView(tEngine, tView);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }
    
  EMSCRIPTEN_KEEPALIVE void Engine_destroySceneRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyScene(tEngine, tScene);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine* tEngine, void (*onComplete)(TCamera *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto camera = Engine_createCamera(tEngine);
        onComplete(camera);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto * view = Engine_createView(tEngine);
        onComplete(view);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderThread(TEngine *tEngine, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroy(tEngine);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture *tTexture, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyTexture(engine, tTexture);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, void (*onComplete)()) {
      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySkybox(tEngine, tSkybox);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }
    
  EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, void (*onComplete)()) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyIndirectLight(tEngine, tIndirectLight);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto material = Engine_buildMaterial(tEngine, materialData, length);
          onComplete(material);
        });
    auto fut = _renderThread->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterial(tEngine, tMaterial);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyMaterialInstance(tEngine, tMaterialInstance);
        onComplete();
      });
      auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*)) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *fence = Engine_createFence(tEngine);
        onComplete(fence);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyFence(tEngine, tFence);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThead(TEngine *tEngine, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_flushAndWait(tEngine);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, uint8_t *skyboxData, size_t length,  void (*onComplete)(TSkybox *),  void (*onTextureUploadComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *skybox = Engine_buildSkybox(tEngine, skyboxData, length, onTextureUploadComplete);
        onComplete(skybox);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightRenderThread(TEngine *tEngine, uint8_t *iblData, size_t length, float intensity, void (*onComplete)(TIndirectLight *), void (*onTextureUploadComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *indirectLight = Engine_buildIndirectLight(tEngine, iblData, length, intensity, onTextureUploadComplete);
        onComplete(indirectLight);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool)) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto result = Renderer_beginFrame(tRenderer, tSwapChain, frameTimeInNanos);
        onComplete(result);
      });
    auto fut = _renderThread->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_endFrame(tRenderer);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_render(tRenderer, tView);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_renderStandaloneView(tRenderer, tView);
        onComplete();
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
    bool discard, void (*onComplete)()) {
      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Renderer_setClearOptions(tRenderer, clearR, clearG, clearB, clearA, clearStencil, clear, discard);
          onComplete();
        });
      auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsRenderThread(
    TRenderer *tRenderer,
    TView *tView,
    TRenderTarget *tRenderTarget,
    TPixelDataFormat tPixelBufferFormat,
    TPixelDataType tPixelDataType,
    uint8_t *out,
    void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_readPixels(tRenderer, tView, tRenderTarget, tPixelBufferFormat, tPixelDataType, out);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *instance = Material_createImageMaterial(tEngine);
        onComplete(instance);
      });
      auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createInstance(tMaterial);
          onComplete(instance);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        SceneAsset_destroy(tSceneAsset);
        onComplete();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneAsset_loadGlbRenderThread(
    TEngine *tEngine,
    TGltfAssetLoader *tAssetLoader,
    TNameComponentManager *tNameComponentManager,
    uint8_t *data,
    size_t length,
    size_t numInstances,
    void (*callback)(TSceneAsset *)
  ) {
    std::packaged_task<void()> lambda(
      [=]
      {
        auto sceneAsset = SceneAsset_loadGlb(tEngine, tAssetLoader, tNameComponentManager, data, length, numInstances);
        callback(sceneAsset);
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
    void (*callback)(TSceneAsset *)
) {
  std::packaged_task<void()> lambda(
    [=]
    {
      auto sceneAsset = SceneAsset_createGeometry(tEngine, vertices, numVertices, normals, numNormals, uvs, numUvs, indices, numIndices, tPrimitiveType, materialInstances, materialInstanceCount);
      callback(sceneAsset);
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
          callback(instanceAsset);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(TMaterialProvider *tMaterialProvider, TMaterialKey *tKey, void (*callback)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto materialInstance = MaterialProvider_createMaterialInstance(tMaterialProvider, tKey);
          callback(materialInstance);
        });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void ColorGrading_createRenderThread(TEngine *tEngine, TToneMapping toneMapping, void (*callback)(TColorGrading *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto cg = ColorGrading_create(tEngine, toneMapping);
          callback(cg);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingRenderThread(TEngine *tEngine, TColorGrading *tColorGrading, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          Engine_destroyColorGrading(tEngine, tColorGrading);
          callback();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setColorGrading(tView, tColorGrading);
          callback();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBloom(tView, enabled, strength);
          callback();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setCamera(tView, tCamera);
          callback();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)(TAnimationManager *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *animationManager = AnimationManager_create(tEngine, tScene);
        onComplete(animationManager);
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
          callback(result);
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
          callback(result);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  // Add these implementations to your ThermionDartRenderThreadApi.cpp file

  // Image methods
  EMSCRIPTEN_KEEPALIVE void Image_createEmptyRenderThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_createEmpty(width, height, channel);
          onComplete(image);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t *data, size_t length, const char *name, void (*onComplete)(TLinearImage *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_decode(data, length, name);
          onComplete(image);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto bytes = Image_getBytes(tLinearImage);
          onComplete(bytes);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Image_destroy(tLinearImage);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto width = Image_getWidth(tLinearImage);
          onComplete(width);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto height = Image_getHeight(tLinearImage);
          onComplete(height);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto channels = Image_getChannels(tLinearImage);
          onComplete(channels);
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
    TTextureFormat format, void (*onComplete)(TTexture *)) {
      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *texture = Texture_build(tEngine, width, height, depth, levels, tUsage, import, sampler, format);
          onComplete(texture);
        });
    auto fut = _renderThread->add_task(lambda);  
    }

  // Texture methods
  EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage,
                                                          TPixelDataFormat bufferFormat, TPixelDataType pixelDataType,
                                                          void (*onComplete)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_loadImage(tEngine, tTexture, tImage, bufferFormat, pixelDataType);
          onComplete(result);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setImageRenderThread(
      TEngine *tEngine,
      TTexture *tTexture,
      uint32_t level,
      uint8_t *data,
      size_t size,
      uint32_t width,
      uint32_t height,
      uint32_t channels,
      uint32_t bufferFormat,
      uint32_t pixelDataType,
      void (*onComplete)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          bool result = Texture_setImage(tEngine, tTexture, level, data, size, width, height, channels,
                                         bufferFormat, pixelDataType);
          onComplete(result);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Texture_setImageWithDepthRenderThread(
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
    uint32_t channels,
    uint32_t depth,
    uint32_t bufferFormat,
    uint32_t pixelDataType,
    void (*onComplete)(bool)
) {
  std::packaged_task<void()> lambda(
      [=]() mutable
      {
        bool result = Texture_setImageWithDepth(
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
          channels,
          depth,
          bufferFormat,
          pixelDataType
        );
        onComplete(result);
      });
  auto fut = _renderThread->add_task(lambda);
}

  EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_getColorTexture(tRenderTarget);
          onComplete(texture);
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
          onComplete(texture);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  

  
  EMSCRIPTEN_KEEPALIVE void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_create();
          onComplete(sampler);
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
          onComplete(sampler);
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
          onComplete(sampler);
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMinFilter filter,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMinFilter(sampler, filter);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterRenderThread(
      TTextureSampler *sampler,
      TSamplerMagFilter filter,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setMagFilter(sampler, filter);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeS(sampler, mode);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeT(sampler, mode);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRRenderThread(
      TTextureSampler *sampler,
      TSamplerWrapMode mode,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setWrapModeR(sampler, mode);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyRenderThread(
      TTextureSampler *sampler,
      double anisotropy,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setAnisotropy(sampler, anisotropy);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeRenderThread(
      TTextureSampler *sampler,
      TSamplerCompareMode mode,
      TTextureSamplerCompareFunc func,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_setCompareMode(sampler, mode, func);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyRenderThread(
      TTextureSampler *sampler,
      void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          TextureSampler_destroy(sampler);
          onComplete();
        });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, void (*callback)(TGltfAssetLoader *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_create(tEngine, tMaterialProvider);
        callback(loader);
      });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, const char* relativeResourcePath, void (*callback)(TGltfResourceLoader *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfResourceLoader_create(tEngine, relativeResourcePath);
        callback(loader);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyRenderThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, void (*callback)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        GltfResourceLoader_destroy(tEngine, tResourceLoader);
        callback();
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto result = GltfResourceLoader_loadResources(tGltfResourceLoader, tFilamentAsset);
        callback(result);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataRenderThread(
    TGltfResourceLoader *tGltfResourceLoader,
    const char *uri,
    uint8_t *data,
    size_t length,
    void (*callback)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        GltfResourceLoader_addResourceData(tGltfResourceLoader, uri, data, length);
        callback();
      });
    auto fut = _renderThread->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
      TEngine *tEngine,
      TGltfAssetLoader *tAssetLoader,
      uint8_t *data,
      size_t length,
      uint8_t numInstances,
      void (*callback)(TFilamentAsset *)
  ) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_load(tEngine, tAssetLoader, data, length, numInstances);
        callback(loader);
      });
    auto fut = _renderThread->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, void (*callback)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Scene_addFilamentAsset(tScene, tAsset);
        callback();
      });
    auto fut = _renderThread->add_task(lambda);
  }
}
