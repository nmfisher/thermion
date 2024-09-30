#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>

#include <emscripten/emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>

extern "C"
{
  extern EMSCRIPTEN_KEEPALIVE EMSCRIPTEN_WEBGL_CONTEXT_HANDLE thermion_dart_web_create_gl_context();
}
#endif

#include "ThermionDartRenderThreadApi.h"
#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"
#include "filament/LightManager.h"

#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

using namespace thermion;
using namespace std::chrono_literals;
#include <time.h>

class RenderLoop
{
public:
  explicit RenderLoop()
  {
    srand(time(NULL));
#ifdef __EMSCRIPTEN__
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    emscripten_pthread_attr_settransferredcanvases(&attr, "canvas");
    pthread_create(&t, &attr, &RenderLoop::startHelper, this);
#else
    t = new std::thread([this]()
                        { start(); });
#endif
  }

  ~RenderLoop()
  {
    _stop = true;
    swapChain = nullptr;
    _cv.notify_one();
#ifdef __EMSCRIPTEN__
    pthread_join(t, NULL);
#else
    t->join();
#endif
  }

  static void mainLoop(void *arg)
  {
    ((RenderLoop *)arg)->iter();
  }

  static void *startHelper(void *parm)
  {
#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop_arg(&RenderLoop::mainLoop, parm, 0, true);
#else
    ((RenderLoop *)parm)->start();
#endif
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
          std::cout << "FPS: " << _fps << std::endl;
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

    _cv.wait_for(taskLock, std::chrono::microseconds(1000), [this]
    { return !_tasks.empty() || _stop; });

  }

  void createViewer(void *const context,
                    void *const platform,
                    const char *uberArchivePath,
                    const ResourceLoaderWrapper *const loader,
                    void (*renderCallback)(void *),
                    void *const owner,
                    void (*callback)(TViewer*))
  {
    _renderCallback = renderCallback;
    _renderCallbackOwner = owner;
    std::packaged_task<void()> lambda([=]() mutable
                                      {
#ifdef __EMSCRIPTEN__
                                        _context = thermion_dart_web_create_gl_context();

                                        auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)_context);
                                        if (success != EMSCRIPTEN_RESULT_SUCCESS)
                                        {
                                          std::cout << "Failed to make context current." << std::endl;
                                          return;
                                        }
                                        glClearColor(0.0, 0.5, 0.5, 1.0);
                                        glClear(GL_COLOR_BUFFER_BIT);
                                        // emscripten_webgl_commit_frame();

                                        _viewer = (FilamentViewer *)Viewer_create((void *const)_context, loader, platform, uberArchivePath);
                                        MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, _viewer);
#else
    Log("CREATING1");

                                        auto viewer = (FilamentViewer *)Viewer_create(context, loader, platform, uberArchivePath);
                                        Log("CREATING2");
                                        _viewer = reinterpret_cast<TViewer*>(viewer);
                                        callback(_viewer);
#endif
                                      });
    auto fut = add_task(lambda);
  }

  void destroyViewer(FilamentViewer *viewer)
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      swapChain = nullptr;
      _viewer = nullptr;
      destroy_filament_viewer(reinterpret_cast<TViewer*>(viewer)); });
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

public:
  TSwapChain *swapChain;

private:
  void(*_requestFrameRenderCallback)()  = nullptr;
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

#ifdef __EMSCRIPTEN__
  pthread_t t;
  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE _context;
#else
  std::thread *t = nullptr;
#endif
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

  EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer_render_thread(TViewer *viewer)
  {
    _rl->destroyViewer((FilamentViewer *)viewer);
    delete _rl;
    _rl = nullptr;
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_createHeadlessSwapChainRenderThread(TViewer *viewer,
                                                            uint32_t width,
                                                            uint32_t height,
                                                            void (*onComplete)(TSwapChain*))
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
                                                            void (*onComplete)(TSwapChain*))
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
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, onComplete);
#else
          onComplete();
