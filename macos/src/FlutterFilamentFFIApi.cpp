
#include "FlutterFilamentFFIApi.h"

#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"
#include "filament/LightManager.h"

#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>

extern "C"
{
  extern FLUTTER_PLUGIN_EXPORT EMSCRIPTEN_WEBGL_CONTEXT_HANDLE flutter_filament_web_create_gl_context();
}

#endif 
#include <pthread.h>

using namespace polyvox;
using namespace std::chrono_literals;

class RenderLoop {
public:
  explicit RenderLoop() {
    _t = new std::thread([this]() {
      auto last = std::chrono::high_resolution_clock::now();
      while (!_stop) {

        auto now = std::chrono::high_resolution_clock::now();
        float elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());

        while(_frameIntervalInMilliseconds - elapsed > 5) {
          
          std::function<void()> task;
          std::unique_lock<std::mutex> lock(_access);
          if (_tasks.empty()) {
            std::this_thread::sleep_for(5ms);
            // _cond.wait_for(lock, std::chrono::duration<float, std::milli>(1));
            now = std::chrono::high_resolution_clock::now();
            elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());
            continue;
          }
          task = std::move(_tasks.front());
          _tasks.pop_front();
          task();
              
          now = std::chrono::high_resolution_clock::now();
          elapsed = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());
        }
        if (_rendering) {
          // Log("Rendering with %d tasks still pending",  _tasks.size());
          // auto frameStart = std::chrono::high_resolution_clock::now();
          doRender();
          // auto frameEnd = std::chrono::high_resolution_clock::now();
          // Log("Took %f milliseconds for render",           float(std::chrono::duration_cast<std::chrono::milliseconds>(frameEnd - frameStart).count()));
          
        } else { 
          Log("SKIP");
        }

        last = std::chrono::high_resolution_clock::now();
      }
    });
  }
  ~RenderLoop() {
    _stop = true;
    _t->join();
  }

  void *const createViewer(void *const context, void *const platform,
                           const char *uberArchivePath,
                           const ResourceLoaderWrapper *const loader,
                           void (*renderCallback)(void *), 
                           void *const owner,
                           void **out) {
    _renderCallback = renderCallback;
    _renderCallbackOwner = owner;
    std::packaged_task<FilamentViewer *()> lambda([=]() mutable {
      #ifdef __EMSCRIPTEN__     
        auto emContext = flutter_filament_web_create_gl_context();

        auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)emContext);
        if(success != EMSCRIPTEN_RESULT_SUCCESS) {
          std::cout << "Failed to make context current." << std::endl;
          return (FilamentViewer*)nullptr;
        }
        _viewer = new FilamentViewer((void* const) emContext, loader, platform, uberArchivePath);
      #else
        _viewer = new FilamentViewer(context, loader, platform, uberArchivePath);
      #endif
      if(out) {
          *out = _viewer;
      }
      return _viewer;
    });
    auto fut = add_task(lambda);
    if(out) {
      return nullptr;
    }
    fut.wait();
    _viewer = fut.get();
    return (void *const)_viewer;
  }

  void destroyViewer() {
    std::packaged_task<void()> lambda([&]() mutable {
      _rendering = false;
      destroy_filament_viewer(_viewer);
      _viewer = nullptr;
    });
    auto fut = add_task(lambda);
    fut.wait();
  }

  void setRendering(bool rendering) {
    std::packaged_task<void()> lambda(
        [&]() mutable { this->_rendering = rendering; });
    auto fut = add_task(lambda);
    fut.wait();   
  }

  void doRender() {
    auto now = std::chrono::high_resolution_clock::now();
    auto nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
    render(_viewer, 0, nullptr, nullptr, nullptr);
    _lastRenderTime = std::chrono::high_resolution_clock::now();

    #ifdef __EMSCRIPTEN__
      emscripten_webgl_commit_frame();
    #endif
        
    if(_renderCallback) {
      _renderCallback(_renderCallbackOwner);
    }
  }

  void setFrameIntervalInMilliseconds(float frameIntervalInMilliseconds) {
    _frameIntervalInMilliseconds = frameIntervalInMilliseconds;
  }

  template <class Rt>
  auto add_task(std::packaged_task<Rt()> &pt) -> std::future<Rt> {
    std::unique_lock<std::mutex> lock(_access);
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                          std::move(pt))] { (*pt)(); });
    // _cond.notify_one();
    // Log("Added task");
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

