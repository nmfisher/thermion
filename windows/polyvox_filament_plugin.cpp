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
#ifdef USE_ANGLE
#include "PlatformANGLE.h"
#endif 

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
      registrar->texture_registrar(), registrar, channel);

  registrar->AddPlugin(std::move(plugin));
}

PolyvoxFilamentPlugin::PolyvoxFilamentPlugin(
    flutter::TextureRegistrar *textureRegistrar,
    flutter::PluginRegistrarWindows *pluginRegistrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>& channel)
    : _textureRegistrar(textureRegistrar), _pluginRegistrar(pluginRegistrar), _channel(std::move(channel)) {
      _channel->SetMethodCallHandler(
      [=](const auto &call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });
    }

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

    TCHAR pBuf[512];
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
  
  // std::lock_guard<std::mutex> guard(*(_renderMutex.get()));
  if (_active) {
      #ifdef USE_ANGLE
        _active->RenderCallback();
      #endif
      _textureRegistrar->MarkTextureFrameAvailable(_active->flutterTextureId);
  }
}

#ifdef USE_ANGLE
bool PolyvoxFilamentPlugin::CreateSharedEGLContext() { 
  
    //platform = new filament::backend::PlatformANGLE(_internalD3DTextureHandle,
  // width, height);
    _platform = new filament::backend::PlatformEGL(); 

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
      std::cout << "Failed to locate default D3D adapter"<< std::endl;
      return false;
    } 
    
    DXGI_ADAPTER_DESC adapter_desc_;
    adapter_->GetDesc(&adapter_desc_);
    std::wcout << L"D3D adapter description: " << adapter_desc_.Description << std::endl;
    
    auto hr = ::D3D11CreateDevice(
        adapter_, D3D_DRIVER_TYPE_UNKNOWN, 0, 0, feature_levels.begin(),
        static_cast<UINT>(feature_levels.size()), D3D11_SDK_VERSION,
        &_D3D11Device, 0, &_D3D11DeviceContext);

    if (FAILED(hr)) {   
      std::cout << "Failed to create D3D device"<< std::endl;
      return false;
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


    // *******************
    // *                 *
    // *                 *
    // * EGL starts here *
    // *                 *
    // *                 *
    // *                 *
    // *******************
    EGLBoolean bindAPI = eglBindAPI(EGL_OPENGL_ES_API);
    if (UTILS_UNLIKELY(!bindAPI)) {
        std::cout << "eglBindAPI EGL_OPENGL_ES_API failed" << std::endl;
        return false;
    }

    _eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert_invariant(_eglDisplay != EGL_NO_DISPLAY);

    EGLint major, minor;
    EGLBoolean initialized = false; 

    EGLDeviceEXT eglDevice;
    EGLint numDevices;

    if(auto* getPlatformDisplay = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
              eglGetProcAddress("eglGetPlatformDisplayEXT"))) {

        EGLint kD3D11DisplayAttributes[] = {
            EGL_PLATFORM_ANGLE_TYPE_ANGLE,
            EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
            EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
            EGL_TRUE,
            EGL_NONE,
        };
        _eglDisplay = getPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, EGL_DEFAULT_DISPLAY, kD3D11DisplayAttributes);
        initialized = eglInitialize(_eglDisplay, &major, &minor);
    }

    std::cout << "Got major " << major << " and minor " << minor << std::endl;

    if (UTILS_UNLIKELY(!initialized)) {
        std::cout << "eglInitialize failed" << std::endl;
        return false;
    }

    importGLESExtensionsEntryPoints();

    EGLint configsCount;

    EGLint configAttribs[] = {
      EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE,    8,
      EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_NONE
    };

    EGLint contextAttribs[] = {
            EGL_CONTEXT_CLIENT_VERSION, 3,
            EGL_NONE, EGL_NONE, // reserved for EGL_CONTEXT_OPENGL_NO_ERROR_KHR below
            EGL_NONE
    };

    // find an opaque config
    if (!eglChooseConfig(_eglDisplay, configAttribs, &_eglConfig, 1, &configsCount)) {
        return false;
    }

    _context = (void*)eglCreateContext(_eglDisplay, _eglConfig, EGL_NO_CONTEXT, contextAttribs);

    if (UTILS_UNLIKELY(_context == EGL_NO_CONTEXT)) {
        return false;
    }
}

