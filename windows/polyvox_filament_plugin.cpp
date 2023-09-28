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
// #include "PlatformANGLE.h"
#include "GL/GL.h"
#include "GL/GLu.h"
#include "GL/wglext.h"

#include <Windows.h>
#include <wrl.h>

#include "ThreadPool.hpp"


namespace polyvox_filament {

static ThreadPool* _tp;


GLuint CompileShader(GLenum type, const std::string& source) {
  auto shader = glCreateShader(type);
  const char* s[1] = {source.c_str()};
  glShaderSource(shader, 1, s, NULL);
  glCompileShader(shader);
  return shader;
}

GLuint CompileProgram(const std::string& vertex_shader_source,
                      const std::string& fragment_shader_source) {
  auto program = glCreateProgram();

  auto vs = CompileShader(GL_VERTEX_SHADER, vertex_shader_source);
  auto fs = CompileShader(GL_FRAGMENT_SHADER, fragment_shader_source);
  if (vs == 0 || fs == 0) {
    glDeleteShader(fs);
    glDeleteShader(vs);
    glDeleteProgram(program);
    return 0;
  }
  glAttachShader(program, vs);
  glDeleteShader(vs);
  glAttachShader(program, fs);
  glDeleteShader(fs);
  glLinkProgram(program);
  return program;
}

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
    TCHAR pBuf[256];
    size_t len = sizeof(pBuf);
    int bytes = GetModuleFileName(NULL, pBuf, len);
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring assetPath = converter.from_bytes(name);

    std::wstring exePathBuf(pBuf);
    std::filesystem::path exePath(exePathBuf);
    auto exeDir = exePath.remove_filename();
    targetFilePath = exeDir.wstring() + L"data/flutter_assets/" +
                            assetPath;
  }
  std::wcout << "Loading from " << targetFilePath << std::endl;
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

void PolyvoxFilamentPlugin::CreateFilamentViewer(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if(!_tp) {
    _tp = new ThreadPool();
  }

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = uint32_t(*(std::get_if<double>(&(args->at(0)))));
  const auto height = uint32_t(*(std::get_if<double>(&(args->at(1)))));

  const ResourceLoaderWrapper *const resourceLoader =
      new ResourceLoaderWrapper(_loadResource, _freeResource, this);
    _viewer = (void *)create_filament_viewer(nullptr, resourceLoader, _platform);
     
    // headless
   create_swap_chain(_viewer, nullptr, width, height);
   create_render_target(_viewer, _platform->glTextureId, width, height);

    result->Success(flutter::EncodableValue((int64_t)_viewer));

}
    using namespace std::chrono_literals;
void PolyvoxFilamentPlugin::Render(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
    render(_viewer, 0, nullptr, nullptr, nullptr);
   
    _D3D11DeviceContext->CopyResource(_externalD3DTexture2D.Get(),
                                          _internalD3DTexture2D.Get());
    _D3D11DeviceContext->Flush();
    _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);

  result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::SetRendering(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  _rendering = *(std::get_if<bool>(methodCall.arguments()));
  result->Success(flutter::EncodableValue("OK"));
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

  filament::backend::Platform::DriverConfig config;

  // std::packaged_task<void()> lambda([&]() mutable {

  // _platform->createDriver(nullptr, config);

  //     std::cout << glGetString(GL_VERSION) << std::endl;
  //     constexpr char kVertexShader[] = R"(attribute vec4 vPosition;
  //       void main()
  //       {
  //           gl_Position = vPosition;
  //       })";
  //     constexpr char kFragmentShader[] = R"(precision mediump float;
  //       void main()
  //       {
  //           gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
  //       })";
  //     auto program = CompileProgram(kVertexShader, kFragmentShader);
  //     glEnableVertexAttribArray(0);
  //     glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  //     GLfloat vertices[] = {
  //         0.0f, -0.5f, 0.0f, -0.5f, 0.5f, 0.0f, 0.5f, 0.5f, 0.0f,
  //     };
  //     glClear(GL_COLOR_BUFFER_BIT);
  //     glViewport(0, 0, width, height);
  //     glUseProgram(program);
  //     glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, vertices);
  //     glDrawArrays(GL_TRIANGLES, 0, 3);
  //     glDisableVertexAttribArray(0);
  //     glFinish();

      _D3D11DeviceContext->CopyResource(_externalD3DTexture2D.Get(),
          _internalD3DTexture2D.Get());
      _D3D11DeviceContext->Flush();

      _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);
      result->Success(flutter::EncodableValue(_flutterTextureId));
      // }
}

