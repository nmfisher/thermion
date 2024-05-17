#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>

#include <emscripten/threading.h>
#include <emscripten/val.h>

extern "C"
{
  extern EMSCRIPTEN_KEEPALIVE EMSCRIPTEN_WEBGL_CONTEXT_HANDLE flutter_filament_web_create_gl_context();
}
#include <pthread.h>


#endif

#include "DartFilamentFFIApi.h"

#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"
#include "filament/LightManager.h"

#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

using namespace flutter_filament;
using namespace std::chrono_literals;

void doSomeStuff(void* ptr) { 
  std::cout << "DOING SOME STUFF ON MAIN THREDA" << std::endl;
}

class RenderLoop
{
public:
  explicit RenderLoop()
  {
    _t = new std::thread([this]()
                         {
      auto last = std::chrono::high_resolution_clock::now();
      while (!_stop) {

        if (_rendering) {
          // auto frameStart = std::chrono::high_resolution_clock::now();
          doRender();
          // auto frameEnd = std::chrono::high_resolution_clock::now();
        }

        last = std::chrono::high_resolution_clock::now();

        auto now = std::chrono::high_resolution_clock::now();

        float elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());

        std::function<void()> task;

        std::unique_lock<std::mutex> lock(_access);

        if(_tasks.empty()) {
          _cond.wait_for(lock, std::chrono::duration<float, std::milli>(1));
        }
        while(!_tasks.empty()) {
          task = std::move(_tasks.front());
          _tasks.pop_front();
          task();
        }

        now = std::chrono::high_resolution_clock::now();
        elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());
        if(elapsed < _frameIntervalInMilliseconds) {
          auto sleepFor = std::chrono::microseconds(int(_frameIntervalInMilliseconds - elapsed) * 1000);
          std::this_thread::sleep_for(sleepFor);
        }
      } });
  }
  ~RenderLoop()
  {
    _stop = true;
    _t->join();
  }

  void createViewer(void *const context, void *const platform,
                    const char *uberArchivePath,
                    const ResourceLoaderWrapperImpl *const loader,
                    void (*renderCallback)(void *),
                    void *const owner,
                    void (*callback)(void *const))
  {
    _renderCallback = renderCallback;
    _renderCallbackOwner = owner;
    std::packaged_task<FilamentViewer *()> lambda([=]() mutable
                                                  {
#ifdef __EMSCRIPTEN__     
        auto emContext = flutter_filament_web_create_gl_context();

        auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)emContext);
        if(success != EMSCRIPTEN_RESULT_SUCCESS) {
          std::cout << "Failed to make context current." << std::endl;
          return (FilamentViewer*)nullptr;
        }
        // glClearColor(0.0, 1.0, 0.0, 1.0);
        // glClear(GL_COLOR_BUFFER_BIT);
        // emscripten_webgl_commit_frame();

        _viewer = new FilamentViewer((void* const) emContext, loader, platform, uberArchivePath);
        MAIN_THREAD_EM_ASM({
          moduleArg.dartFilamentResolveCallback($0, $1);
        }, callback, _viewer);
#else
        _viewer = new FilamentViewer(context, loader, platform, uberArchivePath);
        callback(_viewer);
#endif
      return _viewer; });
    auto fut = add_task(lambda);
  }

  void destroyViewer()
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
      _rendering = false;
      destroy_filament_viewer(_viewer);
      _viewer = nullptr; });
    auto fut = add_task(lambda);
  }

  void setRendering(bool rendering)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        { this->_rendering = rendering; });
    auto fut = add_task(lambda);
  }

  void doRender()
  {
    // auto now = std::chrono::high_resolution_clock::now();
    // auto nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
    render(_viewer, 0, nullptr, nullptr, nullptr);
    _lastRenderTime = std::chrono::high_resolution_clock::now();
    if (_renderCallback)
    {
      _renderCallback(_renderCallbackOwner);
    }
#ifdef __EMSCRIPTEN__
    emscripten_webgl_commit_frame();
#endif
  }

  void setFrameIntervalInMilliseconds(float frameIntervalInMilliseconds)
  {
    _frameIntervalInMilliseconds = frameIntervalInMilliseconds;
    Log("Set _frameIntervalInMilliseconds to %f", _frameIntervalInMilliseconds);
  }

  template <class Rt>
  auto add_task(std::packaged_task<Rt()> &pt) -> std::future<Rt>
  {
    std::unique_lock<std::mutex> lock(_access);
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                          std::move(pt))]
                     { (*pt)(); });
    _cond.notify_one();
    return ret;
  }

