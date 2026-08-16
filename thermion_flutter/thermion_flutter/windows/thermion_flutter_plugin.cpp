#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")

#include "thermion_flutter_plugin.h"

// Dart API DL for port-based frame scheduling (hot restart safe)
#include "dart/dart_api_dl.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <codecvt>
#include <cstring>
#include <filesystem>
#include <fstream>

#include <iostream>
#include <locale>
#include <map>
#include <math.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <atomic>
#include <set>
#include <utility>

#include "flutter_d3d_texture.h"

// Declared here rather than by including c_api/ThermionDartRenderThreadApi.h:
// that header drags in the whole T* API surface, and this translation unit is
// already sensitive to Filament header ordering (see the utils::io forward
// declaration in the plugin header). DLL_EXPORT resolves to dllimport here
// (THERMION_WIN32_KHR_BUILD) and to dllexport inside thermion_dart, which is
// the same pairing WindowsVulkanContext already uses.
namespace thermion
{
  extern "C"
  {
    DLL_EXPORT bool EngineLifecycle_lock(int timeoutMs);
    DLL_EXPORT void EngineLifecycle_unlock();
  }
}

namespace thermion::tflutter::windows
{

  using namespace std::chrono_literals;

  // How long window teardown waits for an in-flight engine creation on the
  // shared render thread. Long enough to cover a real create (hundreds of ms
  // to a few seconds on a cold Vulkan device), short enough that a wedged
  // create cannot make a window unclosable.
  constexpr int kEngineCreateDrainMs = 10000;

  // Static member initialization for Dart API DL
  bool ThermionFlutterPlugin::_dartApiInitialized = false;

  // The rendering context is PROCESS-WIDE, matching the file-static
  // _flutterTextures / _blitQueue / _blitWorker / _contextMutex below.
  //
  // Windows registers one ThermionFlutterPlugin per FlutterEngine, and
  // desktop_multi_window spawns an engine per sub-window. With a per-instance
  // context the second engine saw `_context == nullptr` and constructed a
  // SECOND WindowsVulkanContext — a second VkInstance whose
  // `bluevk::bindInstance()` rebound the PROCESS-GLOBAL Vulkan dispatch table
  // underneath the first context's still-running blit worker and Filament
  // render thread. The result was an access violation on a non-main thread
  // with no Dart exception and no Windows Error Reporting entry.
  //
  // Sharing one context also matches the surrounding state: `_flutterTextures`
  // is already a file-static shared across instances.
  //
  // LIFETIME: the context is PROCESS-IMMORTAL. `destroyContext` arrives from
  // `FilamentApp.onDestroy`, i.e. once per ENGINE, and a single engine's
  // shutdown cannot prove that no other engine still has live render or blit
  // threads using it. Nulling it let a later engine construct a second context
  // and rebind BlueVK underneath the first; deleting it would be a plain
  // use-after-free. Keeping it alive leaks exactly one context per process.
  // FUTURE: refcounted leases so the last engine out can genuinely release it.
  //
  // All access is under `_contextMutex` via `EnsureContextLocked()`.
  thermion::vulkan::windows::WindowsVulkanContext *ThermionFlutterPlugin::_context = nullptr;

  thermion::vulkan::windows::WindowsVulkanContext *
  ThermionFlutterPlugin::EnsureContextLocked() {
    if (!_context) {
      _context = new thermion::vulkan::windows::WindowsVulkanContext();
    }
    return _context;
  }

  // The context (VkInstance/VkDevice) is process-wide, but a filament
  // Platform belongs to one Engine, and Windows registers one plugin per
  // FlutterEngine. Handing a single platform to two engines re-ran Vulkan
  // device selection on the live object underneath the first engine.
  // Cached per instance so a hot restart's second getRenderingContext keeps
  // the same platform (the pre-existing single-engine behaviour).
  filament::backend::Platform *ThermionFlutterPlugin::EnginePlatformLocked() {
    if (!_enginePlatform) {
      _enginePlatform = EnsureContextLocked()->CreatePlatform();
    }
    return _enginePlatform;
  }

  // Defined below alongside the blit-worker state they manage; declared here
  // because the constructor and destructor appear above that block.
  static void AcquireBlitWorker();
  static void ReleaseBlitWorker();

  void ThermionFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "dev.thermion.flutter/event",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ThermionFlutterPlugin>(
        registrar->texture_registrar(), registrar, channel);