extern "C" {

static RenderLoop *_rl;

FLUTTER_PLUGIN_EXPORT void *const create_filament_viewer_ffi(
    void *const context, 
    void *const platform, 
    const char *uberArchivePath,
    const void* const loader, // must be const ResourceLoaderWrapper *const loader,
    void (*renderCallback)(void *const renderCallbackOwner),
    void *const renderCallbackOwner) {
  if (!_rl) {
    _rl = new RenderLoop();
  }
  return _rl->createViewer(context, platform, uberArchivePath, (const ResourceLoaderWrapper* const)loader,
                           renderCallback, renderCallbackOwner, nullptr);
}

FLUTTER_PLUGIN_EXPORT void create_filament_viewer_async_ffi(
    void *const context, 
    void *const platform, 
    const char *uberArchivePath,
    const void* const loader, // must be const ResourceLoaderWrapper *const loader,
    void (*renderCallback)(void *const renderCallbackOwner),
    void *const renderCallbackOwner,
    void **out) {
  if (!_rl) {
    _rl = new RenderLoop();
  }
  _rl->createViewer(context, platform, uberArchivePath, (const ResourceLoaderWrapper* const)loader,
                           renderCallback, renderCallbackOwner, out);
}

FLUTTER_PLUGIN_EXPORT void destroy_filament_viewer_ffi(void *const viewer) {
  _rl->destroyViewer();
}

FLUTTER_PLUGIN_EXPORT void create_swap_chain_ffi(void *const viewer,
                                                 void *const surface,
                                                 uint32_t width,
                                                 uint32_t height) {
  Log("Creating swapchain %dx%d", width, height);
  std::packaged_task<void()> lambda(
      [&]() mutable { create_swap_chain(viewer, surface, width, height); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void create_swap_chain_async_ffi(void *const viewer,
                                                 void *const surface,
                                                 uint32_t width,
                                                 uint32_t height, bool* complete) {
  Log("Creating swapchain %dx%d", width, height);
  std::packaged_task<void()> lambda(
      [=]() mutable { 
        create_swap_chain(viewer, surface, width, height); 
        *complete = true;
    });
  auto fut = _rl->add_task(lambda);
}

FLUTTER_PLUGIN_EXPORT void destroy_swap_chain_ffi(void *const viewer) {
  Log("Destroying swapchain");
  std::packaged_task<void()> lambda(
      [&]() mutable { 
        destroy_swap_chain(viewer); 
    });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void create_render_target_ffi(void *const viewer,
                                                    intptr_t nativeTextureId,
                                                    uint32_t width,
                                                    uint32_t height) {
  std::packaged_task<void()> lambda([&]() mutable {
    create_render_target(viewer, nativeTextureId, width, height);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection_ffi(
    void *const viewer, const uint32_t width, const uint32_t height,
    const float scaleFactor) {
  std::packaged_task<void()> lambda([&]() mutable {
    update_viewport_and_camera_projection(viewer, width, height, scaleFactor);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_rendering_ffi(void *const viewer,
                                             bool rendering) {
  if (!_rl) {
    Log("No render loop!"); // PANIC?
  } else {
    if (rendering) {
      Log("Set rendering to true");
    } else {
      Log("Set rendering to false");
    }
    _rl->setRendering(rendering);
  }
}

FLUTTER_PLUGIN_EXPORT void
set_frame_interval_ffi(float frameIntervalInMilliseconds) {
  _rl->setFrameIntervalInMilliseconds(frameIntervalInMilliseconds);
}

FLUTTER_PLUGIN_EXPORT void render_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&]() mutable { _rl->doRender(); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void
set_background_color_ffi(void *const viewer, const float r, const float g,
                         const float b, const float a) {
  std::packaged_task<void()> lambda(
      [&]() mutable { set_background_color(viewer, r, g, b, a); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT EntityId load_gltf_ffi(void *const assetManager,
                                             const char *path,
                                             const char *relativeResourcePath) {
  std::packaged_task<EntityId()> lambda([&]() mutable {
    return load_gltf(assetManager, path, relativeResourcePath);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT EntityId load_glb_ffi(void *const assetManager,
                                            const char *path) {
  std::packaged_task<EntityId()> lambda(
      [&]() mutable { auto entityId = load_glb(assetManager, path, false); 
      return entityId;
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void load_glb_async_ffi(void *const assetManager,
                                            const char *path, EntityId *out) {
  // capture-by-value as the [out] variable will go out of local scope if we don't wait() the future 
  // (even though we assume the underlying pointer address is still valid)
  std::packaged_task<void()> lambda(
      [=]() mutable { 
        *out = load_glb(assetManager, path, false);
  });
  auto fut = _rl->add_task(lambda);
}

FLUTTER_PLUGIN_EXPORT void clear_background_image_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_background_image(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_background_image_ffi(void *const viewer,
                                                    const char *path,
                                                    bool fillHeight) {
  std::packaged_task<void()> lambda(
      [&] { set_background_image(viewer, path, fillHeight); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_background_image_position_ffi(void *const viewer,
                                                             float x, float y,
                                                             bool clamp) {
  std::packaged_task<void()> lambda(
      [&] { set_background_image_position(viewer, x, y, clamp); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_tone_mapping_ffi(void *const viewer,
                                                int toneMapping) {
  std::packaged_task<void()> lambda(
      [&] { set_tone_mapping(viewer, toneMapping); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_bloom_ffi(void *const viewer, float strength) {
  std::packaged_task<void()> lambda([&] { set_bloom(viewer, strength); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void load_skybox_ffi(void *const viewer,
                                           const char *skyboxPath, bool* complete) {
  std::string skyboxPathString(skyboxPath);
  std::packaged_task<void()> lambda([=] { 
    load_skybox(viewer, skyboxPathString.c_str()); 
    if(complete) { 
      *complete = true;
    }
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();

  if(!complete) {
    fut.wait();
  }
}

FLUTTER_PLUGIN_EXPORT void load_ibl_ffi(void *const viewer, const char *iblPath,
                                        float intensity, bool* complete) {
  std::packaged_task<void()> lambda(
      [=] { 
        load_ibl(viewer, iblPath, intensity); 
        if(complete) {
          *complete = true;
        }
      });
  auto fut = _rl->add_task(lambda);
  if(!complete) {
    fut.wait();
  }
}

FLUTTER_PLUGIN_EXPORT void remove_skybox_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { remove_skybox(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void remove_ibl_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { remove_ibl(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

EntityId add_light_ffi(void *const viewer, uint8_t type, float colour,
                       float intensity, float posX, float posY, float posZ,
                       float dirX, float dirY, float dirZ, bool shadows) {
  std::packaged_task<EntityId()> lambda([&] {
    return add_light(viewer, type, colour, intensity, posX, posY, posZ, dirX,
                     dirY, dirZ, shadows);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

void add_light_async_ffi(void *const viewer, uint8_t type, float colour,
                       float intensity, float posX, float posY, float posZ,
                       float dirX, float dirY, float dirZ, bool shadows, EntityId* out) {
  std::packaged_task<void()> lambda([&] {
    *out = add_light(viewer, type, colour, intensity, posX, posY, posZ, dirX,
                     dirY, dirZ, shadows);
  });
  auto fut = _rl->add_task(lambda);

}

FLUTTER_PLUGIN_EXPORT void remove_light_ffi(void *const viewer,
                                            EntityId entityId) {
  std::packaged_task<void()> lambda([&] { remove_light(viewer, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void clear_lights_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_lights(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void remove_asset_ffi(void *const viewer,
                                            EntityId asset) {
  std::packaged_task<void()> lambda([&] { remove_asset(viewer, asset); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void clear_assets_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_assets(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT bool set_camera_ffi(void *const viewer, EntityId asset,
                                          const char *nodeName) {
  std::packaged_task<bool()> lambda(
      [&] { return set_camera(viewer, asset, nodeName); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void
get_morph_target_name_ffi(void *assetManager, EntityId asset,
                          const char *meshName, char *const outPtr, int index) {
  std::packaged_task<void()> lambda([&] {
    get_morph_target_name(assetManager, asset, meshName, outPtr, index);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT int
get_morph_target_name_count_ffi(void *assetManager, EntityId asset,
                                const char *meshName) {
  std::packaged_task<int()> lambda([&] {
    return get_morph_target_name_count(assetManager, asset, meshName);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}



FLUTTER_PLUGIN_EXPORT void play_animation_ffi(void *const assetManager,
                                              EntityId asset, int index,
                                              bool loop, bool reverse,
                                              bool replaceActive,
                                              float crossfade) {
  std::packaged_task<void()> lambda([&] {
    play_animation(assetManager, asset, index, loop, reverse, replaceActive,
                   crossfade);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_animation_frame_ffi(void *const assetManager,
                                                   EntityId asset,
                                                   int animationIndex,
                                                   int animationFrame) {
  std::packaged_task<void()> lambda([&] {
    set_animation_frame(assetManager, asset, animationIndex, animationFrame);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void stop_animation_ffi(void *const assetManager,
                                              EntityId asset, int index) {
  std::packaged_task<void()> lambda(
      [&] { stop_animation(assetManager, asset, index); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT int get_animation_count_ffi(void *const assetManager,
                                                  EntityId asset) {
  std::packaged_task<int()> lambda(
      [&] { return get_animation_count(assetManager, asset); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}
FLUTTER_PLUGIN_EXPORT void get_animation_name_ffi(void *const assetManager,
                                                  EntityId asset,
                                                  char *const outPtr,
                                                  int index) {
  std::packaged_task<void()> lambda(
      [&] { get_animation_name(assetManager, asset, outPtr, index); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_post_processing_ffi(void *const viewer,
                                                   bool enabled) {
  std::packaged_task<void()> lambda(
      [&] { set_post_processing(viewer, enabled); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void pick_ffi(void *const viewer, int x, int y,
                                    EntityId *entityId) {
  std::packaged_task<void()> lambda([&] { pick(viewer, x, y, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT const char *
get_name_for_entity_ffi(void *const assetManager, const EntityId entityId) {
  std::packaged_task<const char *()> lambda(
      [&] { return get_name_for_entity(assetManager, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

void set_morph_target_weights_ffi(void *const assetManager, 
                                  EntityId asset,
                                  const char *const entityName,
                                  const float *const morphData,
                                  int numWeights) {
    std::packaged_task<void()> lambda(
      [&] { return set_morph_target_weights(assetManager, asset, entityName, morphData, numWeights); });
      auto fut = _rl->add_task(lambda);
      fut.wait();
}

bool set_morph_animation_ffi(
		void *assetManager,
		EntityId asset,
		const char *const entityName,
		const float *const morphData,
		const int *const morphIndices,
		int numMorphTargets,
		int numFrames,
		float frameLengthInMs) {
      std::packaged_task<bool()> lambda(
      [&] { 
        return set_morph_animation(assetManager, asset, entityName, morphData, morphIndices, numMorphTargets, numFrames, frameLengthInMs); 
        });
    auto fut = _rl->add_task(lambda);
    fut.wait();
    return fut.get();
}

FLUTTER_PLUGIN_EXPORT bool set_bone_transform_ffi(
		void *assetManager,
		EntityId asset,
		const char *entityName,
		const float *const transform,
		const char *boneName) {
      std::packaged_task<bool()> lambda(
      [&] { return set_bone_transform(assetManager, asset, entityName, transform, boneName); });
      auto fut = _rl->add_task(lambda);
      fut.wait();
      return fut.get();
}

FLUTTER_PLUGIN_EXPORT void reset_to_rest_pose_ffi(void* const assetManager, EntityId entityId) {
  std::packaged_task<void()> lambda(
      [&] { return reset_to_rest_pose(assetManager, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void add_bone_animation_ffi(
		void *assetManager,
		EntityId asset,
		const float *const frameData,
		int numFrames,
		const char *const boneName,
		const char **const meshNames,
		int numMeshTargets,
		float frameLengthInMs,
		bool isModelSpace,
    bool* completed) {

        std::packaged_task<void()> lambda(
      [=] { 
        add_bone_animation(assetManager, asset, frameData, numFrames, boneName, meshNames, numMeshTargets, frameLengthInMs, isModelSpace); 
        *completed = true;
        });
      auto fut = _rl->add_task(lambda);
    if(!completed) {
      fut.wait();
    }
}

FLUTTER_PLUGIN_EXPORT void ios_dummy_ffi() { Log("Dummy called"); }
}
