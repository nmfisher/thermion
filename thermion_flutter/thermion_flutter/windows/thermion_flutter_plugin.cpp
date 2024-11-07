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

#include "rendering/vulkan/vulkan_context.h"

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

  ResourceBuffer ThermionFlutterPlugin::loadResource(const char *name)
  {

    std::string name_str(name);
    std::filesystem::path targetFilePath;

    if (name_str.rfind("file://", 0) == 0)
    {
      targetFilePath = name_str.substr(7);
    }
    else
    {

      if (name_str.rfind("asset://", 0) == 0)
      {
        name_str = name_str.substr(8);
      }

      int size_needed = MultiByteToWideChar(CP_UTF8, 0, name_str.c_str(), -1, nullptr, 0);
      std::wstring assetPath(size_needed, 0);
      MultiByteToWideChar(CP_UTF8, 0, name_str.c_str(), -1, &assetPath[0], size_needed);

      TCHAR pBuf[512];
      size_t len = sizeof(pBuf);
      GetModuleFileName(NULL, pBuf, static_cast<DWORD>(len));

      std::wstring exePathBuf(pBuf);
      std::filesystem::path exePath(exePathBuf);
      auto exeDir = exePath.remove_filename();
      targetFilePath = exeDir.wstring() + L"data/flutter_assets/" + assetPath;
    }
    std::streampos length;

    std::ifstream is(targetFilePath.c_str(), std::ios::binary);
    if (!is)
    {
      std::cout << "Failed to find resource at file path " << targetFilePath
                << std::endl;
      return ResourceBuffer(nullptr, 0, -1);
    }
    is.seekg(0, std::ios::end);
    length = is.tellg();

    char *buffer;
    buffer = new char[length];
    is.seekg(0, std::ios::beg);
    is.read(buffer, length);
    is.close();
    int32_t id = static_cast<int32_t>(_resources.size());
    auto rb = ResourceBuffer(buffer, static_cast<int32_t>(length), id);
    _resources.emplace(id, rb);

    std::wcout << "Loaded resource of length " << length << " from path "
               << targetFilePath << std::endl;

    return rb;
  }

  void ThermionFlutterPlugin::freeResource(ResourceBuffer rbuf)
  {
    free((void *)rbuf.data);
  }

  static ResourceBuffer _loadResource(const char *path, void *const plugin)
  {
    std::wcout << "Loading resource from path " << path << std::endl;
    return ((ThermionFlutterPlugin *)plugin)->loadResource(path);
  }

  static void _freeResource(ResourceBuffer rbf, void *const plugin)
  {
    ((ThermionFlutterPlugin *)plugin)->freeResource(rbf);
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
      _context = std::make_unique<thermion::windows::vulkan::ThermionVulkanContext>();
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

    auto it = std::find_if(_flutterTextures.begin(), _flutterTextures.end(), [=](auto &&ft)
                           { return ft->GetFlutterTextureId() == flutterTextureId; });
    HANDLE d3dTextureHandle;
    if (it != _flutterTextures.end())
    {
      auto flutterTexture = std::move(*it);

      d3dTextureHandle = flutterTexture->GetD3DTextureHandle();
      _flutterTextures.erase(it);
    }

    if (_context && d3dTextureHandle)
    {
      _context->DestroyRenderingSurface(d3dTextureHandle);
      return true;
    }
    return false;
  }

  void ThermionFlutterPlugin::DestroyTexture(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto flutterTextureId = *(std::get_if<int64_t>(methodCall.arguments()));

    auto shared_result = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(result.release());

    _textureRegistrar->UnregisterTexture(flutterTextureId, ([shared_result, flutterTextureId, this]()
                                                            {
                                                              if (this->OnTextureUnregistered(flutterTextureId))
                                                              {
                                                                shared_result->Success(flutter::EncodableValue((int64_t) nullptr));
                                                              }
                                                              else
                                                              {
                                                                shared_result->Error("NO_CONTEXT", "No rendering context is active");
                                                              }
                                                            }));
  }

  void ThermionFlutterPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &methodCall,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    // std::cout << methodCall.method_name().c_str() << std::endl;
    if (methodCall.method_name() == "getResourceLoaderWrapper")
    {
      auto wrapper = (ResourceLoaderWrapper *)malloc(sizeof(ResourceLoaderWrapper));
      wrapper->loadFromOwner = _loadResource;
      wrapper->freeFromOwner = _freeResource,
      wrapper->owner = this;
      wrapper->loadResource = nullptr;
      wrapper->loadToOut = nullptr;
      wrapper->freeResource = nullptr;
      result->Success(flutter::EncodableValue((int64_t)wrapper));
    }
    else if (methodCall.method_name() == "getSharedContext")
    {
      if (!_context)
      {
        _context = std::make_unique<thermion::windows::vulkan::ThermionVulkanContext>();
      }
      // result->Success(flutter::EncodableValue((int64_t)_context->GetSharedContext()));
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "resizeWindow")
    {

      const auto *args =
          std::get_if<flutter::EncodableList>(methodCall.arguments());

      int dWidth = *(std::get_if<int>(&(args->at(0))));
      int dHeight = *(std::get_if<int>(&(args->at(1))));
      int dLeft = *(std::get_if<int>(&(args->at(2))));
      int dTop = *(std::get_if<int>(&(args->at(3))));
      auto width = static_cast<uint32_t>(dWidth);
      auto height = static_cast<uint32_t>(dHeight);
      auto left = static_cast<uint32_t>(dLeft);
      auto top = static_cast<uint32_t>(dTop);

      _context->ResizeRenderingSurface(width, height, left, top);
      result->Success();
    }
    else if (methodCall.method_name() == "createTexture")
    {
      CreateTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "createWindow")
    {
      CreateTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "destroyTexture")
    {
      DestroyTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "destroyWindow")
    {
      DestroyTexture(methodCall, std::move(result));
    }
    else if (methodCall.method_name() == "markTextureFrameAvailable")
    {
      if (_context)
      {

        _context->Flush();
        _context->BlitFromSwapchain();
        const auto *flutterTextureId = std::get_if<int64_t>(methodCall.arguments());

        if (!flutterTextureId || *flutterTextureId == -1)
        {
          std::cout << "Bad texture" << std::endl;
          return;
        }
        // std::cout << "Marking texture" << (*flutterTextureId) << "available" << std::endl;
        _textureRegistrar->MarkTextureFrameAvailable(*flutterTextureId);
      }
      result->Success(flutter::EncodableValue((int64_t) nullptr));
    }
    else if (methodCall.method_name() == "getDriverPlatform")
    {
      if (!_context)
      {
        _context = std::make_unique<thermion::windows::vulkan::ThermionVulkanContext>();
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
