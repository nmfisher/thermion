#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")

#include "thermion_flutter_plugin.h"

#include <Windows.h>

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

  ThermionFlutterPlugin::~ThermionFlutterPlugin() {
    StopFrameScheduler();
  }

  // this is only for storing Flutter surface descriptors
  // (as opposed to the D3D/Vulkan handles, which are stored in the ThermionVulkanContext)
  static std::vector<std::unique_ptr<FlutterD3DTexture>> _flutterTextures;

  void ThermionFlutterPlugin::CreateTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (!_context)
    {
      _context = new thermion::windows::vulkan::ThermionVulkanContext();
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

    auto vkImage = _context->GetVulkanImageForSurface(d3dHandle);

    auto flutterTexture = std::make_unique<FlutterD3DTexture>(d3dHandle, width, height);

    auto flutterTextureId = _textureRegistrar->RegisterTexture(flutterTexture->GetFlutterTexture());
    flutterTexture->SetFlutterTextureId(flutterTextureId);
    _flutterTextures.push_back(std::move(flutterTexture));

    std::cout << "Registered Flutter texture ID " << flutterTextureId
              << std::endl;

    std::vector<flutter::EncodableValue> resultList;
    resultList.push_back(flutter::EncodableValue(flutterTextureId));
    resultList.push_back(flutter::EncodableValue((int64_t)vkImage));
    resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
    result->Success(resultList);
  }

  bool ThermionFlutterPlugin::OnTextureUnregistered(int64_t flutterTextureId)
  {
    std::cerr << "ThermionFlutterPlugin::OnTextureUnregistered" << std::endl;

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
    _context->DestroyRenderingSurface(d3dTextureHandle);

    return true;
    
  }

  void ThermionFlutterPlugin::DestroyTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto flutterTextureId = *(std::get_if<int64_t>(methodCall.arguments()));

    auto shared_result = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(result.release());

    std::cerr << "Unregistering Flutter texture ID " << flutterTextureId << std::endl;

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
        _context = new thermion::windows::vulkan::ThermionVulkanContext();
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
    else if (methodCall.method_name() == "markTextureFrameAvailable")
    {
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

        HANDLE d3dTextureHandle = (*it)->GetD3DTextureHandle();
        _context->Blit(d3dTextureHandle);

        _textureRegistrar->MarkTextureFrameAvailable(*flutterTextureId);
      } else {
        std::cout << "No context" << std::endl;
      }
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "destroyContext") {
      _context = std::nullptr_t();
      std::cerr << "Destroyed context" << std::endl;
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    }
    else if (methodCall.method_name() == "getDriverPlatform")
    {
      if (!_context) {
        std::cerr << "No context, creating new one" << std::endl;
        _context = new thermion::windows::vulkan::ThermionVulkanContext();
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
