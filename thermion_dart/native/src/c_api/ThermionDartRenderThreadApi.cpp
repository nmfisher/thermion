#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#include <filament/LightManager.h>

#include "c_api/APIBoundaryTypes.h"
#include "c_api/TAnimationManager.h"
#include "c_api/TEngine.h"
#include "c_api/TGltfAssetLoader.h"
#include "c_api/TRenderer.h"
#include "c_api/TRenderTarget.h"
#include "c_api/TScene.h"
#include "c_api/TSceneAsset.h"
#include "c_api/TSceneManager.h"
#include "c_api/TTexture.h"
#include "c_api/TView.h"
#include "c_api/ThermionDartRenderThreadApi.h"

#include "RenderTicker.hpp"
#include "rendering/RenderLoop.hpp"
#include "Log.hpp"

#include "ThreadPool.hpp"

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>

extern "C"
{

  static std::unique_ptr<RenderLoop> _rl;

  EMSCRIPTEN_KEEPALIVE void RenderLoop_create() {
    TRACE("RenderLoop_create");
    if (_rl)
    {
      Log("WARNING - you are attempting to create a RenderLoop when the previous one has not been disposed.");
    }
    _rl = std::make_unique<RenderLoop>();
  }

  EMSCRIPTEN_KEEPALIVE void RenderLoop_destroy() {
    TRACE("RenderLoop_destroy");
    if (_rl)
    {
      _rl = nullptr;
    }
  }

  
  EMSCRIPTEN_KEEPALIVE void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, , uint64_t frameTimeInNanos, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        RenderTicker_render(tRenderTicker, frameTimeInNanos);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(TBackend backend, void (*onComplete)(TEngine *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto engine = Engine_create(backend);
        onComplete(engine);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto renderer = Engine_createRenderer(tEngine);
        onComplete(renderer);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto swapChain = Engine_createSwapChain(tEngine, window, flags);
        onComplete(swapChain);
      });
    auto fut = _rl->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto swapChain = Engine_createHeadlessSwapChain(tEngine, width, height, flags);
        onComplete(swapChain);
      });
    auto fut = _rl->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroySwapChain(tEngine);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine* tEngine, void (*onComplete)(TCamera *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto camera = Engine_createCamera(tEngine);
        onComplete(camera);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto * view = Engine_createView(tEngine);
        onComplete(view);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture *tTexture, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyTexture(engine, tTexture);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, void (*onComplete)()) {
      std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroySkybox(tEngine, tSkybox);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }
    
  EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, void (*onComplete)()) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyIndirectLight(tEngine, tIndirectLight);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto material = Engine_buildMaterial(tEngine, materialData, length);
          onComplete(material);
        });
    auto fut = _rl->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Engine_destroyMaterial(tEngine, tMaterial);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*)) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *fence = Engine_createFence(tEngine);
        onComplete(fence);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_destroyFence(tEngine, tFence);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThead(TEngine *tEngine, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Engine_flushAndWait(tEngine);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, uint8_t *skyboxData, size_t length,  void (*onComplete)(TSkybox *),  void (*onTextureUploadComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *skybox = Engine_buildSkybox(tEngine, skyboxData, length, onTextureUploadComplete);
        onComplete(skybox);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightRenderThread(TEngine *tEngine, uint8_t *iblData, size_t length, float intensity, void (*onComplete)(TIndirectLight *), void (*onTextureUploadComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *indirectLight = Engine_buildIndirectLight(tEngine, iblData, length, intensity, onTextureUploadComplete);
        onComplete(indirectLight);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool)) { 
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto result = Renderer_beginFrame(tRenderer, tSwapChain, frameTimeInNanos);
        onComplete(result);
      });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_endFrame(tRenderer);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_render(tRenderer, tView);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Renderer_renderStandaloneView(tRenderer, tView);
        onComplete();
      });
    auto fut = _rl->add_task(lambda);
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
      auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *instance = Material_createInstance(tMaterial);
          onComplete(instance);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_renderRenderThread(TViewer *viewer, TView *tView, TSwapChain *tSwapChain)
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { _rl->doRender(); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createGridRenderThread(TSceneManager *tSceneManager, TMaterial *tMaterial, void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      auto *sceneAsset = SceneManager_createGrid(tSceneManager, tMaterial);
      callback(sceneAsset); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_loadGltfRenderThread(TSceneManager *sceneManager,
                                                              const char *path,
                                                              const char *relativeResourcePath,
                                                              bool keepData,
                                                              void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      auto entity = SceneManager_loadGltf(sceneManager, path, relativeResourcePath, keepData);
      callback(entity); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_loadGlbRenderThread(TSceneManager *sceneManager,
                                                             const char *path,
                                                             int numInstances,
                                                             bool keepData,
                                                             void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto asset = SceneManager_loadGlb(sceneManager, path, numInstances, keepData);
          callback(asset);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createGeometryRenderThread(
      TSceneManager *sceneManager,
      float *vertices,
      int numVertices,
      float *normals,
      int numNormals,
      float *uvs,
      int numUvs,
      uint16_t *indices,
      int numIndices,
      int primitiveType,
      TMaterialInstance **materialInstances,
      int materialInstanceCount,
      bool keepData,
      void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto *asset = SceneManager_createGeometry(sceneManager, vertices, numVertices, normals, numNormals, uvs, numUvs, indices, numIndices, primitiveType, materialInstances, materialInstanceCount, keepData);
          callback(asset);
        });
    auto fut = _rl->add_task(lambda);
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
  auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(TMaterialProvider *tMaterialProvider, TMaterialKey *tKey, void (*callback)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto materialInstance = MaterialProvider_createMaterialInstance(tMaterialProvider, tKey);
          callback(materialInstance);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstanceRenderThread(TSceneManager *tSceneManager, TMaterialInstance *tMaterialInstance, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          SceneManager_destroyMaterialInstance(tSceneManager, tMaterialInstance);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createUnlitMaterialInstanceRenderThread(TSceneManager *sceneManager, void (*callback)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto instance = SceneManager_createUnlitMaterialInstance(sceneManager);
          callback(instance);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createUnlitFixedSizeMaterialInstanceRenderThread(TSceneManager *sceneManager, void (*callback)(TMaterialInstance *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto instance = SceneManager_createUnlitFixedSizeMaterialInstance(sceneManager);
          callback(instance);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_loadGlbFromBufferRenderThread(TSceneManager *sceneManager,
                                                                       const uint8_t *const data,
                                                                       size_t length,
                                                                       int numInstances,
                                                                       bool keepData,
                                                                       int priority,
                                                                       int layer,
                                                                       bool loadResourcesAsync,
                                                                       void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *asset = SceneManager_loadGlbFromBuffer(sceneManager, data, length, numInstances, keepData, priority, layer, loadResourcesAsync);
          callback(asset);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void clear_background_image_render_thread(TViewer *viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { clear_background_image(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_background_image_render_thread(TViewer *viewer,
                                                               const char *path,
                                                               bool fillHeight, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          set_background_image(viewer, path, fillHeight);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_background_image_position_render_thread(TViewer *viewer,
                                                                        float x, float y,
                                                                        bool clamp)
  {
    std::packaged_task<void()> lambda(
        [=]
        { set_background_image_position(viewer, x, y, clamp); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_loadSkyboxRenderThread(TViewer *viewer,
                                                          const char *skyboxPath,
                                                          void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
                                        Viewer_loadSkybox(viewer, skyboxPath);
                                        onComplete(); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_removeSkyboxRenderThread(TViewer *viewer, void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]
                                      { 
                                        Viewer_removeSkybox(viewer); 
                                        onComplete(); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setToneMappingRenderThread(TView *tView, TEngine *tEngine, thermion::ToneMapping toneMapping)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setToneMapping(tView, tEngine, toneMapping);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength)
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setBloom(tView, enabled, strength);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          View_setCamera(tView, tCamera);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAllRenderThread(TSceneManager *tSceneManager, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneManager_destroyAll(tSceneManager);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmoRenderThread(
      TSceneManager *tSceneManager,
      TView *tView,
      TScene *tScene,
      TGizmoType tGizmoType,
      void (*onComplete)(TGizmo *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *gizmo = SceneManager_createGizmo(tSceneManager, tView, tScene, tGizmoType);
          onComplete(gizmo);
        });
    auto fut = _rl->add_task(lambda);
    return nullptr;
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_addLightRenderThread(
      TSceneManager *tSceneManager,
      uint8_t type,
      float colour,
      float intensity,
      float posX,
      float posY,
      float posZ,
      float dirX,
      float dirY,
      float dirZ,
      float falloffRadius,
      float spotLightConeInner,
      float spotLightConeOuter,
      float sunAngularRadius,
      float sunHaloSize,
      float sunHaloFallof,
      bool shadows,
      void (*callback)(EntityId entityId))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto light = SceneManager_addLight(tSceneManager, type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, falloffRadius, spotLightConeInner, spotLightConeOuter, sunAngularRadius, sunHaloSize, sunHaloFallof, shadows);
          callback(light);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_removeLightRenderThread(TSceneManager *tSceneManager, EntityId entityId, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneManager_removeLight(tSceneManager, entityId);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAssetRenderThread(TSceneManager *tSceneManager, TSceneAsset *tSceneAsset, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneManager_destroyAsset(tSceneManager, tSceneAsset);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAssetsRenderThread(TSceneManager *tSceneManager, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneManager_destroyAssets(tSceneManager);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyLightsRenderThread(TSceneManager *tSceneManager, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          SceneManager_destroyLights(tSceneManager);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createCameraRenderThread(TSceneManager *tSceneManager, void (*callback)(TCamera *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *camera = SceneManager_createCamera(tSceneManager);
          callback(reinterpret_cast<TCamera *>(camera));
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)(TAnimationManager *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto *animationManager = AnimationManager_create(tEngine, tScene);
        callback(animationManager);
      });
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t *data, size_t length, const char *name, void (*onComplete)(TLinearImage *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto image = Image_decode(data, length, name);
          onComplete(image);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto bytes = Image_getBytes(tLinearImage);
          onComplete(bytes);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Image_destroy(tLinearImage);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto width = Image_getWidth(tLinearImage);
          onComplete(width);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto height = Image_getHeight(tLinearImage);
          onComplete(height);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto channels = Image_getChannels(tLinearImage);
          onComplete(channels);
        });
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);  
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
  auto fut = _rl->add_task(lambda);
}

  EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto texture = RenderTarget_getColorTexture(tRenderTarget);
          onComplete(texture);
        });
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
  }

  

  
  EMSCRIPTEN_KEEPALIVE void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto sampler = TextureSampler_create();
          onComplete(sampler);
        });
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
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
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, void (*callback)(TGltfAssetLoader *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_create(tEngine, tMaterialProvider);
        callback(loader);
      });
    auto fut = _rl->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *)) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfResourceLoader_create(tEngine);
        callback(loader);
      });
    auto fut = _rl->add_task(lambda);
  }
  
  EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
      TGltfAssetLoader *tAssetLoader,
      TGltfResourceLoader *tResourceLoader,
      uint8_t *data,
      size_t length,
      uint8_t numInstances,
      void (*callback)(TFilamentAsset *)
  ) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        auto loader = GltfAssetLoader_load(tAssetLoader, tResourceLoader, data, length, numInstances);
        callback(loader);
      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, void (*callback)()) {
    std::packaged_task<void()> lambda(
      [=]() mutable
      {
        Scene_addFilamentAsset(tScene, tAsset);
        callback();
      });
    auto fut = _rl->add_task(lambda);
  }
}