    registrar->AddPlugin(std::move(plugin));
  }

  ThermionFlutterPlugin::ThermionFlutterPlugin(
      flutter::TextureRegistrar *textureRegistrar,
      flutter::PluginRegistrarWindows *pluginRegistrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> &channel)
      : _textureRegistrar(textureRegistrar), _pluginRegistrar(pluginRegistrar),
        _channel(std::move(channel))
  {

    AcquireBlitWorker();

    // attach the method call handler for incoming messages
    _channel->SetMethodCallHandler([=](const auto &call, auto result)
                                   { this->HandleMethodCall(call, std::move(result)); });
  }

  // this is only for storing Flutter surface descriptors
  // (as opposed to the D3D/Vulkan handles, which are stored in the WindowsVulkanContext)
  static std::vector<std::unique_ptr<FlutterD3DTexture>> _flutterTextures;

  // ────────────────────────────────────────────────────────────────
  // Dedicated Blit-worker thread
  // ────────────────────────────────────────────────────────────────
  //
  // Why: `markTextureFrameAvailable` was originally synchronous on
  // the Flutter UI thread, calling `WindowsVulkanContext::Blit` which
  // includes vkQueueSubmit + vkWaitForFences. Under multi-viewer
  // load (8 viewers × Filament frames) this saturated the UI
  // thread, killed the Win32 message pump, and Windows declared
  // "Not Responding". A first naive fix spawned a detached
  // `std::thread` per call — but `WindowsVulkanContext::Blit`'s
  // shared command pool / queue / fence are NOT thread-safe (the
  // Vulkan spec requires app-side synchronisation of VkQueue
  // access), and the Intel driver crashed with `0xC0000005`
  // access-violation inside `igvk64.dll` as soon as two Blits
  // overlapped.
  //
  // Correct fix: ONE worker thread, ONE queue, one Blit in flight
  // at any moment. The UI thread enqueues and returns immediately.
  // If the queue grows past kMaxBlitQueueDepth the OLDEST entry is
  // dropped — Flutter shows a previously-blitted texture for one
  // frame, which is preferable to unbounded queue growth under
  // sustained GPU pressure.
  // Texture identity is (owning registrar, Flutter texture ID). Texture and
  // retirement state are process-global while registrars are per-engine, and
  // IDs are pointer-derived and therefore recyclable, so an ID alone is not a
  // stable identity: a stale retire(old) landing after a create(new) that
  // reused the ID would mute the new texture.
  using TextureKey = std::pair<flutter::TextureRegistrar*, int64_t>;

  struct BlitJob {
    thermion::vulkan::windows::WindowsVulkanContext* context;
    flutter::TextureRegistrar* registrar;
    HANDLE handle;
    int64_t flutterTextureId;

    TextureKey key() const { return TextureKey{registrar, flutterTextureId}; }
  };

  static constexpr size_t kMaxBlitQueueDepth = 16;

  static std::mutex _blitMutex;
  // WindowsVulkanContext owns one command buffer/queue and parallel vectors of
  // surface resources. Serialize worker blits with create/resize/destroy.
  static std::mutex _contextMutex;
  static std::condition_variable _blitCv;
  static std::queue<BlitJob> _blitQueue;
  static std::set<TextureKey> _retiringTextures;

  // Worker lifetime is PROCESS-owned and refcounted by plugin instance, not
  // owned by whichever instance happens to be destroyed first. Previously
  // every destructor stopped and joined the shared worker and never reset the
  // flags, so tearing down one engine permanently disabled blitting for every
  // survivor: jobs still enqueued, nothing consumed them.
  //
  // _workerMutex serialises start/stop (it is taken ONLY in the constructor
  // and destructor). It is never acquired while _contextMutex is held, and
  // the worker never acquires it, so joining under it cannot deadlock.
  static std::mutex _workerMutex;
  // Heap-held, never a namespace-scope std::thread: this DLL's onexit table
  // destroys file statics at DLL_PROCESS_DETACH. When the process exits via
  // exit()/ExitProcess while the plugin is still alive, ExitProcess has already
  // killed the worker but a namespace-scope std::thread would still hold its id,
  // and ~thread() would see joinable() and call std::terminate -> abort ->
  // 0xC0000409 (upstream thermion #419). The pointer is deliberately leaked at
  // process exit; it is only deleted by StopBlitWorkerLocked after a join.
  static std::thread* _blitWorker = nullptr;
  static std::atomic<bool> _blitWorkerShouldStop{false};
  static int _pluginInstanceCount = 0;

  static void BlitWorkerLoop() {
    while (true) {
      BlitJob job;
      {
        std::unique_lock<std::mutex> lock(_blitMutex);
        _blitCv.wait(lock, [] {
          return !_blitQueue.empty() || _blitWorkerShouldStop.load();
        });
        if (_blitWorkerShouldStop.load() && _blitQueue.empty()) {
          return;
        }
        job = _blitQueue.front();
        _blitQueue.pop();
      }
      // A texture can begin retiring after its job is popped. Recheck while
      // holding the same context lock used by surface destruction: either this
      // blit completes before destruction, or it is skipped after retirement.
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      bool retiring = false;
      {
        std::lock_guard<std::mutex> blitLock(_blitMutex);
        retiring = _retiringTextures.find(job.key()) != _retiringTextures.end();
      }
      if (!retiring) {
        if (job.context) {
          job.context->Blit(job.handle);
        }
        if (job.registrar) {
          job.registrar->MarkTextureFrameAvailable(job.flutterTextureId);
        }
      }
    }
  }

  // Called once, by the FIRST plugin instance. Starting here rather than
  // lazily from EnqueueBlit keeps _workerMutex off the hot path, which is what
  // makes the lock graph acyclic: EnqueueBlit runs under _contextMutex, so a
  // lazy start would create _contextMutex -> _workerMutex while a concurrent
  // stop holds _workerMutex and joins a worker waiting on _contextMutex.
  static void StartBlitWorkerLocked() {
    if (_blitWorker) return;
    _blitWorkerShouldStop.store(false);
    _blitWorker = new std::thread(BlitWorkerLoop);
  }

  // Called once, by the LAST plugin instance to be destroyed. Every piece of
  // worker state is reset so a plugin registered later can start it again.
  static void StopBlitWorkerLocked() {
    if (!_blitWorker) return;
    _blitWorkerShouldStop.store(true);
    _blitCv.notify_all();
    if (_blitWorker->joinable()) {
      _blitWorker->join();
    }
    delete _blitWorker;
    _blitWorker = nullptr;
    _blitWorkerShouldStop.store(false);
  }

  static void AcquireBlitWorker() {
    std::lock_guard<std::mutex> workerLock(_workerMutex);
    if (_pluginInstanceCount++ == 0) {
      StartBlitWorkerLocked();
    }
  }

  static void ReleaseBlitWorker() {
    std::lock_guard<std::mutex> workerLock(_workerMutex);
    if (_pluginInstanceCount > 0 && --_pluginInstanceCount == 0) {
      StopBlitWorkerLocked();
    }
  }

  static void EnqueueBlit(BlitJob&& job) {
    {
      std::lock_guard<std::mutex> lock(_blitMutex);
      if (_retiringTextures.find(job.key()) != _retiringTextures.end()) {
        return;
      }
      // Bounded queue — drop oldest under sustained GPU pressure
      // rather than growing without limit. Visual effect under
      // overload: one stale frame, no hang, no crash.
      while (_blitQueue.size() >= kMaxBlitQueueDepth) {
        _blitQueue.pop();
      }
      _blitQueue.push(std::move(job));
    }
    _blitCv.notify_one();
  }

  // Retires `key` AND acts as an in-flight barrier.
  //
  // Taking _contextMutex first is what makes this a barrier rather than a mere
  // flag. The worker holds _contextMutex across its whole admitted
  // blit-and-mark sequence, so once this function holds that lock, any blit
  // that already passed the retirement check has finished marking. With only
  // _blitMutex a worker could pass the check, this function could return, the
  // caller could begin unregistration, and the admitted worker would still
  // call MarkTextureFrameAvailable on a texture the engine was destroying.
  //
  // Lock order _contextMutex -> _blitMutex matches every other nested site.
  // CALLERS MUST NOT ALREADY HOLD _contextMutex.
  static void RetireBlitJobs(const TextureKey& key) {
    std::lock_guard<std::mutex> contextLock(_contextMutex);
    std::lock_guard<std::mutex> blitLock(_blitMutex);
    _retiringTextures.insert(key);

    std::queue<BlitJob> retained;
    while (!_blitQueue.empty()) {
      auto job = std::move(_blitQueue.front());
      _blitQueue.pop();
      if (job.key() != key) {
        retained.push(std::move(job));
      }
    }
    _blitQueue.swap(retained);
  }

  ThermionFlutterPlugin::~ThermionFlutterPlugin() {
    // Refuse new registrations first: an allocation already in flight when the
    // widget disposed can still complete here, and must not attach a texture to
    // a registrar that is going away.
    _shuttingDown.store(true);
    StopFrameScheduler();

    // Engine creation runs on the shared render thread and does not stop
    // because this window is closing. A popout watchdog closing the window
    // mid-create tore surfaces and the blit worker out from under an engine
    // that was still being built, and aborted a plugin worker thread. Wait
    // for any in-flight create to finish before destroying anything it may
    // be about to use. Bounded: a create that never returns must not make a
    // window unclosable.
    const bool lifecycleLocked = EngineLifecycle_lock(kEngineCreateDrainMs);

    // Per-engine shutdown barrier.
    //
    // The Dart-side `retireTexture` call is an asynchronous optimisation, not a
    // lifetime guarantee: `invokeMethod` is a platform message, engine teardown
    // can destroy the messenger before the handler runs, and an allocation
    // still in flight at dispose has no descriptor to retire yet. So retire and
    // barrier every texture owned by THIS registrar here, where the ordering is
    // enforced natively and cannot be outrun.
    std::vector<int64_t> ownedIds;
    {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      for (auto &texture : _flutterTextures) {
        if (texture->GetOwner() == _textureRegistrar) {
          ownedIds.push_back(texture->GetFlutterTextureId());
        }
      }
    }
    // RetireBlitJobs takes _contextMutex itself, so it must be called WITHOUT
    // holding it.
    for (auto id : ownedIds) {
      RetireBlitJobs(TextureKey{_textureRegistrar, id});
    }

    // Drop this registrar's records and release their GPU surfaces. Leaving
    // them in the process-global vector would let a surviving engine match a
    // dead registrar's entry, and would leak one surface per texture per engine.
    {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      for (auto it = _flutterTextures.begin(); it != _flutterTextures.end();) {
        if ((*it)->GetOwner() != _textureRegistrar) {
          ++it;
          continue;
        }
        if (_context) {
          _context->DestroyRenderingSurface((*it)->GetD3DTextureHandle());
        }
        it = _flutterTextures.erase(it);
      }
      for (auto &entry : _pendingSwaps) {
        if (_context) {
          _context->DestroyRenderingSurface(entry.second.newD3DHandle);
        }
      }
      _pendingSwaps.clear();
    }

    // Retirement entries are keyed by registrar, so this registrar's are now
    // permanently unmatchable. Drop them rather than growing the set forever.
    {
      std::lock_guard<std::mutex> blitLock(_blitMutex);
      for (auto it = _retiringTextures.begin(); it != _retiringTextures.end();) {
        it = (it->first == _textureRegistrar) ? _retiringTextures.erase(it)
                                              : std::next(it);
      }
    }

    // The worker is process-owned. Only the LAST plugin instance stops it;
    // previously every destructor stopped and joined the shared worker and
    // never reset its flags, permanently disabling blitting for survivors.
    // Called without _contextMutex held — the join would otherwise deadlock
    // against a worker waiting for that lock.
    ReleaseBlitWorker();

    // This engine is gone, so its platform can serve the next one rather
    // than accumulating one per popout open/close cycle.
    if (_enginePlatform) {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      if (_context) {
        _context->ReleasePlatform(_enginePlatform);
      }
      _enginePlatform = nullptr;
    }

    if (lifecycleLocked) {
      EngineLifecycle_unlock();
    }
  }

  void ThermionFlutterPlugin::CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (_shuttingDown.load()) {
      result->Error("SHUTTING_DOWN",
                    "This plugin instance is being destroyed");
      return;
    }

    std::lock_guard<std::mutex> contextLock(_contextMutex);
    EnsureContextLocked();

    const auto *args =
        std::get_if<flutter::EncodableList>(methodCall.arguments());

    int dWidth = *(std::get_if<int>(&(args->at(0))));
    int dHeight = *(std::get_if<int>(&(args->at(1))));
    int dLeft = *(std::get_if<int>(&(args->at(2))));
    int dTop = *(std::get_if<int>(&(args->at(3))));
    auto width = (uint32_t)round(dWidth);
    auto height = (uint32_t)round(dHeight);
    auto left = (uint32_t)round(dLeft);
    auto top = (uint32_t)round(dTop);

    auto d3dHandle = _context->CreateRenderingSurface(width, height, left, top);

    if (!d3dHandle)
    {
      result->Error("Failed to create D3D texture");
      return;
    }

    auto externalImage = _context->CreateExternalImageForSurface(d3dHandle);

    auto flutterTexture = std::make_unique<FlutterD3DTexture>(d3dHandle, width, height);

    auto flutterTextureId = _textureRegistrar->RegisterTexture(flutterTexture->GetFlutterTexture());
    flutterTexture->SetFlutterTextureId(flutterTextureId);
    flutterTexture->SetOwner(_textureRegistrar);
    _flutterTextures.push_back(std::move(flutterTexture));

    // Texture IDs are pointer-derived and can be recycled, and retirement is
    // insert-only. Clear any stale retirement for this (registrar, ID) so a
    // recycled ID is not permanently muted — which would present as a texture
    // that registers successfully but never receives a frame.
    //
    // Same-registrar ordering is what makes this sufficient: MethodChannel
    // delivery is FIFO per engine, so a retire sent before this create is
    // handled before it, and a retire sent after refers to this texture.
    {
      std::lock_guard<std::mutex> blitLock(_blitMutex);
      _retiringTextures.erase(TextureKey{_textureRegistrar, flutterTextureId});
    }

    std::cout << "Registered Flutter texture ID " << flutterTextureId
              << std::endl;

    std::vector<flutter::EncodableValue> resultList;
    resultList.push_back(flutter::EncodableValue(flutterTextureId));
    resultList.push_back(flutter::EncodableValue((int64_t)externalImage));
    resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
    result->Success(resultList);
  }

  void ThermionFlutterPlugin::ResizeTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    std::lock_guard<std::mutex> contextLock(_contextMutex);
    if (!_context)
    {
      result->Error("NO_CONTEXT", "No rendering context");
      return;
    }

    const auto *args =
        std::get_if<flutter::EncodableList>(methodCall.arguments());

    int64_t flutterTextureId = std::get<int64_t>(args->at(0));
    int dWidth = std::get<int>(args->at(1));
    int dHeight = std::get<int>(args->at(2));
    auto width = static_cast<uint32_t>(dWidth);
    auto height = static_cast<uint32_t>(dHeight);

    // Find the existing FlutterD3DTexture
    auto it = std::find_if(_flutterTextures.begin(), _flutterTextures.end(), [=](auto &&ft)
                           { return ft->GetFlutterTextureId() == flutterTextureId &&
                                    ft->GetOwner() == _textureRegistrar; });
    if (it == _flutterTextures.end()) {
      result->Error("NOT_FOUND", "Flutter texture not found");
      return;
    }

    HANDLE oldD3DHandle = (*it)->GetD3DTextureHandle();

    // A second resize can arrive before the two-frame descriptor swap. The
    // abandoned replacement is no longer a Flutter surface, but its Filament
    // target is retained by Dart's deferred cleanup. Transfer image ownership
    // to Filament and retire the native interop resources before replacing it.
    auto pendingIt = _pendingSwaps.find(flutterTextureId);
    if (pendingIt != _pendingSwaps.end()) {
      _context->DestroyRenderingSurface(pendingIt->second.newD3DHandle);
      _pendingSwaps.erase(pendingIt);
    }

    // Create new D3D + Vulkan textures
    auto newD3DHandle = _context->CreateRenderingSurface(width, height, 0, 0);
    if (!newD3DHandle) {
      result->Error("CREATE_FAILED", "Failed to create new D3D texture");
      return;
    }

    auto externalImage = _context->CreateExternalImageForSurface(newD3DHandle);

    // Store pending swap — will be applied after first successful Blit
    _pendingSwaps[flutterTextureId] = PendingSwap{
      oldD3DHandle, newD3DHandle, width, height,
      static_cast<int64_t>(reinterpret_cast<intptr_t>(externalImage))
    };

    // Return [externalImage] to Dart
    std::vector<flutter::EncodableValue> resultList;
    resultList.push_back(flutter::EncodableValue(static_cast<int64_t>(reinterpret_cast<intptr_t>(externalImage))));
    result->Success(resultList);
  }

  bool ThermionFlutterPlugin::OnTextureUnregistered(int64_t flutterTextureId)
  {
    std::cerr << "ThermionFlutterPlugin::OnTextureUnregistered" << std::endl;

    std::lock_guard<std::mutex> contextLock(_contextMutex);
    if (!_context) {
      std::cerr << "No rendering context is active, cannot destroy Flutter texture ID" << flutterTextureId << std::endl;
      return false;    
    }

    auto it = std::find_if(_flutterTextures.begin(), _flutterTextures.end(), [=](auto &&ft)
                           { return ft->GetFlutterTextureId() == flutterTextureId &&
                                    ft->GetOwner() == _textureRegistrar; });
    
    if (it == _flutterTextures.end()) {
      std::cerr << "Failed to find Flutter texture associated with Flutter texture ID " << flutterTextureId << std::endl;
      return false;
    }
    
    auto flutterTexture = std::move(*it);
    HANDLE d3dTextureHandle = flutterTexture->GetD3DTextureHandle();
    _flutterTextures.erase(it);
    std::cerr << "Erased flutter texture" << std::endl;

    // If unregister races the two-frame resize handshake, Flutter still owns
    // the old descriptor while Filament is rendering into the new surface.
    // Retire both native surfaces and remove the stale handshake.
    std::vector<HANDLE> handles{d3dTextureHandle};
    auto pendingIt = _pendingSwaps.find(flutterTextureId);
    if (pendingIt != _pendingSwaps.end()) {
      handles.push_back(pendingIt->second.oldD3DHandle);
      handles.push_back(pendingIt->second.newD3DHandle);
      _pendingSwaps.erase(pendingIt);
    }
    std::set<HANDLE> uniqueHandles(handles.begin(), handles.end());
    for (auto handle : uniqueHandles) {
      _context->DestroyRenderingSurface(handle);
    }

    return true;
    
  }

  void ThermionFlutterPlugin::DestroyTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto flutterTextureId = *(std::get_if<int64_t>(methodCall.arguments()));

    auto shared_result = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(result.release());

    std::cerr << "Unregistering Flutter texture ID " << flutterTextureId << std::endl;

    // Prevent queued or subsequently delivered frame notifications from
    // touching the surface after TextureRegistrar begins unregistration.
    RetireBlitJobs(TextureKey{_textureRegistrar, flutterTextureId});

    _textureRegistrar->UnregisterTexture(
      flutterTextureId,
      ([shared_result, flutterTextureId, this]() {
          std::cerr << "TextureRegistrar unregister callback for Flutter texture ID " << flutterTextureId << std::endl;
          if (this->OnTextureUnregistered(flutterTextureId))
          {
            shared_result->Success(flutter::EncodableValue((int64_t) nullptr));
          }
          else
          {
            shared_result->Error("NO_CONTEXT", "Failed to unregister Flutter texture");
          }
      }));
  }

  void ThermionFlutterPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    // std::cout << methodCall.method_name().c_str() << std::endl;
    if (methodCall.method_name() == "getSharedContext")
    {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      result->Success(flutter::EncodableValue(
          (int64_t)EnsureContextLocked()->GetSharedContext()));
    }
    else if (methodCall.method_name() == "getRenderingContext")
    {
      // Single locked operation returning BOTH values.
      //
      // Dart used to fetch the driver platform and the shared context in two
      // separate channel calls. Even with each call individually locked, the
      // pair was not consistent: another engine could act between them. One
      // op under one lock removes the interleaving window entirely.
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      auto *context = EnsureContextLocked();
      std::vector<flutter::EncodableValue> resultList;
      // Both are per ENGINE: the platform object itself, and the
      // VulkanSharedContext carrying this engine's VkQueue index. Only the
      // VkInstance/VkDevice inside them are process-wide. See
      // EnginePlatformLocked().
      auto *platform = EnginePlatformLocked();
      auto *sharedContext = context->GetSharedContextForPlatform(platform);
      resultList.push_back(flutter::EncodableValue((int64_t)platform));
      resultList.push_back(flutter::EncodableValue((int64_t)sharedContext));
      result->Success(resultList);
    }
    else if (methodCall.method_name() == "createTexture")
    {
      CreateTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "destroyTexture")
    {
      // result->Success(flutter::EncodableValue((int64_t) nullptr));
      DestroyTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "resizeTexture")
    {
      ResizeTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "cancelResizeTexture")
    {
      const auto *flutterTextureId =
          std::get_if<int64_t>(methodCall.arguments());
      if (!flutterTextureId) {
        result->Error("BAD_ARGUMENT", "Missing Flutter texture ID");
        return;
      }

      std::lock_guard<std::mutex> contextLock(_contextMutex);
      auto pendingIt = _pendingSwaps.find(*flutterTextureId);
      if (pendingIt != _pendingSwaps.end()) {
        if (_context) {
          _context->DestroyRenderingSurface(pendingIt->second.newD3DHandle);
        }
        _pendingSwaps.erase(pendingIt);
      }
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "markTextureFrameAvailable")
    {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      if (_context)
      {
        const auto *flutterTextureId = std::get_if<int64_t>(methodCall.arguments());

        if (!flutterTextureId || *flutterTextureId == -1)
        {
          std::cout << "Bad texture" << std::endl;
          result->Success(flutter::EncodableValue((int64_t) nullptr));
          return;
        }

        // A retired texture must never be marked again — its Flutter-side view
        // may already be tearing down inside the engine. `EnqueueBlit` performs
        // this check for the steady-state path, but the pending-swap branch
        // below calls `MarkTextureFrameAvailable` DIRECTLY and bypassed it
        // entirely. Check once here so both paths are covered.
        //
        // Lock order is _contextMutex (held above) then _blitMutex, matching
        // BlitWorkerLoop.
        {
          std::lock_guard<std::mutex> blitLock(_blitMutex);
          if (_retiringTextures.find(
                  TextureKey{_textureRegistrar, *flutterTextureId}) !=
              _retiringTextures.end()) {
            result->Success(flutter::EncodableValue((int64_t) nullptr));
            return;
          }
        }

        // Find the FlutterD3DTexture for this flutterTextureId
        auto it = std::find_if(_flutterTextures.begin(), _flutterTextures.end(), [=](auto &&ft)
                               { return ft->GetFlutterTextureId() == *flutterTextureId &&
                                        ft->GetOwner() == _textureRegistrar; });

        if (it == _flutterTextures.end()) {
          std::cerr << "Failed to find Flutter texture for ID " << *flutterTextureId << std::endl;
          result->Success(flutter::EncodableValue((int64_t) nullptr));
          return;
        }

        auto swapIt = _pendingSwaps.find(*flutterTextureId);
        if (swapIt != _pendingSwaps.end()) {
          auto& swap = swapIt->second;
          swap.frameCount++;

          if (swap.frameCount < 2) {
            // Frame 1: Filament is rendering into the new RT.
            // Blit OLD handle — old RT VkImage is still valid because
            // Dart deferred its Filament texture cleanup.
            // Flutter keeps showing last valid frame via old D3D texture.
            _context->Blit(swap.oldD3DHandle);
          } else {
            // Frame 2+: new RT has valid content from previous render.
            // Blit new handle, swap descriptor, retire old textures.
            _context->ClearPendingFirstBlit(swap.newD3DHandle);
            _context->Blit(swap.newD3DHandle);

            (*it)->SwapDescriptor(swap.newD3DHandle, swap.width, swap.height);
            _context->DestroyRenderingSurface(swap.oldD3DHandle);
            _pendingSwaps.erase(swapIt);
          }
        } else {
          // Enqueue the Blit + MarkTextureFrameAvailable on the
          // dedicated worker thread. Synchronous Blit on the UI
          // thread saturates the Win32 message pump under multi-
          // viewer load and the per-call detached-thread variant
          // crashed inside the Intel Vulkan driver because Blit's
          // command pool / queue / fence are not thread-safe. The
          // worker thread serialises all Blits process-wide and
          // returns the UI thread immediately. See BlitWorkerLoop
          // / EnqueueBlit above.
          HANDLE d3dTextureHandle = (*it)->GetD3DTextureHandle();
          EnqueueBlit(BlitJob{
              _context,
              _textureRegistrar,
              d3dTextureHandle,
              *flutterTextureId,
          });
          result->Success(flutter::EncodableValue((int64_t) nullptr));
          return;
        }

        _textureRegistrar->MarkTextureFrameAvailable(*flutterTextureId);
      } else {
        std::cout << "No context" << std::endl;
      }
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "retireTexture")
    {
      // Stop producing frames for this texture NOW, ahead of the asynchronous
      // teardown chain. Widget disposal enqueues `destroyTextureForView`
      // behind any in-flight allocation/resize, so it can run many frames
      // after the widget has left the tree — and until it does, the blit
      // worker keeps calling MarkTextureFrameAvailable for a texture whose
      // engine-side view is already being destroyed.
      const auto *flutterTextureId =
          std::get_if<int64_t>(methodCall.arguments());
      if (!flutterTextureId) {
        result->Error("BAD_ARGUMENT", "Missing Flutter texture ID");
        return;
      }
      RetireBlitJobs(TextureKey{_textureRegistrar, *flutterTextureId});
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "destroyContext") {
      // Deliberate no-op: the rendering context is process-immortal.
      //
      // This arrives from `FilamentApp.onDestroy`, i.e. once per ENGINE, but
      // the context, its VkInstance/VkDevice and the process-global BlueVK
      // dispatch table are shared by every engine. One engine's shutdown
      // cannot prove no other engine still has live render or blit threads
      // using them. Nulling the pointer let a later engine construct a second
      // context and rebind BlueVK underneath the first engine's running
      // threads; deleting it would be a straight use-after-free.
      //
      // Cost: one context retained for the process lifetime. FUTURE: refcounted
      // leases so the last engine out can genuinely release it.
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else if (methodCall.method_name() == "getDriverPlatform")
    {
      // Retained for compatibility; `getRenderingContext` is the coherent
      // form. Locked because an unsynchronised check-then-construct let two
      // engine platform threads each build a context.
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      result->Success(flutter::EncodableValue((int64_t)EnginePlatformLocked()));
    }
    else if (methodCall.method_name() == "startFrameScheduler")
    {
      const auto *args = std::get_if<flutter::EncodableList>(methodCall.arguments());
      int64_t callbackAddress = std::get<int64_t>(args->at(0));
      int targetFps = std::get<int>(args->at(1));
      StartFrameScheduler(callbackAddress, targetFps);
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else if (methodCall.method_name() == "stopFrameScheduler")
    {
      StopFrameScheduler();
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else if (methodCall.method_name() == "initDartApi")
    {
      // Initialize Dart API DL for port-based messaging (hot restart safe)
      int64_t dataAddress = std::get<int64_t>(*methodCall.arguments());
      void* data = reinterpret_cast<void*>(dataAddress);
      if (!_dartApiInitialized && data != nullptr) {
        intptr_t initResult = Dart_InitializeApiDL(data);
        _dartApiInitialized = (initResult == 0);
      }
      result->Success(flutter::EncodableValue(_dartApiInitialized ? 0 : -1));
    }
    else if (methodCall.method_name() == "startFrameSchedulerWithPort")
    {
      // Port-based frame scheduling (hot restart safe)
      const auto *args = std::get_if<flutter::EncodableList>(methodCall.arguments());
      int64_t port = std::get<int64_t>(args->at(0));
      int targetFps = std::get<int>(args->at(1));
      StartFrameSchedulerWithPort(port, targetFps);
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else
    {
      result->Error("NOT_IMPLEMENTED", "Method is not implemented %s",
                    methodCall.method_name());
    }
  }

  void ThermionFlutterPlugin::StartFrameScheduler(int64_t callbackAddress, int targetFps) {
    StopFrameScheduler();
    _frameCallback = reinterpret_cast<FrameCallback>(callbackAddress);
    _frameSchedulerRunning = true;
    _frameSchedulerThread = std::thread([this]() {
      IDXGIFactory1* factory = nullptr;
      IDXGIAdapter* adapter = nullptr;
      IDXGIOutput* output = nullptr;

      HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory);
      if (SUCCEEDED(hr) && factory) {
        hr = factory->EnumAdapters(0, &adapter);
        if (SUCCEEDED(hr) && adapter) {
          hr = adapter->EnumOutputs(0, &output);
          if (FAILED(hr)) {
            output = nullptr;
            std::cerr << "Failed to get DXGI output for WaitForVBlank, falling back to timer" << std::endl;
          }
        }
      }

      while (_frameSchedulerRunning) {
        if (output) {
          output->WaitForVBlank();
        } else {
          std::this_thread::sleep_for(std::chrono::nanoseconds(1000000000 / 60));
        }
        if (_frameCallback && _frameSchedulerRunning) {
          auto now = std::chrono::high_resolution_clock::now();
          uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
              now.time_since_epoch()).count();
          _frameCallback(nanos);
        }
      }

      if (output) output->Release();
      if (adapter) adapter->Release();
      if (factory) factory->Release();
    });
  }

  void ThermionFlutterPlugin::StartFrameSchedulerWithPort(int64_t port, int targetFps) {
    StopFrameScheduler();
    _dartPort = port;
    _usePortMode = true;
    _frameSchedulerRunning = true;
    _frameSchedulerThread = std::thread([this]() {
      IDXGIFactory1* factory = nullptr;
      IDXGIAdapter* adapter = nullptr;
      IDXGIOutput* output = nullptr;

      HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory);
      if (SUCCEEDED(hr) && factory) {
        hr = factory->EnumAdapters(0, &adapter);
        if (SUCCEEDED(hr) && adapter) {
          hr = adapter->EnumOutputs(0, &output);
          if (FAILED(hr)) {
            output = nullptr;
            std::cerr << "Failed to get DXGI output for WaitForVBlank, falling back to timer" << std::endl;
          }
        }
      }

      while (_frameSchedulerRunning) {
        if (output) {
          output->WaitForVBlank();
        } else {
          std::this_thread::sleep_for(std::chrono::nanoseconds(1000000000 / 60));
        }
        if (_usePortMode && _dartPort != 0 && _frameSchedulerRunning) {
          auto now = std::chrono::high_resolution_clock::now();
          uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
              now.time_since_epoch()).count();

          // Post to Dart port - silently drops if isolate is dead (hot restart safe)
          Dart_CObject msg;
          msg.type = Dart_CObject_kInt64;
          msg.value.as_int64 = static_cast<int64_t>(nanos);
          Dart_PostCObject_DL(_dartPort, &msg);
        }
      }

      if (output) output->Release();
      if (adapter) adapter->Release();
      if (factory) factory->Release();
    });
  }

  void ThermionFlutterPlugin::StopFrameScheduler() {
    _frameSchedulerRunning = false;
    if (_frameSchedulerThread.joinable()) {
      _frameSchedulerThread.join();
    }
    _frameCallback = nullptr;
    _dartPort = 0;
    _usePortMode = false;
  }

} // namespace thermion_flutter