#endif
        });
    auto fut = _rl->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void Viewer_requestFrameRenderThread(TViewer *viewer, void(*onComplete)())
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
                                      { 
                                        _rl->doRender(); 
                                        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderThread(TViewer *viewer, TView *view, TSwapChain *tSwapChain, uint8_t *pixelBuffer, void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { Viewer_capture(viewer, view, tSwapChain, pixelBuffer, onComplete); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTargetRenderThread(TViewer *viewer, TView *view, TSwapChain *tSwapChain, TRenderTarget* tRenderTarget, uint8_t *pixelBuffer, void (*onComplete)())
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

  EMSCRIPTEN_KEEPALIVE void load_gltf_render_thread(TSceneManager *sceneManager,
                                                    const char *path,
                                                    const char *relativeResourcePath,
                                                    bool keepData,
                                                    void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda([=]() mutable
                                          {
    auto entity = load_gltf(sceneManager, path, relativeResourcePath, keepData);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0, $1);
          }, callback, entity);
#else
      callback(entity);
#endif
    return entity; });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_glb_render_thread(TSceneManager *sceneManager,
                                                   const char *path,
                                                   int numInstances,
                                                   bool keepData,
                                                   void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]() mutable
        {
          auto entity = load_glb(sceneManager, path, numInstances, keepData);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, entity);
#else
          callback(entity);
#endif
          return entity;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_glb_from_buffer_render_thread(TSceneManager *sceneManager,
                                                               const uint8_t *const data,
                                                               size_t length,
                                                               int numInstances,
                                                               bool keepData,
                                                               int priority,
                                                               int layer,
                                                               void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]() mutable
        {
          auto entity = load_glb_from_buffer(sceneManager, data, length, keepData, priority, layer);
          callback(entity);
          return entity;
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
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
          callback();
#endif
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
  
  EMSCRIPTEN_KEEPALIVE void load_skybox_render_thread(TViewer *viewer,
                                                      const char *skyboxPath,
                                                      void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
                                        load_skybox(viewer, skyboxPath);
#ifdef __EMSCRIPTEN__
                                        MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, onComplete);
#else
                                        onComplete();
#endif
                                      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_ibl_render_thread(TViewer *viewer, const char *iblPath,
                                                   float intensity)
  {
    std::packaged_task<void()> lambda(
        [=]
        { load_ibl(viewer, iblPath, intensity); });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void remove_skybox_render_thread(TViewer *viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { remove_skybox(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void remove_ibl_render_thread(TViewer *viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { remove_ibl(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void remove_entity_render_thread(TViewer *viewer,
                                                        EntityId asset, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
                                        remove_entity(viewer, asset);
#ifdef __EMSCRIPTEN__
                                        MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
                                        callback();
#endif
                                      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void clear_entities_render_thread(TViewer *viewer, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
                                        clear_entities(viewer);
#ifdef __EMSCRIPTEN__
                                        MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
                                        callback();
#endif
                                      });
    auto fut = _rl->add_task(lambda);
  }


  EMSCRIPTEN_KEEPALIVE void
  get_morph_target_name_render_thread(TSceneManager *sceneManager, EntityId assetEntity,
                                      EntityId childEntity, char *const outPtr, int index, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
                                        get_morph_target_name(sceneManager, assetEntity, childEntity, outPtr, index);
#ifdef __EMSCRIPTEN__
                                        MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
                                        callback();
#endif
                                      });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  get_morph_target_name_count_render_thread(TSceneManager *sceneManager, EntityId assetEntity,
                                            EntityId childEntity, void (*callback)(int))
  {
    std::packaged_task<int()> lambda([=]
                                     {
    auto count = get_morph_target_name_count(sceneManager, assetEntity, childEntity);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, count);
#else
    callback(count);
#endif
    return count; });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_animation_frame_render_thread(TSceneManager *sceneManager,
                                                              EntityId asset,
                                                              int animationIndex,
                                                              int animationFrame)
  {
    std::packaged_task<void()> lambda([=]
                                      { set_animation_frame(sceneManager, asset, animationIndex, animationFrame); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void stop_animation_render_thread(TSceneManager *sceneManager,
                                                         EntityId asset, int index)
  {
    std::packaged_task<void()> lambda(
        [=]
        { stop_animation(sceneManager, asset, index); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void get_animation_count_render_thread(TSceneManager *sceneManager,
                                                              EntityId asset,
                                                              void (*callback)(int))
  {
    std::packaged_task<int()> lambda(
        [=]
        {
          auto count = get_animation_count(sceneManager, asset);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, count);
#else
          callback(count);
#endif
          return count;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void get_animation_name_render_thread(TSceneManager *sceneManager,
                                                             EntityId asset,
                                                             char *const outPtr,
                                                             int index,
                                                             void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          get_animation_name(sceneManager, asset, outPtr, index);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
          callback();
#endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  get_name_for_entity_render_thread(TSceneManager *sceneManager, const EntityId entityId, void (*callback)(const char *))
  {
    std::packaged_task<const char *()> lambda(
        [=]
        {
          auto name = get_name_for_entity(sceneManager, entityId);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, name);
#else
          callback(name);
#endif
          return name;
        });
    auto fut = _rl->add_task(lambda);
  }

  void set_morph_target_weights_render_thread(TSceneManager *sceneManager,
                                              EntityId asset,
                                              const float *const morphData,
                                              int numWeights,
                                              void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto result = set_morph_target_weights(sceneManager, asset, morphData, numWeights);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, result);
#else
          callback(result);
#endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_bone_transform_render_thread(
      TSceneManager *sceneManager,
      EntityId asset,
      int skinIndex,
      int boneIndex,
      const float *const transform,
      void (*callback)(bool))
  {
    std::packaged_task<bool()> lambda(
        [=]
        {
          auto success = set_bone_transform(sceneManager, asset, skinIndex, boneIndex, transform);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, success);
#else
          callback(success);
#endif
          return success;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void update_bone_matrices_render_thread(TSceneManager *sceneManager,
                                                               EntityId entity, void (*callback)(bool))
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          auto success = update_bone_matrices(sceneManager, entity);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback, success);
#else
          callback(success);
#endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose_render_thread(TSceneManager *sceneManager, EntityId entityId, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          reset_to_rest_pose(sceneManager, entityId);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0); }, callback);
#else
          callback();
#endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void create_geometry_render_thread(
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
      TMaterialInstance *materialInstance,
      bool keepData,
      void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]
        {
          auto entity = create_geometry(sceneManager, vertices, numVertices, normals, numNormals, uvs, numUvs, indices, numIndices, primitiveType, materialInstance, keepData);
#ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({ moduleArg.dartFilamentResolveCallback($0, $1); }, callback, entity);
#else
          callback(entity);
#endif
          return entity;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void unproject_texture_render_thread(TViewer* viewer, EntityId entity, uint8_t *input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          unproject_texture(viewer, entity, input, inputWidth, inputHeight, out, outWidth, outHeight);
          callback();
        });
    auto fut = _rl->add_task(lambda);
  }
}
