#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

#include "polyvox_filament_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

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
#include <future> 

#include "PolyvoxFilamentApi.h"
#include "PlatformANGLE.h"
#include "GL/GL.h"
#include "GL/GLu.h"
#include "GL/wglext.h"

#include <Windows.h>
#include <wrl.h>

using namespace std::chrono_literals;

namespace polyvox_filament {

// static
void PolyvoxFilamentPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "app.polyvox.filament/event",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PolyvoxFilamentPlugin>(
      registrar->texture_registrar(), registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PolyvoxFilamentPlugin::PolyvoxFilamentPlugin(
    flutter::TextureRegistrar *textureRegistrar,
    flutter::PluginRegistrarWindows *pluginRegistrar)
    : _textureRegistrar(textureRegistrar), _pluginRegistrar(pluginRegistrar) {}

PolyvoxFilamentPlugin::~PolyvoxFilamentPlugin() {}

ResourceBuffer PolyvoxFilamentPlugin::loadResource(const char *name) {
  
  std::string name_str(name);
  std::filesystem::path targetFilePath;
  
  if (name_str.rfind("file://", 0) == 0) {
    targetFilePath = name_str.substr(7);
  } else {

    if (name_str.rfind("asset://", 0) == 0) {
      name_str = name_str.substr(8);
    }

    TCHAR pBuf[256];
    size_t len = sizeof(pBuf);
    int bytes = GetModuleFileName(NULL, pBuf, len);
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring assetPath = converter.from_bytes(name_str.c_str());

    std::wstring exePathBuf(pBuf);
    std::filesystem::path exePath(exePathBuf);
    auto exeDir = exePath.remove_filename();
    targetFilePath = exeDir.wstring() + L"data/flutter_assets/" +
                            assetPath;
  }
  std::streampos length;
  
  std::ifstream is(targetFilePath.c_str(), std::ios::binary);
  if (!is) {
    std::cout << "Failed to find resource at file path " << targetFilePath << std::endl;
    return ResourceBuffer(nullptr, 0, -1);
  }
  is.seekg(0, std::ios::end);
  length = is.tellg();

  char *buffer;
  buffer = new char[length];
  is.seekg(0, std::ios::beg);
  is.read(buffer, length);
  is.close();
  auto id = _resources.size();
  auto rb = ResourceBuffer(buffer, length, id);
  _resources.emplace(id, rb);

  std::wcout << "Loaded resource of length " << length << " from path " << targetFilePath << std::endl;

  return rb;
}

void PolyvoxFilamentPlugin::freeResource(ResourceBuffer rbuf) {
  free((void *)rbuf.data);
}

static ResourceBuffer _loadResource(const char *path, void *const plugin) {
  return ((PolyvoxFilamentPlugin *)plugin)->loadResource(path);
}

static void _freeResource(ResourceBuffer rbf, void *const plugin) {
  ((PolyvoxFilamentPlugin *)plugin)->freeResource(rbf);
}

// this is the C-style function that will be returned via getRenderCallback
// called on every frame by the FFI API
// this is just a convenient wrapper to call RenderCallback on the actual plugin instance
void render_callback(void* owner) { 
    ((PolyvoxFilamentPlugin*)owner)->RenderCallback();
}

// this is the method on PolyvoxFilamentPlugin that will copy between D3D textures
void PolyvoxFilamentPlugin::RenderCallback() {
  _D3D11DeviceContext->CopyResource(_externalD3DTexture2D.Get(),
                                    _internalD3DTexture2D.Get());
  _D3D11DeviceContext->Flush();
  _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);
}

void PolyvoxFilamentPlugin::CreateTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

   const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = (uint32_t)round(*(std::get_if<double>(&(args->at(0)))));
  const auto height = (uint32_t)round(*(std::get_if<double>(&(args->at(1)))));

  // D3D starts here
  IDXGIAdapter* adapter_ = nullptr;

