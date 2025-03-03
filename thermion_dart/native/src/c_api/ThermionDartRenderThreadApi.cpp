#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#include <filament/LightManager.h>

#include "c_api/APIBoundaryTypes.h"
#include "c_api/TEngine.h"
#include "c_api/TView.h"
#include "c_api/TSceneAsset.h"
#include "c_api/TSceneManager.h"
#include "c_api/TTexture.h"
#include "c_api/TAnimationManager.h"
#include "c_api/ThermionDartRenderThreadApi.h"

#include "FilamentViewer.hpp"
#include "Log.hpp"

#include "ThreadPool.hpp"

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>

class RenderLoop
{
public:
  explicit RenderLoop()
  {
    srand(time(NULL));
    t = new std::thread([this]()
                        { start(); });
  }

  ~RenderLoop()
  {
    _stop = true;
    _cv.notify_one();
    t->join();
  }

  static void mainLoop(void *arg)
  {
    ((RenderLoop *)arg)->iter();
  }

  static void *startHelper(void *parm)
  {
    ((RenderLoop *)parm)->start();
    return nullptr;
  }

  void start()
  {
    while (!_stop)
    {
      iter();
    }
  }

  void requestFrame(void (*callback)())
  {
    std::unique_lock<std::mutex> lock(_mutex);
    this->_requestFrameRenderCallback = callback;
    _cv.notify_one();
  }

  void iter()
  {
    {
      std::unique_lock<std::mutex> lock(_mutex);
      if (_requestFrameRenderCallback)
      {
        doRender();
        lock.unlock();
        this->_requestFrameRenderCallback();
        this->_requestFrameRenderCallback = nullptr;

        // Calculate and print FPS
        auto currentTime = std::chrono::high_resolution_clock::now();
        float deltaTime = std::chrono::duration<float, std::chrono::seconds::period>(currentTime - _lastFrameTime).count();
        _lastFrameTime = currentTime;

        _frameCount++;
        _accumulatedTime += deltaTime;

        if (_accumulatedTime >= 1.0f) // Update FPS every second
        {
          _fps = _frameCount / _accumulatedTime;
          // std::cout << "FPS: " << _fps << std::endl;
          _frameCount = 0;
          _accumulatedTime = 0.0f;
        }
      }
    }
    std::unique_lock<std::mutex> taskLock(_taskMutex);

    if (!_tasks.empty())
    {
      auto task = std::move(_tasks.front());
      _tasks.pop_front();
      taskLock.unlock();
      task();
      taskLock.lock();
    }

    _cv.wait_for(taskLock, std::chrono::microseconds(2000), [this]
                 { return !_tasks.empty() || _stop; });
  }

  void createViewer(void *const context,
                    void *const platform,
                    const char *uberArchivePath,
                    const ResourceLoaderWrapper *const loader,
                    void (*renderCallback)(void *),
                    void *const owner,
                    void (*callback)(TViewer *))
  {
    _renderCallback = renderCallback;
    _renderCallbackOwner = owner;
    std::packaged_task<void()> lambda([=]() mutable
                                      {
                                        auto viewer = (FilamentViewer *)Viewer_create(context, loader, platform, uberArchivePath);
                                        _viewer = reinterpret_cast<TViewer*>(viewer);
                                        callback(_viewer); });
    auto fut = add_task(lambda);
  }

  void destroyViewer(FilamentViewer *viewer)
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      _viewer = nullptr;
      Viewer_destroy(reinterpret_cast<TViewer*>(viewer)); });
    auto fut = add_task(lambda);
    fut.wait();
  }

  void doRender()
  {
    Viewer_render(_viewer);
    if (_renderCallback)
    {
      _renderCallback(_renderCallbackOwner);
    }
  }

  void setFrameIntervalInMilliseconds(float frameIntervalInMilliseconds)
  {
    _frameIntervalInMicroseconds = static_cast<int>(1000.0f * frameIntervalInMilliseconds);
  }

  template <class Rt>
  auto add_task(std::packaged_task<Rt()> &pt) -> std::future<Rt>
  {
    std::unique_lock<std::mutex> lock(_taskMutex);
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                          std::move(pt))]
                     { (*pt)(); });
    _cv.notify_one();
    return ret;
  }

private:
  void (*_requestFrameRenderCallback)() = nullptr;
  bool _stop = false;
  int _frameIntervalInMicroseconds = 1000000 / 60;
  std::mutex _mutex;
  std::mutex _taskMutex;
  std::condition_variable _cv;
  void (*_renderCallback)(void *const) = nullptr;
  void *_renderCallbackOwner = nullptr;
  std::deque<std::function<void()>> _tasks;
  TViewer *_viewer = nullptr;
  std::chrono::high_resolution_clock::time_point _lastFrameTime;
  int _frameCount = 0;
  float _accumulatedTime = 0.0f;
  float _fps = 0.0f;
  std::thread *t = nullptr;
};

