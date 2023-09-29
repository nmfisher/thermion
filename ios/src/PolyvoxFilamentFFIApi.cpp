#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"


#include <thread>
#include <functional>

using namespace polyvox;

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))

class RenderLoop
{
public:
    explicit RenderLoop()
    {
        _t = new std::thread([this]()
                             {
			while(!_stop) {
				std::function<void()> task;
				{
					std::unique_lock<std::mutex> lock(_access);
					if(_tasks.empty()) {
						_cond.wait_for(lock, std::chrono::duration<int, std::milli>(5));
						continue;
					}
					task = std::move(_tasks.front());
					_tasks.pop_front();
                    std::this_thread::sleep_for(
                        std::chrono::milliseconds(_frameIntervalInMilliseconds));
                    if(_rendering) {
                        doRender();
                    }
                
                }

				task();
			} });
    }
    ~RenderLoop()
    {
        _stop = true;
        _t->join();
    }

    void *const createViewer(void *const context, const ResourceLoaderWrapper *const loader, void (*renderCallback)(void *), void *const owner)
    {
        _renderCallback = renderCallback;
        _renderCallbackOwner = owner;
        std::packaged_task<FilamentViewer *const()> lambda([&]() mutable
                                                           { return new FilamentViewer(context, loader); });
        auto fut = add_task(lambda);
        fut.wait();
        _viewer = fut.get();
        return (void *const)_viewer;
    }

    void setRendering(bool rendering)
    {
        _rendering = rendering;
    }

    void doRender()
    {
        render(_viewer, 0);
        _renderCallback(_renderCallbackOwner);
    }

    template <class Rt>
    auto add_task(std::packaged_task<Rt()> &pt) -> std::future<Rt>
    {
        std::unique_lock<std::mutex> lock(_access);
        auto ret = pt.get_future();
        _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(std::move(pt))]
                         { (*pt)(); });
        _cond.notify_one();
        return ret;
    }

private:
    bool _stop = false;
    bool _rendering = false;
    int _frameIntervalInMilliseconds = 1000 / 60;
    std::mutex _access;
    FilamentViewer *_viewer = nullptr;
    void (*_renderCallback)(void *const) = nullptr;
    void *_renderCallbackOwner = nullptr;
    std::thread *_t = nullptr;
    std::condition_variable _cond;
    std::deque<std::function<void()>> _tasks;
};