  // first, we need to initialize the D3D device and create the backing texture
  // this has been taken from https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/blob/master/windows/angle_surface_manager.cc
  auto feature_levels = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
        D3D_FEATURE_LEVEL_9_3,
    };
  // NOTE: Not enabling DirectX 12.
  // |D3D11CreateDevice| crashes directly on Windows 7.
  // D3D_FEATURE_LEVEL_12_2, D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0,
  // D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1,
  // D3D_FEATURE_LEVEL_10_0, D3D_FEATURE_LEVEL_9_3,
  IDXGIFactory* dxgi = nullptr;
  ::CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&dxgi);
  // Manually selecting adapter. As far as my experience goes, this is the
  // safest approach. Passing NULL (so-called default) seems to cause issues
  // on Windows 7 or maybe some older graphics drivers.
  // First adapter is the default.
  // |D3D_DRIVER_TYPE_UNKNOWN| must be passed with manual adapter selection.
  dxgi->EnumAdapters(0, &adapter_);
  dxgi->Release();
  if (!adapter_) {
    result->Error("ERROR", "Failed to locate default D3D adapter", nullptr);
    return;
  } 
  
  DXGI_ADAPTER_DESC adapter_desc_;
  adapter_->GetDesc(&adapter_desc_);
  std::wcout << L"D3D adapter description: " << adapter_desc_.Description << std::endl;
  
  auto hr = ::D3D11CreateDevice(
      adapter_, D3D_DRIVER_TYPE_UNKNOWN, 0, 0, feature_levels.begin(),
      static_cast<UINT>(feature_levels.size()), D3D11_SDK_VERSION,
      &_D3D11Device, 0, &_D3D11DeviceContext);

  if (FAILED(hr)) {   
    result->Error("ERROR", "Failed to create D3D device", nullptr);
    return;
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device = nullptr;
  auto dxgi_device_success = _D3D11Device->QueryInterface(
      __uuidof(IDXGIDevice), (void**)&dxgi_device);
  if (SUCCEEDED(dxgi_device_success) && dxgi_device != nullptr) {
    dxgi_device->SetGPUThreadPriority(5);  // Must be in interval [-7, 7].
  }

  auto level = _D3D11Device->GetFeatureLevel();
  std::cout << "media_kit: ANGLESurfaceManager: Direct3D Feature Level: "
            << (((unsigned)level) >> 12) << "_"
            << ((((unsigned)level) >> 8) & 0xf) << std::endl;
  auto d3d11_texture2D_desc = D3D11_TEXTURE2D_DESC{0};
  d3d11_texture2D_desc.Width = width;
  d3d11_texture2D_desc.Height = height;
  d3d11_texture2D_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  d3d11_texture2D_desc.MipLevels = 1;
  d3d11_texture2D_desc.ArraySize = 1;
  d3d11_texture2D_desc.SampleDesc.Count = 1;
  d3d11_texture2D_desc.SampleDesc.Quality = 0;
  d3d11_texture2D_desc.Usage = D3D11_USAGE_DEFAULT;
  d3d11_texture2D_desc.BindFlags =
      D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  d3d11_texture2D_desc.CPUAccessFlags = 0;
  d3d11_texture2D_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

  // create internal texture
  hr =  _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr, &_internalD3DTexture2D);
  if FAILED(hr)
  {
    result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
  }
  auto resource = Microsoft::WRL::ComPtr<IDXGIResource>{};
  hr = _internalD3DTexture2D.As(&resource);
  
  if FAILED(hr) { 
    result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
  }
  hr = resource->GetSharedHandle(&_internalD3DTextureHandle);
  if FAILED(hr) { 
    result->Error("ERROR", "Failed to get shared handle to D3D texture", nullptr);
    return;
  }
  _internalD3DTexture2D->AddRef();

  std::cout << "Created internal D3D texture" << std::endl;

  // external
  hr =  _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr, &_externalD3DTexture2D);
  if FAILED(hr)
  {
    result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
  }
  hr = _externalD3DTexture2D.As(&resource);
  
  if FAILED(hr) { 
    result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
  }
  hr = resource->GetSharedHandle(&_externalD3DTextureHandle);
  if FAILED(hr) { 
    result->Error("ERROR", "Failed to get shared handle to external D3D texture", nullptr);
    return;
  }
  _externalD3DTexture2D->AddRef();

  std::cout << "Created external D3D texture" << std::endl;

  _platform = new filament::backend::PlatformANGLE(_internalD3DTextureHandle, width, height);

  _textureDescriptor = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
  _textureDescriptor->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  _textureDescriptor->handle = _externalD3DTextureHandle;
  _textureDescriptor->width = _textureDescriptor->visible_width = width;
  _textureDescriptor->height = _textureDescriptor->visible_height = height;
  _textureDescriptor->release_context = nullptr;
  _textureDescriptor->release_callback = [](void* release_context) {};
  _textureDescriptor->format = kFlutterDesktopPixelFormatBGRA8888;

  _texture =
        std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
            [&](auto, auto) { return _textureDescriptor.get(); }));

  _flutterTextureId = _textureRegistrar->RegisterTexture(_texture.get());
  std::cout << "Registered Flutter texture ID " << _flutterTextureId << std::endl;

  _D3D11DeviceContext->CopyResource(_externalD3DTexture2D.Get(),
      _internalD3DTexture2D.Get());
  _D3D11DeviceContext->Flush();

  _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);

  std::vector<flutter::EncodableValue> resultList;
  resultList.push_back(flutter::EncodableValue(_flutterTextureId));
  resultList.push_back(flutter::EncodableValue((int64_t)nullptr));
  resultList.push_back(flutter::EncodableValue(_platform->glTextureId));
  result->Success(resultList);
      
}

void PolyvoxFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // std::cout << methodCall.method_name() << std::endl;
  if (methodCall.method_name() == "getSharedContext") {
    result->Success(flutter::EncodableValue((int64_t)nullptr));
  } else if (methodCall.method_name() == "getResourceLoaderWrapper") {
    const ResourceLoaderWrapper *const resourceLoader =
      new ResourceLoaderWrapper(_loadResource, _freeResource, this);
    result->Success(flutter::EncodableValue((int64_t)resourceLoader));
  } else if (methodCall.method_name() == "createTexture") {
    CreateTexture(methodCall, std::move(result));
  } else if(methodCall.method_name() == "getRenderCallback") {
    flutter::EncodableList resultList;
    resultList.push_back(flutter::EncodableValue((int64_t)&render_callback));
    resultList.push_back(flutter::EncodableValue((int64_t)this));
    result->Success(resultList);
  } else if(methodCall.method_name() == "getDriverPlatform") { 
    result->Success(flutter::EncodableValue((int64_t)_platform));
  }
}

} // namespace polyvox_filament