extern "C"
{

  static RenderLoop *_rl;

  EMSCRIPTEN_KEEPALIVE void Viewer_createOnRenderThread(
      void *const context, void *const platform, const char *uberArchivePath,
      const void *const loader,
      void (*renderCallback)(void *const renderCallbackOwner),
      void *const renderCallbackOwner,
      void (*callback)(TViewer *))
  {

    if (!_rl)
    {
      _rl = new RenderLoop();
    }
    _rl->createViewer(context, platform, uberArchivePath, (const ResourceLoaderWrapper *const)loader,
                      renderCallback, renderCallbackOwner, callback);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_destroyOnRenderThread(TViewer *viewer)
  {
    _rl->destroyViewer((FilamentViewer *)viewer);
    delete _rl;
    _rl = nullptr;
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_createHeadlessSwapChainRenderThread(TViewer *viewer,
                                                                       uint32_t width,
                                                                       uint32_t height,
                                                                       void (*onComplete)(TSwapChain *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *swapChain = Viewer_createHeadlessSwapChain(viewer, width, height);
          onComplete(swapChain);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_createSwapChainRenderThread(TViewer *viewer,
                                                               void *const surface,
                                                               void (*onComplete)(TSwapChain *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto *swapChain = Viewer_createSwapChain(viewer, surface);
          onComplete(swapChain);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_destroySwapChainRenderThread(TViewer *viewer, TSwapChain *swapChain, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Viewer_destroySwapChain(viewer, swapChain);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_requestFrameRenderThread(TViewer *viewer, void (*onComplete)())
  {
    if (!_rl)
    {
      Log("No render loop!"); // PANIC?
    }
    else
    {
      _rl->requestFrame(onComplete);
    }
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_loadIblRenderThread(TViewer *viewer, const char *iblPath, float intensity, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Viewer_loadIbl(viewer, iblPath, intensity);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_removeIblRenderThread(TViewer *viewer, void (*onComplete)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Viewer_removeIbl(viewer);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_createRenderTargetRenderThread(TViewer *viewer, intptr_t texture, uint32_t width, uint32_t height, void (*onComplete)(TRenderTarget *))
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto renderTarget = Viewer_createRenderTarget(viewer, texture, width, height);
          onComplete(renderTarget);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_destroyRenderTargetRenderThread(TViewer *tViewer, TRenderTarget *tRenderTarget, void (*onComplete)()) {
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          Viewer_destroyRenderTarget(tViewer, tRenderTarget);
          onComplete();
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Engine_buildTextureRenderThread(TEngine *engine, 
    uint32_t width, 
    uint32_t height, 
    uint8_t levels, 
    TTextureSamplerType sampler, 
    TTextureFormat format,
    void (*onComplete)(TTexture*)
) {
  std::packaged_task<void()> lambda(
    [=]() mutable
    {
      auto texture = Engine_buildTexture(engine, width, height, levels, sampler, format);
      onComplete(texture);
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

  EMSCRIPTEN_KEEPALIVE void
  set_frame_interval_render_thread(TViewer *viewer, float frameIntervalInMilliseconds)
  {
    _rl->setFrameIntervalInMilliseconds(frameIntervalInMilliseconds);
    std::packaged_task<void()> lambda([=]() mutable
                                      { ((FilamentViewer *)viewer)->setFrameInterval(frameIntervalInMilliseconds); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_renderRenderThread(TViewer *viewer, TView *tView, TSwapChain *tSwapChain)
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { _rl->doRender(); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderThread(TViewer *viewer, TView *view, TSwapChain *tSwapChain, uint8_t *pixelBuffer, void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { Viewer_capture(viewer, view, tSwapChain, pixelBuffer, onComplete); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTargetRenderThread(TViewer *viewer, TView *view, TSwapChain *tSwapChain, TRenderTarget *tRenderTarget, uint8_t *pixelBuffer, void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { Viewer_captureRenderTarget(viewer, view, tSwapChain, tRenderTarget, pixelBuffer, onComplete); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  set_background_color_render_thread(TViewer *viewer, const float r, const float g,
                                     const float b, const float a)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        { set_background_color(viewer, r, g, b, a); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void SceneManager_createGridRenderThread(TSceneManager *tSceneManager, TMaterial *tMaterial, void (*callback)(TSceneAsset *))
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      auto *sceneAsset = SceneManager_createGrid(tSceneManager, tMaterial);
      callback(sceneAsset); 
    });
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

  EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstanceRenderThread(TSceneManager *tSceneManager, TMaterialInstance *tMaterialInstance, void (*callback)()) { 
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
                                        onComplete();
                                      });
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
  
  EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength) { 
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
            void (*callback)(EntityId entityId)) { 
std::packaged_task<void()> lambda(
        [=]() mutable
        {
          auto light = SceneManager_addLight(tSceneManager, type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, falloffRadius, spotLightConeInner, spotLightConeOuter, sunAngularRadius, sunHaloSize, sunHaloFallof, shadows);
          callback(light);
        });
    auto fut = _rl->add_task(lambda);
            }
  
  EMSCRIPTEN_KEEPALIVE void SceneManager_removeLightRenderThread(TSceneManager *tSceneManager, EntityId entityId, void (*callback)()) {
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

  EMSCRIPTEN_KEEPALIVE void unproject_texture_render_thread(TViewer *viewer, EntityId entity, uint8_t *input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          unproject_texture(viewer, entity, input, inputWidth, inputHeight, out, outWidth, outHeight);
          callback();
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
}
