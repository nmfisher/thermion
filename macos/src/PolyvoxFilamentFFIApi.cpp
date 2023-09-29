#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

using namespace polyvox;

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))

class RenderLoop {
public:
    explicit RenderLoop() { 
        _t = new std::thread([this]() {
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
                }

				task();
			}
		});
	}
	~RenderLoop() {
		_stop = true;
        _t->join();
	}

    void setRendering(bool rendering) {
        _rendering = rendering;
    }

	template<class Rt>
	auto add_task(std::packaged_task<Rt()>& pt) -> std::future<Rt> {
		std::unique_lock<std::mutex> lock(_access);
		auto ret = pt.get_future();
		_tasks.push_back([pt=std::make_shared<std::packaged_task<Rt()>>(std::move(pt))]{ (*pt)();});
		_cond.notify_one();
		return ret;
	}
private: 
    bool _stop = false;
    bool _rendering = false;
    int _frameIntervalInMilliseconds = 1000 / 60;
	std::mutex _access;
    FilamentViewer* _viewer = nullptr;
    std::thread* _t = nullptr;
	std::condition_variable _cond;
	std::deque<std::function<void()>> _tasks;

};



extern "C" {

  #include "PolyvoxFilamentApi.h"

  static RenderLoop* _rl;

  FLUTTER_PLUGIN_EXPORT const void* create_filament_viewer_ffi(const void* context, const ResourceLoaderWrapper* const loader) {
    if(!_rl) {
        _rl = new RenderLoop();
    }
    std::packaged_task<const void*()> lambda([&]() mutable  {
        return (const void*) new FilamentViewer(context, loader);
    });
    auto fut = _rl->add_task(lambda);
    fut.wait();
    return fut.get();
  }
  

  FLUTTER_PLUGIN_EXPORT bool set_rendering(bool rendering) {
      if(!_rl) {
        return false;
      }
      _rl->setRendering(rendering);
      return true;
  }

  FLUTTER_PLUGIN_EXPORT void render_ffi(void* const viewer) {
    std::packaged_task<void()> lambda([&]() mutable  {
        render(viewer, 0);
    });
    auto fut = _rl->add_task(lambda);
    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_background_color_ffi(const void* const viewer, const float r, const float g, const float b, const float a) {
    std::packaged_task<void()> lambda([&]() mutable  {
        set_background_color(viewer, r, g,b, a);
    });
    auto fut = _rl->add_task(lambda);
    fut.wait();
  }

}
