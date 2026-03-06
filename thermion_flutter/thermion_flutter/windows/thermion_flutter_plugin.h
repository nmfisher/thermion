#pragma once

#define THERMION_WIN32_KHR_BUILD

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <chrono>
#include <map>
#include <memory>
#include <mutex>
#include <thread>

#include "windows/import.h"

#include "vulkan/windows/WindowsVulkanContext.h"

namespace thermion::tflutter::windows {

class ThermionFlutterPlugin : public ::flutter::Plugin {
public:
  static void RegisterWithRegistrar(::flutter::PluginRegistrarWindows *registrar);

  ThermionFlutterPlugin(flutter::TextureRegistrar *textureRegistrar,
                        flutter::PluginRegistrarWindows *registrar,
                        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>& channel);
  virtual ~ThermionFlutterPlugin();

  // Disallow copy and assign.
  ThermionFlutterPlugin(const ThermionFlutterPlugin &) = delete;
  ThermionFlutterPlugin &operator=(const ThermionFlutterPlugin &) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows *_pluginRegistrar;
  flutter::TextureRegistrar *_textureRegistrar;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> _channel;
 
  void CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DestroyTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RenderCallback();

  void ResizeTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  private:
    thermion::vulkan::windows::WindowsVulkanContext *_context = nullptr;
    bool OnTextureUnregistered(int64_t flutterTextureId);

    // Pending handle swap: after resizeTexture creates new GPU resources,
    // the new D3D handle waits here until the first successful Blit, then
    // SwapDescriptor() is called so Flutter sees the new handle.
    struct PendingSwap {
      HANDLE oldD3DHandle;
      HANDLE newD3DHandle;
      uint32_t width;
      uint32_t height;
      int64_t externalImage;
      int frameCount = 0;  // Frames since resize; swap fires at 2+
    };
    std::map<int64_t, PendingSwap> _pendingSwaps;

    // Frame scheduler (DXGI vsync)
    using FrameCallback = void (*)(uint64_t);
    FrameCallback _frameCallback = nullptr;
    std::atomic<bool> _frameSchedulerRunning{false};
    std::thread _frameSchedulerThread;
    void StartFrameScheduler(int64_t callbackAddress, int targetFps);
    void StartFrameSchedulerWithPort(int64_t port, int targetFps);
    void StopFrameScheduler();

    // Port-based frame scheduling (hot restart safe)
    int64_t _dartPort = 0;
    bool _usePortMode = false;
    static bool _dartApiInitialized;

};

} // namespace thermion_flutter