private:
  bool _stop = false;
  bool _rendering = false;
  float _frameIntervalInMilliseconds = 1000.0 / 60.0;
  std::mutex _access;
  FilamentViewer *_viewer = nullptr;
  void (*_renderCallback)(void *const) = nullptr;
  void *_renderCallbackOwner = nullptr;
  std::thread *_t = nullptr;
  std::condition_variable _cond;
  std::deque<std::function<void()>> _tasks;
  std::chrono::steady_clock::time_point _lastRenderTime = std::chrono::high_resolution_clock::now();
};

extern "C"
{

  static RenderLoop *_rl;

  EMSCRIPTEN_KEEPALIVE void create_filament_viewer_ffi(
      void *const context, void *const platform, const char *uberArchivePath,
      const void *const loader,
      void (*renderCallback)(void *const renderCallbackOwner),
      void *const renderCallbackOwner,
      void (*callback)(void *const))
  {

    if (!_rl)
    {
      _rl = new RenderLoop();
    }
    _rl->createViewer(context, platform, uberArchivePath, (const ResourceLoaderWrapperImpl *const)loader,
                      renderCallback, renderCallbackOwner, callback);
  }

  EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer_ffi(void *const viewer)
  {
    _rl->destroyViewer();
  }

  EMSCRIPTEN_KEEPALIVE void create_swap_chain_ffi(void *const viewer,
                                                   void *const surface,
                                                   uint32_t width,
                                                   uint32_t height,
                                                   void (*onComplete)())
  {
    Log("Creating swapchain %dx%d with viewer %d", width, height, viewer);
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          create_swap_chain(viewer, surface, width, height);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, onComplete);
          #else
          onComplete();
          #endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void destroy_swap_chain_ffi(void *const viewer, void (*onComplete)())
  {
    Log("Destroying swapchain");
    std::packaged_task<void()> lambda(
        [=]() mutable
        {
          destroy_swap_chain(viewer);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, onComplete);
          #else
          onComplete();
          #endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void create_render_target_ffi(void *const viewer,
                                                      intptr_t nativeTextureId,
                                                      uint32_t width,
                                                      uint32_t height,
                                                      void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      {
    create_render_target(viewer, nativeTextureId, width, height);
    #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, onComplete);
    #else
    onComplete(); 
    #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void update_viewport_and_camera_projection_ffi(
      void *const viewer, const uint32_t width, const uint32_t height,
      const float scaleFactor,
      void (*onComplete)())
  {
    Log("Update viewport  %dx%d", width, height);
    std::packaged_task<void()> lambda([=]() mutable
                                      {
    update_viewport_and_camera_projection(viewer, width, height, scaleFactor);
    #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, onComplete);
    #else
    onComplete(); 
    #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_rendering_ffi(void *const viewer,
                                               bool rendering)
  {
    if (!_rl)
    {
      Log("No render loop!"); // PANIC?
    }
    else
    {
      if (rendering)
      {
        Log("Set rendering to true");
      }
      else
      {
        Log("Set rendering to false");
      }
      _rl->setRendering(rendering);
    }
  }

  EMSCRIPTEN_KEEPALIVE void
  set_frame_interval_ffi(void* const viewer, float frameIntervalInMilliseconds)
  {
    _rl->setFrameIntervalInMilliseconds(frameIntervalInMilliseconds);
    std::packaged_task<void()> lambda([=]() mutable
                                      { ((FilamentViewer*)viewer)->setFrameInterval(frameIntervalInMilliseconds); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void render_ffi(void *const viewer)
  {
    std::packaged_task<void()> lambda([=]() mutable
                                      { _rl->doRender(); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  set_background_color_ffi(void *const viewer, const float r, const float g,
                           const float b, const float a)
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        { set_background_color(viewer, r, g, b, a); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_gltf_ffi(void *const sceneManager,
                                           const char *path,
                                           const char *relativeResourcePath,
                                           void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda([=]() mutable
                                          {
    auto entity = load_gltf(sceneManager, path, relativeResourcePath);
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

  EMSCRIPTEN_KEEPALIVE void load_glb_ffi(void *const sceneManager,
                                          const char *path, int numInstances, void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]() mutable
        {
          auto entity = load_glb(sceneManager, path, numInstances);
           #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0, $1);
          }, callback, entity);
          #else
            callback(entity);
          #endif
          return entity;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_glb_from_buffer_ffi(void *const sceneManager,
                                                      const void *const data, size_t length, int numInstances, void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]() mutable
        {
          auto entity = load_glb_from_buffer(sceneManager, data, length);
          callback(entity);
          return entity;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void clear_background_image_ffi(void *const viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { clear_background_image(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_background_image_ffi(void *const viewer,
                                                      const char *path,
                                                      bool fillHeight, void (*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        {
          set_background_image(viewer, path, fillHeight);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback);
          #else
          callback(); 
          #endif
        });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void set_background_image_position_ffi(void *const viewer,
                                                               float x, float y,
                                                               bool clamp)
  {
    std::packaged_task<void()> lambda(
        [=]
        { set_background_image_position(viewer, x, y, clamp); });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void set_tone_mapping_ffi(void *const viewer,
                                                  int toneMapping)
  {
    std::packaged_task<void()> lambda(
        [=]
        { set_tone_mapping(viewer, toneMapping); });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void set_bloom_ffi(void *const viewer, float strength)
  {
    std::packaged_task<void()> lambda([=]
                                      { set_bloom(viewer, strength); });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void load_skybox_ffi(void *const viewer,
                                             const char *skyboxPath,
                                             void (*onComplete)())
  {
    std::packaged_task<void()> lambda([=]
                                      { 
        load_skybox(viewer, skyboxPath); 
        #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, onComplete);
        #else
        onComplete(); 
        #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void load_ibl_ffi(void *const viewer, const char *iblPath,
                                          float intensity)
  {
    std::packaged_task<void()> lambda(
        [=]
        { load_ibl(viewer, iblPath, intensity); });
    auto fut = _rl->add_task(lambda);
  }
  EMSCRIPTEN_KEEPALIVE void remove_skybox_ffi(void *const viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { remove_skybox(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void remove_ibl_ffi(void *const viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { remove_ibl(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  void add_light_ffi(void *const viewer, uint8_t type, float colour,
                     float intensity, float posX, float posY, float posZ,
                     float dirX, float dirY, float dirZ, bool shadows, void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda([=]
                                          {
    auto entity = add_light(viewer, type, colour, intensity, posX, posY, posZ, dirX,
                     dirY, dirZ, shadows);
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

  EMSCRIPTEN_KEEPALIVE void remove_light_ffi(void *const viewer,
                                              EntityId entityId)
  {
    std::packaged_task<void()> lambda([=]
                                      { remove_light(viewer, entityId); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void clear_lights_ffi(void *const viewer)
  {
    std::packaged_task<void()> lambda([=]
                                      { clear_lights(viewer); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void remove_entity_ffi(void *const viewer,
                                               EntityId asset, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      {   
    remove_entity(viewer, asset); 
    #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback);
    #else
    callback(); 
    #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void clear_entities_ffi(void *const viewer, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      { 
      clear_entities(viewer); 
      #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback);
      #else
      callback(); 
      #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_camera_ffi(void *const viewer, EntityId asset,
                                            const char *nodeName, void (*callback)(bool))
  {
    std::packaged_task<bool()> lambda(
        [=]
        {
          auto success = set_camera(viewer, asset, nodeName);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, success);
          #else
          callback(success);
          #endif
          return success;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  get_morph_target_name_ffi(void *sceneManager, EntityId assetEntity,
                            EntityId childEntity, char *const outPtr, int index, void (*callback)())
  {
    std::packaged_task<void()> lambda([=]
                                      {
    get_morph_target_name(sceneManager, assetEntity, childEntity, outPtr, index);
    #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
        }, callback);
    #else
    callback(); 
    #endif
    });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  get_morph_target_name_count_ffi(void *sceneManager, EntityId assetEntity,
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

  EMSCRIPTEN_KEEPALIVE void play_animation_ffi(void *const sceneManager,
                                                EntityId asset, int index,
                                                bool loop, bool reverse,
                                                bool replaceActive,
                                                float crossfade)
  {
    std::packaged_task<void()> lambda([=]
                                      { play_animation(sceneManager, asset, index, loop, reverse, replaceActive,
                                                       crossfade); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_animation_frame_ffi(void *const sceneManager,
                                                     EntityId asset,
                                                     int animationIndex,
                                                     int animationFrame)
  {
    std::packaged_task<void()> lambda([=]
                                      { set_animation_frame(sceneManager, asset, animationIndex, animationFrame); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void stop_animation_ffi(void *const sceneManager,
                                                EntityId asset, int index)
  {
    std::packaged_task<void()> lambda(
        [=]
        { stop_animation(sceneManager, asset, index); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void get_animation_count_ffi(void *const sceneManager,
                                                     EntityId asset,
                                                     void (*callback)(int))
  {
    std::packaged_task<int()> lambda(
        [=]
        {
          auto count = get_animation_count(sceneManager, asset);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, count);
          #else
          callback(count);
          #endif
          return count;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void get_animation_name_ffi(void *const sceneManager,
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
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback);
          #else
          callback();
          #endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_post_processing_ffi(void *const viewer,
                                                     bool enabled)
  {
    std::packaged_task<void()> lambda(
        [=]
        { set_post_processing(viewer, enabled); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void
  get_name_for_entity_ffi(void *const sceneManager, const EntityId entityId, void (*callback)(const char *))
  {
    std::packaged_task<const char *()> lambda(
        [=]
        {
          auto name = get_name_for_entity(sceneManager, entityId);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, name);
          #else
          callback(name);
          #endif
          return name;
        });
    auto fut = _rl->add_task(lambda);
  }

  void set_morph_target_weights_ffi(void *const sceneManager,
                                    EntityId asset,
                                    const float *const morphData,
                                    int numWeights,
                                    void (*callback)(bool))
  {
    Log("Setting morph target weights");
    std::packaged_task<void()> lambda(
        [=]
        {
          Log("Setting in lambda");
          auto result = set_morph_target_weights(sceneManager, asset, morphData, numWeights);
          Log("Set, result was %d", result);
          #ifdef __EMSCRIPTEN__
          Log("emscripten");
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, result);
          #else
          callback(result);
          #endif
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void set_bone_transform_ffi(
      void *sceneManager,
      EntityId asset,
      const char *entityName,
      const float *const transform,
      const char *boneName,
      void (*callback)(bool))
  {
    std::packaged_task<bool()> lambda(
        [=]
        {
          auto success = set_bone_transform(sceneManager, asset, entityName, transform, boneName);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, success);
          #else
          callback(success);
          #endif
          return success;
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose_ffi(void *const sceneManager, EntityId entityId)
  {
    std::packaged_task<void()> lambda(
        [=]
        { return reset_to_rest_pose(sceneManager, entityId); });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void add_bone_animation_ffi(
      void *sceneManager,
      EntityId asset,
      const float *const frameData,
      int numFrames,
      const char *const boneName,
      const char **const meshNames,
      int numMeshTargets,
      float frameLengthInMs,
      bool isModelSpace)
  {

    std::packaged_task<void()> lambda(
        [=]
        {
          add_bone_animation(sceneManager, asset, frameData, numFrames, boneName, meshNames, numMeshTargets, frameLengthInMs, isModelSpace);
        });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void ios_dummy_ffi() { Log("Dummy called"); }

  EMSCRIPTEN_KEEPALIVE void create_geometry_ffi(void *const viewer, float *vertices, int numVertices, uint16_t *indices, int numIndices, int primitiveType, const char *materialPath, void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]
        {
          auto entity = create_geometry(viewer, vertices, numVertices, indices, numIndices, primitiveType, materialPath);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0,$1);
          }, callback, entity);
          #else
          callback(entity);
          #endif
          return entity;
        });
    auto fut = _rl->add_task(lambda);
  }
}