void PolyvoxFilamentPlugin::SetBackgroundImage(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto path = std::get_if<std::string>(&(args->at(0)));
  const auto fillHeight = std::get_if<bool>(&(args->at(1)));
  // std::packaged_task<void()> lambda([&]() mutable  {
    set_background_image(_viewer, path->c_str(), *fillHeight);
  // });
  // auto fut = _tp->add_task(lambda);
  // fut.wait();
  
  result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::SetBackgroundColor(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto r = std::get_if<double>(&(args->at(0)));
  const auto g = std::get_if<double>(&(args->at(1)));
  const auto b = std::get_if<double>(&(args->at(2)));
  const auto a = std::get_if<double>(&(args->at(3)));
  // std::packaged_task<void()> lambda([&]() mutable  {
      set_background_color(_viewer, static_cast<float>(*r), static_cast<float>(*g),
                       static_cast<float>(*b), static_cast<float>(*a));
  // });
  // auto fut = _tp->add_task(lambda);
  // fut.wait();

  result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::GetAssetManager(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto assetManager = get_asset_manager(_viewer);
  result->Success(flutter::EncodableValue((int64_t)assetManager));
}

void PolyvoxFilamentPlugin::UpdateViewportAndCameraProjection(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = std::get_if<int32_t>(&(args->at(0)));
  const auto height = std::get_if<int32_t>(&(args->at(1)));
  const auto scaleFactor = std::get_if<double>(&(args->at(2)));

  update_viewport_and_camera_projection(_viewer, (uint32_t)*width,
                                        (uint32_t)*height,
                                        static_cast<double>(*scaleFactor));
  result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::LoadSkybox(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args = std::get_if<std::string>(methodCall.arguments());
  // std::packaged_task<void()> lambda([&]() mutable  {
    load_skybox(_viewer, (*args).c_str());
  // });
  // auto fut = _tp->add_task(lambda);
  // fut.wait();
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RemoveIbl(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::packaged_task<void()> lambda([&]() mutable  {
    remove_ibl(_viewer);
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
  
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::LoadIbl(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto path = std::get_if<std::string>(&(args->at(0)));
  const auto intensity = std::get_if<double>(&(args->at(1)));
  std::packaged_task<void()> lambda([&]() mutable  {
    load_ibl(_viewer, (*path).c_str(), static_cast<float>(*intensity));
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
  
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RemoveSkybox(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::packaged_task<void()> lambda([&]() mutable  {
    remove_skybox(_viewer);
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
  
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::AddLight(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto type = *std::get_if<int>(&(args->at(0)));
  const auto color = *std::get_if<double>(&(args->at(1)));
  const auto intensity = *std::get_if<double>(&(args->at(2)));
  const auto posX = *std::get_if<double>(&(args->at(3)));
  const auto posY = *std::get_if<double>(&(args->at(4)));
  const auto posZ = *std::get_if<double>(&(args->at(5)));
  const auto dirX = *std::get_if<double>(&(args->at(6)));
  const auto dirY = *std::get_if<double>(&(args->at(7)));
  const auto dirZ = *std::get_if<double>(&(args->at(8)));
  const auto shadows = *std::get_if<bool>(&(args->at(9)));

  std::packaged_task<void()> lambda([&]() mutable  {
    auto entityId = add_light(_viewer, type, color, intensity, posX, posY, posZ,
                            dirX, dirY, dirZ, shadows);
    result->Success(flutter::EncodableValue(entityId));
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
}

void PolyvoxFilamentPlugin::LoadGlb(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto path = *std::get_if<std::string>(&(args->at(1)));
  const auto unlit = *std::get_if<bool>(&(args->at(2)));
  
  std::packaged_task<void()> lambda([&]() mutable  {
    auto entityId = load_glb((void *)assetManager, path.c_str(), unlit);
    result->Success(flutter::EncodableValue(entityId));
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
}

void PolyvoxFilamentPlugin::GetAnimationNames(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto asset = *std::get_if<int32_t>(&(args->at(1)));

  std::vector<flutter::EncodableValue> names;

  auto numNames = get_animation_count((void *)assetManager, asset);

  for (int i = 0; i < numNames; i++) {
    char out[255];
    get_animation_name((void *)assetManager, asset, out, i);
    names.push_back(flutter::EncodableValue(out));
  }

  result->Success(names);
}

void PolyvoxFilamentPlugin::RemoveAsset(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto asset = *std::get_if<int>(&(args->at(1)));
  std::packaged_task<void()> lambda([&]() mutable  {
    remove_asset(_viewer, asset);
    result->Success(flutter::EncodableValue("OK"));
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
}

void PolyvoxFilamentPlugin::TransformToUnitCube(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto asset = *std::get_if<int32_t>(&(args->at(1)));
  std::packaged_task<void()> lambda([&]() mutable  {
    transform_to_unit_cube((void *)assetManager, asset);
    result->Success(flutter::EncodableValue("OK"));
  });
  auto fut = _tp->add_task(lambda);
  fut.wait();
}

void PolyvoxFilamentPlugin::RotateStart(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));

  std::packaged_task<void()> lambda([=]() mutable  {
    grab_begin(_viewer, static_cast<float>(x), static_cast<float>(y), false);
  });
  auto fut = _tp->add_task(lambda);

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RotateEnd(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::packaged_task<void()> lambda([=]() mutable  {
    grab_end(_viewer);
  });
  auto fut = _tp->add_task(lambda);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RotateUpdate(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));
  std::packaged_task<void()> lambda([=]() mutable  {
    grab_update(_viewer, static_cast<float>(x), static_cast<float>(y));
  });
  auto fut = _tp->add_task(lambda);

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::PanStart(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));

  grab_begin(_viewer, static_cast<float>(x), static_cast<float>(y), true);

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::PanUpdate(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));

  grab_update(_viewer, static_cast<float>(x), static_cast<float>(y));

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::PanEnd(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  grab_end(_viewer);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::SetPosition(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto asset = *std::get_if<int32_t>(&(args->at(1)));
  const auto x = *std::get_if<double>(&(args->at(2)));
  const auto y = *std::get_if<double>(&(args->at(3)));
  const auto z = *std::get_if<double>(&(args->at(4)));

  set_position((void *)assetManager, asset, static_cast<float>(x),
               static_cast<float>(y), static_cast<float>(z));

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::SetRotation(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto asset = *std::get_if<int32_t>(&(args->at(1)));
  const auto rads = *std::get_if<double>(&(args->at(2)));
  const auto x = *std::get_if<double>(&(args->at(3)));
  const auto y = *std::get_if<double>(&(args->at(4)));
  const auto z = *std::get_if<double>(&(args->at(5)));

  set_rotation((void *)assetManager, asset, static_cast<float>(rads),
               static_cast<float>(x), static_cast<float>(y),
               static_cast<float>(z));

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::GrabBegin(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = static_cast<float>(*std::get_if<double>(&(args->at(0))));
  const auto y = static_cast<float>(*std::get_if<double>(&(args->at(1))));
  auto pan = std::get_if<bool>(&(args->at(2)));

  grab_begin(_viewer, x, y, pan);

  flutter::EncodableValue response("OK");

  result->Success(response);
}

void PolyvoxFilamentPlugin::GrabEnd(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  grab_end(_viewer);
  flutter::EncodableValue response("OK");
  result->Success(response);
}

void PolyvoxFilamentPlugin::GrabUpdate(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = static_cast<float>(*std::get_if<double>(&(args->at(0))));
  const auto y = static_cast<float>(*std::get_if<double>(&(args->at(1))));

  grab_update(_viewer, x, y);

  flutter::EncodableValue response("OK");

  result->Success(response);
}

void PolyvoxFilamentPlugin::ScrollBegin(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  scroll_begin(_viewer);
  flutter::EncodableValue response("OK");
  result->Success(response);
}

void PolyvoxFilamentPlugin::ScrollEnd(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  scroll_end(_viewer);
  flutter::EncodableValue response("OK");
  result->Success(response);
}

void PolyvoxFilamentPlugin::ScrollUpdate(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args = std::get_if<flutter::EncodableList>(methodCall.arguments());
  const float x = static_cast<float>(*std::get_if<double>(&(args->at(0))));
  const float y = static_cast<float>(*std::get_if<double>(&(args->at(1))));
  const float z = static_cast<float>(*std::get_if<double>(&(args->at(2))));

  scroll_update(_viewer, x, y, z);

  flutter::EncodableValue response("OK");

  result->Success(response);
}

void PolyvoxFilamentPlugin::ClearAssets(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  clear_assets(_viewer);
  flutter::EncodableValue response("OK");
  result->Success(response);
}

void PolyvoxFilamentPlugin::ClearLights(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  clear_lights(_viewer);
  flutter::EncodableValue response("OK");
  result->Success(response);
}


void PolyvoxFilamentPlugin::MoveCameraToAsset(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto * entityId = std::get_if<int32_t>(methodCall.arguments());
  if(!entityId) {
    const auto * entityId64 = std::get_if<int64_t>(methodCall.arguments());
    if (!entityId64) {
        result->Error("No entity ID provided");
        return;
    }
  }
  move_camera_to_asset(_viewer, *entityId);
  flutter::EncodableValue response("OK");
  result->Success(response);
}

void PolyvoxFilamentPlugin::SetViewFrustumCulling(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto* culling = std::get_if<bool>(methodCall.arguments());
  if(!culling) {
    result->Error("No arg provided");  
    return;
  }
  std::cout << "Setting frustum culling to " << culling << std::endl;
  set_view_frustum_culling(_viewer, *culling);
  flutter::EncodableValue response("OK");
  result->Success(response);
}


void PolyvoxFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // std::cout << methodCall.method_name() << std::endl;

  if (methodCall.method_name() == "createFilamentViewer") {
    CreateFilamentViewer(methodCall, std::move(result));
  } else if (methodCall.method_name() == "createTexture") {
    CreateTexture(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setBackgroundImage") {
    SetBackgroundImage(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setBackgroundColor") {
    SetBackgroundColor(methodCall, std::move(result));
  } else if (methodCall.method_name() == "render") {
    Render(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setRendering") {
    SetRendering(methodCall, std::move(result));
  } else if (methodCall.method_name() == "updateViewportAndCameraProjection") {
    UpdateViewportAndCameraProjection(methodCall, std::move(result));
  } else if (methodCall.method_name() == "getAssetManager") {
    GetAssetManager(methodCall, std::move(result));
  } else if (methodCall.method_name() == "addLight") {
    AddLight(methodCall, std::move(result));
  } else if (methodCall.method_name() == "loadGlb") {
    LoadGlb(methodCall, std::move(result));
  } else if (methodCall.method_name() == "loadSkybox") {
    LoadSkybox(methodCall, std::move(result));
  } else if (methodCall.method_name() == "loadIbl") {
    LoadIbl(methodCall, std::move(result));
  } else if (methodCall.method_name() == "removeIbl") {
    RemoveIbl(methodCall, std::move(result));
  } else if (methodCall.method_name() == "removeSkybox") {
    RemoveSkybox(methodCall, std::move(result));
  } else if (methodCall.method_name() == "addLight") {
    AddLight(methodCall, std::move(result));
  } else if (methodCall.method_name() == "getAnimationNames") {
    GetAnimationNames(methodCall, std::move(result));
  } else if (methodCall.method_name() == "removeAsset") {
    RemoveAsset(methodCall, std::move(result));
  } else if (methodCall.method_name() == "transformToUnitCube") {
    TransformToUnitCube(methodCall, std::move(result));
  } else if (methodCall.method_name() == "rotateStart") {
    RotateStart(methodCall, std::move(result));
  } else if (methodCall.method_name() == "rotateEnd") {
    RotateEnd(methodCall, std::move(result));
  } else if (methodCall.method_name() == "rotateUpdate") {
    RotateUpdate(methodCall, std::move(result));
  } else if (methodCall.method_name() == "panStart") {
    PanStart(methodCall, std::move(result));
  } else if (methodCall.method_name() == "panUpdate") {
    PanUpdate(methodCall, std::move(result));
  } else if (methodCall.method_name() == "panEnd") {
    PanEnd(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setPosition") {
    SetPosition(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setRotation") {
    SetRotation(methodCall, std::move(result));
  } else if (methodCall.method_name() == "grabBegin") {
    GrabBegin(methodCall, std::move(result));
  } else if (methodCall.method_name() == "grabEnd") {
    GrabEnd(methodCall, std::move(result));
  } else if (methodCall.method_name() == "grabUpdate") {
    GrabUpdate(methodCall, std::move(result));
  } else if (methodCall.method_name() == "scrollBegin") {
    ScrollBegin(methodCall, std::move(result));
  } else if (methodCall.method_name() == "scrollEnd") {
    ScrollEnd(methodCall, std::move(result));
  } else if (methodCall.method_name() == "scrollUpdate") {
    ScrollUpdate(methodCall, std::move(result));
  } else if (methodCall.method_name() == "clearAssets") {
    ClearAssets(methodCall, std::move(result));
  } else if (methodCall.method_name() == "clearLights") {
    ClearLights(methodCall, std::move(result));
  } else if (methodCall.method_name() == "moveCameraToAsset") {
    MoveCameraToAsset(methodCall, std::move(result));
  } else if (methodCall.method_name() == "setViewFrustumCulling") {
    SetViewFrustumCulling(methodCall, std::move(result));
  } else {
    result->NotImplemented();
  }
  // } else if(strcmp(method, "setToneMapping") == 0) {
  //   response = _set_tone_mapping(self, methodCall);
  // } else if(strcmp(method, "setBloom") == 0) {
  //   response = _set_bloom(self, methodCall);
  // } else if(strcmp(method, "resize") == 0) {
  //   response = _resize(self, methodCall);
  // } else if(strcmp(method, "getContext") == 0) {
  //   g_autoptr(FlValue) result =
  //        fl_value_new_int(reinterpret_cast<int64_t>(glXGetCurrentContext()));
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "getGlTextureId") == 0) {
  //   g_autoptr(FlValue) result =
  //        fl_value_new_int(reinterpret_cast<unsigned
  //        int>(((FilamentTextureGL*)self->texture)->texture_id));
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "getResourceLoader") == 0) {
  //   ResourceLoaderWrapper* resourceLoader = new
  //   ResourceLoaderWrapper(loadResource, freeResource); g_autoptr(FlValue)
  //   result =
  //        fl_value_new_int(reinterpret_cast<int64_t>(resourceLoader));
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  // } else if(strcmp(method, "setRendering") == 0) {
  //   self->rendering =  fl_value_get_bool(fl_methodCall_get_args(methodCall));
  //   response =
  //   FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));

  // } else if(strcmp(method, "setCamera") == 0) {
  //   response = _set_camera(self, method_call);
  // } else if(strcmp(method, "setCameraModelMatrix") == 0) {
  //   response = _set_camera_model_matrix(self, method_call);
  // } else if(strcmp(method, "setCameraExposure") == 0) {
  //   response = _set_camera_exposure(self, method_call);
  // } else if(strcmp(method, "setCameraPosition") == 0) {
  //   response = _set_camera_position(self, method_call);
  // } else if(strcmp(method, "setCameraRotation") == 0) {
  //   response = _set_camera_rotation(self, method_call);
  // } else if(strcmp(method, "setFrameInterval") == 0) {
  //   response = _set_frame_interval(self, method_call);
  // } else if(strcmp(method, "scrollBegin") == 0) {
  //   response = _scroll_begin(self, method_call);
  // } else if(strcmp(method, "scrollEnd") == 0) {
  //   response = _scroll_end(self, method_call);
  // } else if(strcmp(method, "scrollUpdate") == 0) {
  //   response = _scroll_update(self, method_call);
  // } else if(strcmp(method, "grabBegin") == 0) {
  //   response = _grab_begin(self, method_call);
  // } else if(strcmp(method, "grabEnd") == 0) {
  //   response = _grab_end(self, method_call);
  // } else if(strcmp(method, "grabUpdate") == 0) {
  //   response = _grab_update(self, method_call);
  // } else if(strcmp(method, "playAnimation") == 0) {
  //   response = _play_animation(self, method_call);
  // } else if(strcmp(method, "stopAnimation") == 0) {
  //   response = _stop_animation(self, method_call);
  // } else if(strcmp(method, "setMorphTargetWeights") == 0) {
  //   response = _set_morph_target_weights(self, method_call);
  // } else if(strcmp(method, "setMorphAnimation") == 0) {
  //   response = _set_morph_animation(self, method_call);
  // } else if(strcmp(method, "getMorphTargetNames") == 0) {
  //   response = _get_morph_target_names(self, method_call);
  // } else if(strcmp(method, "setPosition") == 0) {
  //   response = _set_position(self, method_call);
  // } else if(strcmp(method, "setBoneTransform") == 0) {
  //   response = _set_bone_transform(self, method_call);
  // } else {
  //   response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  // }

  // fl_method_call_respond(method_call, response, nullptr);
}

} // namespace polyvox_filament