extern "C"
{
#include "PolyvoxFilamentApi.h"

    static RenderLoop *_rl;

    FLUTTER_PLUGIN_EXPORT void *const create_filament_viewer_ffi(void *const context, const ResourceLoaderWrapper *const loader, void (*renderCallback)(void *const renderCallbackOwner), void *const renderCallbackOwner)
    {
        if (!_rl)
        {
            _rl = new RenderLoop();
        }
        return _rl->createViewer(context, loader, renderCallback, renderCallbackOwner);
    }

    FLUTTER_PLUGIN_EXPORT void create_swap_chain_ffi(void *const viewer, void *const surface, uint32_t width, uint32_t height)
    {
        std::packaged_task<void()> lambda([&]() mutable
                                          { create_swap_chain(viewer, surface, width, height); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

    FLUTTER_PLUGIN_EXPORT void create_render_target_ffi(void *const viewer, uint32_t nativeTextureId, uint32_t width, uint32_t height)
    {
        std::packaged_task<void()> lambda([&]() mutable
                                          { create_render_target(viewer, nativeTextureId, width, height); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

    FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection_ffi(void *const viewer, const uint32_t width, const uint32_t height, const float scaleFactor)
    {
        std::packaged_task<void()> lambda([&]() mutable
                                          { update_viewport_and_camera_projection(viewer, width, height, scaleFactor); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

    FLUTTER_PLUGIN_EXPORT void set_rendering_ffi(bool rendering)
    {
        if (!_rl)
        {
            Log("No render loop!"); // PANIC?
        } else {
            if(rendering) {
                Log("Set rendering to true");
            } else { 
                Log("Set rendering to false");
            }
            _rl->setRendering(rendering);
        }
    }

    FLUTTER_PLUGIN_EXPORT void render_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]() mutable
                                          { _rl->doRender(); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

    FLUTTER_PLUGIN_EXPORT void set_background_color_ffi(void *const viewer, const float r, const float g, const float b, const float a)
    {
        std::packaged_task<void()> lambda([&]() mutable
                                          { set_background_color(viewer, r, g, b, a); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

    FLUTTER_PLUGIN_EXPORT EntityId load_glb_ffi(void *const assetManager, const char *path)
    {
        std::packaged_task<EntityId()> lambda([&]() mutable
                                              { return load_glb(assetManager, path, false); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
        return fut.get();
    }

    FLUTTER_PLUGIN_EXPORT void clear_background_image_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]
                                          { clear_background_image(viewer); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
    
   FLUTTER_PLUGIN_EXPORT void set_background_image_ffi(void *const viewer, const char *path, bool fillHeight)
    {
        std::packaged_task<void()> lambda([&]
                                          { set_background_image(viewer, path, fillHeight); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void set_background_image_position_ffi(void *const viewer, float x, float y, bool clamp)
    {
        std::packaged_task<void()> lambda([&]
                                          { set_background_image_position(viewer, x, y, clamp); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void set_tone_mapping_ffi(void *const viewer, int toneMapping)
    {
        std::packaged_task<void()> lambda([&]
                                          { set_tone_mapping(viewer, toneMapping); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void set_bloom_ffi(void *const viewer, float strength)
    {
        std::packaged_task<void()> lambda([&]
                                          { set_bloom(viewer, strength); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void load_skybox_ffi(void *const viewer, const char *skyboxPath)
    {
        std::packaged_task<void()> lambda([&]
                                          { load_skybox(viewer, skyboxPath); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void load_ibl_ffi(void *const viewer, const char *iblPath, float intensity)
    {
        std::packaged_task<void()> lambda([&]
                                          { load_ibl(viewer, iblPath, intensity); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void remove_skybox_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]
                                          { remove_skybox(viewer); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void remove_ibl_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]
                                          { remove_ibl(viewer); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
    EntityId add_light_ffi(void *const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows)
    {
        std::packaged_task<EntityId()> lambda([&]
                                              { return add_light(viewer, type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
        return fut.get();
    }
   FLUTTER_PLUGIN_EXPORT void remove_light_ffi(void *const viewer, EntityId entityId)
    {
        std::packaged_task<void()> lambda([&]
                                          { remove_light(viewer, entityId); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void clear_lights_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]
                                          { clear_lights(viewer); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }

   FLUTTER_PLUGIN_EXPORT void remove_asset_ffi(void *const viewer, EntityId asset)
    {
        std::packaged_task<void()> lambda([&]
                                          { remove_asset(viewer, asset); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
   FLUTTER_PLUGIN_EXPORT void clear_assets_ffi(void *const viewer)
    {
        std::packaged_task<void()> lambda([&]
                                          { clear_assets(viewer); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
    
    FLUTTER_PLUGIN_EXPORT bool set_camera_ffi(void *const viewer, EntityId asset, const char *nodeName)
    {
        std::packaged_task<bool()> lambda([&]
                                          { return set_camera(viewer, asset, nodeName); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
        return fut.get();
    }
    
   FLUTTER_PLUGIN_EXPORT void set_bone_animation_ffi(
        void *assetManager,
        EntityId asset,
        const float *const frameData,
        int numFrames,
        int numBones,
        const char **const boneNames,
        const char **const meshName,
        int numMeshTargets,
        float frameLengthInMs)
    {
        std::packaged_task<void()> lambda([&]
                                          { set_bone_animation(
                                                assetManager, asset, frameData, numFrames, numBones,
                                                boneNames, meshName, numMeshTargets, frameLengthInMs); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
    // implementations of rest of animation functions
    FLUTTER_PLUGIN_EXPORT void get_morph_target_name_ffi(void *assetManager, EntityId asset, const char *meshName, char *const outPtr, int index)
    {
        std::packaged_task<void()> lambda([&]
                                          { get_morph_target_name(assetManager, asset, meshName, outPtr, index); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
    }
    
    FLUTTER_PLUGIN_EXPORT int get_morph_target_name_count_ffi(void *assetManager, EntityId asset, const char *meshName)
    {
        std::packaged_task<int()> lambda([&]
                                         { return get_morph_target_name_count(assetManager, asset, meshName); });
        auto fut = _rl->add_task(lambda);
        fut.wait();
        return fut.get();
    }

    void set_morph_target_weights_ffi(
        void* const assetManager,
        EntityId asset,
        const char *const entityName,
        const float *const morphData,
        int numWeights
    ) { 
        // TODO
    }
}
