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

#include "ThermionDartFFIApi.h"
#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"
#include "filament/LightManager.h"

#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

using namespace thermion_filament;
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
    t = new std::thread([this]() {
      start();
    });
    #endif
  }

  ~RenderLoop()
  {
    _stop = true;
    #ifdef __EMSCRIPTEN__     
    pthread_join(t, NULL);
    #else
    t->join();
    #endif
    Log("Render loop killed");
  }

  static void mainLoop(void* arg) {
    ((RenderLoop*)arg)->iter();
  }

  static void *startHelper(void * parm) {
    #ifdef __EMSCRIPTEN__     
    emscripten_set_main_loop_arg(&RenderLoop::mainLoop, parm, 0, true);
    #else
    ((RenderLoop*)parm)->start();
    #endif
    return nullptr;
  }

  void start() { 
    while (!_stop) {
      iter();
    } 
  }

  void iter() { 
    
    auto frameStart = std::chrono::high_resolution_clock::now();
    if (_rendering) {
      doRender();
    }

    auto now = std::chrono::high_resolution_clock::now();

    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(now - frameStart).count();

    std::function<void()> task;

    std::unique_lock<std::mutex> lock(_access);
    while(true) {
        now = std::chrono::high_resolution_clock::now();
        elapsed = std::chrono::duration_cast<std::chrono::microseconds>(now - frameStart).count();
        if(elapsed >= _frameIntervalInMicroseconds) {
            break;
        }
        if(!_tasks.empty()) {
          task = std::move(_tasks.front());
          _tasks.pop_front();
          task();
        } else { 
          _cond.wait_for(lock, std::chrono::duration<float, std::milli>(1));
        }
    }
  }

  void createViewer(void *const context, 
                    void *const platform,
                    const char *uberArchivePath,
                    const ResourceLoaderWrapper *const loader,
                    void (*renderCallback)(void *),
                    void *const owner,
                    void (*callback)(void *const))
  {
    _renderCallback = renderCallback;
    _renderCallbackOwner = owner;
    std::packaged_task<void()> lambda([=]() mutable
                                                  {
#ifdef __EMSCRIPTEN__     
        _context = thermion_dart_web_create_gl_context();

        auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)_context);
        if(success != EMSCRIPTEN_RESULT_SUCCESS) {
          std::cout << "Failed to make context current." << std::endl;
          return;
        }
        glClearColor(0.0, 0.5, 0.5, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        // emscripten_webgl_commit_frame();

        _viewer = (FilamentViewer*) create_filament_viewer((void* const) _context, loader, platform, uberArchivePath);
        MAIN_THREAD_EM_ASM({
          moduleArg.dartFilamentResolveCallback($0, $1);
        }, callback, _viewer);
#else
        _viewer = (FilamentViewer*)create_filament_viewer(context, loader, platform, uberArchivePath);
        callback(_viewer);
#endif
    });
    auto fut = add_task(lambda);
  }

  void destroyViewer(FilamentViewer* viewer) 
  {
    std::packaged_task<void()> lambda([=]() mutable {
      _rendering = false;
      _viewer = nullptr;
      destroy_filament_viewer(viewer);
    });
    auto fut = add_task(lambda);
  }

  void setRendering(bool rendering, void(*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]() mutable
        { 
          this->_rendering = rendering; 
            #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback);
          #else
            callback();
          #endif
      });
    auto fut = add_task(lambda);
  }

  void doRender()
  {
    #ifdef __EMSCRIPTEN__
    if(emscripten_is_webgl_context_lost(_context) == EM_TRUE) {
      Log("Context lost");
      auto sleepFor = std::chrono::seconds(1);
      std::this_thread::sleep_for(sleepFor);
      return;
    }
    #endif
    render(_viewer, 0, nullptr, nullptr, nullptr);
    if (_renderCallback)
    {
      _renderCallback(_renderCallbackOwner);
    }
#ifdef __EMSCRIPTEN__
    // emscripten_webgl_commit_frame();
#endif
  }

  void setFrameIntervalInMilliseconds(float frameIntervalInMilliseconds)
  {
    _frameIntervalInMicroseconds = static_cast<int>(1000.0f * frameIntervalInMilliseconds);
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

  bool _stop = false;
  bool _rendering = false;
  int _frameIntervalInMicroseconds = 1000000.0 / 60.0;
  std::mutex _access;
  void (*_renderCallback)(void *const) = nullptr;
  void *_renderCallbackOwner = nullptr;

  
  std::condition_variable _cond;
  std::deque<std::function<void()>> _tasks;
  FilamentViewer* _viewer = nullptr;
  #ifdef __EMSCRIPTEN__
  pthread_t t;
  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE _context;
  int _frameNum = 0;
  #else
  std::thread *t = nullptr;
  #endif
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
    _rl->createViewer(context, platform, uberArchivePath, (const ResourceLoaderWrapper *const)loader,
                      renderCallback, renderCallbackOwner, callback);
  }

  EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer_ffi(void *const viewer)
  {
    _rl->destroyViewer((FilamentViewer*)viewer);
    delete _rl;
    _rl = nullptr;
  }

  EMSCRIPTEN_KEEPALIVE void create_swap_chain_ffi(void *const viewer,
                                                   void *const surface,
                                                   uint32_t width,
                                                   uint32_t height,
                                                   void (*onComplete)())
  {
    Log("Creating swapchain %dx%d with viewer %lu & surface %lu", width, height, viewer, surface);
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
                                               bool rendering, void (*callback)())
  {
    if (!_rl)
    {
      Log("No render loop!"); // PANIC?
    }
    else
    {
      _rl->setRendering(rendering, callback);
      if (rendering)
      {
        Log("Set rendering to true");
      }
      else
      {
        Log("Set rendering to false");
      }
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

  EMSCRIPTEN_KEEPALIVE void capture_ffi(void *const viewer, uint8_t* pixelBuffer, void (*onComplete)()) {
    std::packaged_task<void()> lambda([=]() mutable
                                      { capture(viewer, pixelBuffer, onComplete); });
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

  EMSCRIPTEN_KEEPALIVE void load_glb_ffi(void *const sceneManager,
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
                                                      const void *const data, 
                                                      size_t length, 
                                                      int numInstances, 
                                                      bool keepData,
                                                      void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda(
        [=]() mutable
        {
          auto entity = load_glb_from_buffer(sceneManager, data, length, keepData);
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

  void add_light_ffi(
    void *const viewer, 
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
    void (*callback)(EntityId))
  {
    std::packaged_task<EntityId()> lambda([=]
                                          {
    auto entity = add_light(
      viewer, 
      type,
      colour,
      intensity,
      posX,
      posY,
      posZ,
      dirX,
      dirY,
      dirZ,
      falloffRadius,
      spotLightConeInner,
      spotLightConeOuter,
      sunAngularRadius, 
      sunHaloSize,
      sunHaloFallof,
      shadows);
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
    std::packaged_task<void()> lambda(
        [=]
        {
          auto result = set_morph_target_weights(sceneManager, asset, morphData, numWeights);
          #ifdef __EMSCRIPTEN__
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

  EMSCRIPTEN_KEEPALIVE void update_bone_matrices_ffi(void *sceneManager,
        EntityId entity, void(*callback)(bool)) {
    std::packaged_task<void()> lambda(
        [=]
        { 
          auto success = update_bone_matrices(sceneManager, entity);
          #ifdef __EMSCRIPTEN__
          MAIN_THREAD_EM_ASM({
            moduleArg.dartFilamentResolveCallback($0);
          }, callback, success);
          #else
          callback(success);
          #endif
         });
    auto fut = _rl->add_task(lambda);
  }

  EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose_ffi(void *const sceneManager, EntityId entityId, void(*callback)())
  {
    std::packaged_task<void()> lambda(
        [=]
        { 
          reset_to_rest_pose(sceneManager, entityId); 
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

  EMSCRIPTEN_KEEPALIVE void create_geometry_ffi(
    void *const viewer, 
    float *vertices, 
    int numVertices, 
    uint16_t *indices, 
    int numIndices, 
    int primitiveType, 
    const char *materialPath, 
    void (*callback)(EntityId))
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
