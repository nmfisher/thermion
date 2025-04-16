#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")

#include "thermion_flutter_plugin.h"

#include <Windows.h>

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

  ThermionFlutterPlugin::~ThermionFlutterPlugin() {}

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

    auto flutterTexture = std::make_unique<FlutterD3DTexture>(d3dHandle, width, height);

    auto flutterTextureId = _textureRegistrar->RegisterTexture(flutterTexture->GetFlutterTexture());
    flutterTexture->SetFlutterTextureId(flutterTextureId);
    _flutterTextures.push_back(std::move(flutterTexture));

    std::cout << "Registered Flutter texture ID " << flutterTextureId
              << std::endl;

    std::vector<flutter::EncodableValue> resultList;
    resultList.push_back(flutter::EncodableValue(flutterTextureId));
    resultList.push_back(flutter::EncodableValue((int64_t) nullptr));
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
      // result->Success(flutter::EncodableValue((int64_t)_context->GetSharedContext()));
      result->Success(flutter::EncodableValue((int64_t) nullptr));
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
        _context->BlitFromSwapchain();
        const auto *flutterTextureId = std::get_if<int64_t>(methodCall.arguments());

        if (!flutterTextureId || *flutterTextureId == -1)
        {
          std::cout << "Bad texture" << std::endl;
          return;
        }
        // std::cout << "Marking texture" << (*flutterTextureId) << "available" << std::endl;
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
    else
    {
      result->Error("NOT_IMPLEMENTED", "Method is not implemented %s",
                    methodCall.method_name());
    }
  }

} // namespace thermion_flutter