bool PolyvoxFilamentPlugin::MakeD3DTexture(uint32_t width, uint32_t height,std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  importGLESExtensionsEntryPoints();

  if(_active.get()) {
    result->Error("ERROR", "Texture already exists. You must call destroyTexture before attempting to create a new one.");
    return false;
  } 

  _active = std::make_unique<FlutterAngleTexture>(
    _pluginRegistrar, 
    _textureRegistrar, 
    std::move(result), 
    width, 
    height,
    _D3D11Device,
    _D3D11DeviceContext,
    _eglConfig,
    _eglDisplay,
    _context, [=](size_t width, size_t height) {
      std::vector<int64_t> list;
      list.push_back((int64_t)width);
      list.push_back((int64_t)height);
      auto val = std::make_unique<flutter::EncodableValue>(list);
      this->_channel->InvokeMethod("resize", std::move(val), nullptr);
    });
  
  return _active->flutterTextureId != -1;
}
#else 
bool PolyvoxFilamentPlugin::CreateSharedWGLContext() { 

  HWND hwnd = _pluginRegistrar->GetView()
                  ->GetNativeWindow();

  HDC whdc = GetDC(hwnd);
  if (whdc == NULL) {
    std::cout << "No device context for temporary window" << std::endl;
    return false;
  }
     
    std::cout << "No GL context exists, creating" << std::endl;

    PIXELFORMATDESCRIPTOR pfd = {
          sizeof(PIXELFORMATDESCRIPTOR),
          1,
          PFD_DRAW_TO_BITMAP | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,    // Flags
          PFD_TYPE_RGBA,        // The kind of framebuffer. RGBA or palette.
          32,                   // Colordepth of the framebuffer.
          0, 0, 0, 0, 0, 0,
          0,
          0,
          0,
          0, 0, 0, 0,
          32,                   // Number of bits for the depthbuffer
          0,                    // Number of bits for the stencilbuffer
          0,                    // Number of Aux buffers in the framebuffer.
          PFD_MAIN_PLANE,
          0,
          0, 0, 0
      };

    int pixelFormat = ChoosePixelFormat(whdc, &pfd);
    SetPixelFormat(whdc, pixelFormat, &pfd);

    // We need a tmp context to retrieve and call wglCreateContextAttribsARB.
    HGLRC tempContext = wglCreateContext(whdc);
    if (!wglMakeCurrent(whdc, tempContext)) {
      std::cout <<"Failed to acquire temporary context" << std::endl;
      return false;
    }

    GLenum err = glGetError();

    if(err != GL_NO_ERROR) {
      std::cout <<"GL Error @ 455 %d" << std::endl;
      return false;
    }

    PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribs = nullptr;

    wglCreateContextAttribs =
        (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress(
            "wglCreateContextAttribsARB");

    if (!wglCreateContextAttribs) {
      std::cout <<"Failed to resolve wglCreateContextAttribsARB" << std::endl;
      return false;
    }

    for (int minor = 5; minor >= 1; minor--) {
      std::vector<int> mAttribs = {WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                                  WGL_CONTEXT_MINOR_VERSION_ARB, minor, 0};
      _context = wglCreateContextAttribs(whdc, nullptr, mAttribs.data());
      if (_context) {
        break;
      }
    }

    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(tempContext);

    if (!_context || !wglMakeCurrent(whdc, _context)) {
      std::cout << "Failed to create OpenGL context." << std::endl;
      return false;
    }


}

bool PolyvoxFilamentPlugin::MakeOpenGLTexture(uint32_t width, uint32_t height,std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if(_active.get()) {
    result->Error("ERROR", "Texture already exists. You must call destroyTexture before attempting to create a new one.");
    return false;
  } 

  _active = std::make_unique<OpenGLTextureBuffer>(
    _pluginRegistrar, 
    _textureRegistrar, 
    std::move(result), 
    width, 
    height, 
    _context, 
    _renderMutex
  );
  
  return _active->flutterTextureId != -1;

}
#endif


void PolyvoxFilamentPlugin::CreateTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

      
  if(!_renderMutex.get()) {
    _renderMutex = std::make_shared<std::mutex>();
  }
  
  std::lock_guard<std::mutex> guard(*(_renderMutex.get()));

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = (uint32_t)round(*(std::get_if<double>(&(args->at(0)))));
  const auto height = (uint32_t)round(*(std::get_if<double>(&(args->at(1)))));

  // create a single shared context for the life of the application
  // this will be used to create a backing texture and passed to Filament
  if(!_context) {
    #ifdef USE_ANGLE
      CreateSharedEGLContext();
    #else
      CreateSharedWGLContext();
    #endif
  }

  #ifdef USE_ANGLE
  bool success = MakeD3DTexture(width, height, std::move(result));
  #else
  bool success = MakeOpenGLTexture(width, height, std::move(result));
  #endif      
}

void PolyvoxFilamentPlugin::DestroyTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *flutterTextureId =
      std::get_if<int64_t>(methodCall.arguments());

  if(!flutterTextureId) {
    result->Error("NOT_IMPLEMENTED", "Flutter texture ID must be provided");
    return;
  }

  if(!_active) {
    result->Success("Texture has already been detroyed, ignoring");
    return;
  }

  if(_active->flutterTextureId != *flutterTextureId) {
    result->Error("TEXTURE_MISMATCH", "Specified texture ID is not active");
    return;
  }

  auto sh = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(std::move(result));

  _textureRegistrar->UnregisterTexture(_active->flutterTextureId, [=, 
      sharedResult=std::move(sh) 
  ]() {
      this->_inactive = std::move(this->_active);      
      auto unique = std::move(*(sharedResult.get()));
      unique->Success(flutter::EncodableValue(true));
      std::cout << "Unregistered/destroyed texture." << std::endl;
  });    
 

}

void PolyvoxFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (methodCall.method_name() == "getSharedContext") {
    result->Success(flutter::EncodableValue((int64_t)_context));
  } else if (methodCall.method_name() == "getResourceLoaderWrapper") {
    const ResourceLoaderWrapper *const resourceLoader =
      new ResourceLoaderWrapper(_loadResource, _freeResource, this);
    result->Success(flutter::EncodableValue((int64_t)resourceLoader));
  } else if (methodCall.method_name() == "createTexture") {
    CreateTexture(methodCall, std::move(result));
  } else if (methodCall.method_name() == "destroyTexture") {
    DestroyTexture(methodCall, std::move(result));
  } else if(methodCall.method_name() == "getRenderCallback") {
    flutter::EncodableList resultList;
    resultList.push_back(flutter::EncodableValue((int64_t)&render_callback));
    resultList.push_back(flutter::EncodableValue((int64_t)this));
    result->Success(resultList);
  } else if(methodCall.method_name() == "getDriverPlatform") { 
    #ifdef USE_ANGLE
      result->Success(flutter::EncodableValue((int64_t)_platform));
    #else
      result->Success(flutter::EncodableValue((int64_t)nullptr));
    #endif
  } else {
    result->Error("NOT_IMPLEMENTED", "Method is not implemented %s", methodCall.method_name());
  }
}

} // namespace polyvox_filament

