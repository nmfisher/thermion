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

#include "flutter_d3d_texture.h"


namespace thermion::tflutter::windows
{

  using namespace std::chrono_literals;

  // Static member initialization for Dart API DL
  bool ThermionFlutterPlugin::_dartApiInitialized = false;

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
  struct BlitJob {
    thermion::vulkan::windows::WindowsVulkanContext* context;
    flutter::TextureRegistrar* registrar;
    HANDLE handle;
    int64_t flutterTextureId;
  };

  static constexpr size_t kMaxBlitQueueDepth = 16;

  static std::mutex _blitMutex;
  // WindowsVulkanContext owns one command buffer/queue and parallel vectors of
  // surface resources. Serialize worker blits with create/resize/destroy.
  static std::mutex _contextMutex;
  static std::condition_variable _blitCv;
  static std::queue<BlitJob> _blitQueue;
  static std::set<int64_t> _retiringTextureIds;
  static std::thread _blitWorker;
  static std::atomic<bool> _blitWorkerStarted{false};
  static std::atomic<bool> _blitWorkerShouldStop{false};

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
        retiring =
            _retiringTextureIds.find(job.flutterTextureId) !=
            _retiringTextureIds.end();
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

  static void EnsureBlitWorkerStarted() {
    bool expected = false;
    if (_blitWorkerStarted.compare_exchange_strong(expected, true)) {
      _blitWorker = std::thread(BlitWorkerLoop);
    }
  }

  static void EnqueueBlit(BlitJob&& job) {
    EnsureBlitWorkerStarted();
    {
      std::lock_guard<std::mutex> lock(_blitMutex);
      if (_retiringTextureIds.find(job.flutterTextureId) !=
          _retiringTextureIds.end()) {
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

  static void RetireBlitJobs(int64_t flutterTextureId) {
    std::lock_guard<std::mutex> lock(_blitMutex);
    _retiringTextureIds.insert(flutterTextureId);

    std::queue<BlitJob> retained;
    while (!_blitQueue.empty()) {
      auto job = std::move(_blitQueue.front());
      _blitQueue.pop();
      if (job.flutterTextureId != flutterTextureId) {
        retained.push(std::move(job));
      }
    }
    _blitQueue.swap(retained);
  }

  ThermionFlutterPlugin::~ThermionFlutterPlugin() {
    StopFrameScheduler();

    // Stop the Blit worker thread cleanly. We signal the stop flag,
    // wake the worker (it may be sleeping on the condition variable
    // with an empty queue), and join. The worker drains queued
    // jobs first, then returns. Safe against hot restart / app
    // teardown.
    if (_blitWorkerStarted.load()) {
      _blitWorkerShouldStop.store(true);
      _blitCv.notify_all();
      if (_blitWorker.joinable()) {
        _blitWorker.join();
      }
    }
  }

  void ThermionFlutterPlugin::CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    std::lock_guard<std::mutex> contextLock(_contextMutex);
    if (!_context)
    {
      _context = new thermion::vulkan::windows::WindowsVulkanContext();
    }

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
    _flutterTextures.push_back(std::move(flutterTexture));

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
                           { return ft->GetFlutterTextureId() == flutterTextureId; });
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
                           { return ft->GetFlutterTextureId() == flutterTextureId; });
    
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
    RetireBlitJobs(flutterTextureId);

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
      if (!_context)
      {
        _context = new thermion::vulkan::windows::WindowsVulkanContext();
      }
      result->Success(flutter::EncodableValue((int64_t)_context->GetSharedContext()));
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

        // Find the FlutterD3DTexture for this flutterTextureId
        auto it = std::find_if(_flutterTextures.begin(), _flutterTextures.end(), [=](auto &&ft)
                               { return ft->GetFlutterTextureId() == *flutterTextureId; });

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
    else if (methodCall.method_name() == "destroyContext") {
      std::lock_guard<std::mutex> contextLock(_contextMutex);
      _context = std::nullptr_t();
      std::cerr << "Destroyed context" << std::endl;
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else if (methodCall.method_name() == "getDriverPlatform")
    {
      if (!_context) {
        std::cerr << "No context, creating new one" << std::endl;
        _context = new thermion::vulkan::windows::WindowsVulkanContext();
       } else { 
        std::cerr << "Context already exists, returning existing" << std::endl;
       }
      result->Success(flutter::EncodableValue((int64_t)_context->GetPlatform()));
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
