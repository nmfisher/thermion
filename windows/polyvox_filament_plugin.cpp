#include "polyvox_filament_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

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

#include "GL/GL.h"
#include "GL/GLu.h"
#include "GL/wglext.h"

#include "PolyvoxFilamentApi.h"

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
  TCHAR pBuf[256];
  size_t len = sizeof(pBuf);
  int bytes = GetModuleFileName(NULL, pBuf, len);
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
  std::wstring assetPath = converter.from_bytes(name);

  std::wstring exePathBuf(pBuf);
  std::filesystem::path exePath(exePathBuf);
  auto exeDir = exePath.remove_filename();
  std::filesystem::path p(exeDir.wstring() + L"data/flutter_assets/" +
                          assetPath);
  std::wcout << "Loading from " << p << std::endl;
  std::streampos length;
  std::ifstream is(p.c_str(), std::ios::binary);
  if (!is) {
    std::cout << "Failed to find resource at file path " << p << std::endl;
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

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = uint32_t(*(std::get_if<double>(&(args->at(0)))));
  const auto height = uint32_t(*(std::get_if<double>(&(args->at(1)))));

  const ResourceLoaderWrapper *const resourceLoader =
      new ResourceLoaderWrapper(_loadResource, _freeResource, this);

  wglMakeCurrent(NULL, NULL);

  _viewer = (void *)create_filament_viewer(_context, resourceLoader);

  // auto hwnd = _pluginRegistrar->GetView()->GetNativeWindow();

  create_swap_chain(_viewer, nullptr, width, height);

  create_render_target(_viewer, _glTextureId, width, height);

  result->Success(flutter::EncodableValue((int64_t)_viewer));
}

void PolyvoxFilamentPlugin::Render(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto callback = [](void *buf, size_t size, void *data) {
    auto plugin = (PolyvoxFilamentPlugin *)data;
    plugin->_textureRegistrar->MarkTextureFrameAvailable(
        plugin->_flutterTextureId);
  };
  // render(_viewer, 0, _pixelData.get(), callback, this);
  render(_viewer, 0, nullptr, nullptr, nullptr);
  _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);

  result->Success(flutter::EncodableValue(true));
}

void PolyvoxFilamentPlugin::SetRendering(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  _rendering = *(std::get_if<bool>(methodCall.arguments()));
}

void PolyvoxFilamentPlugin::CreateTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto width = (uint32_t)round(*(std::get_if<double>(&(args->at(0)))));
  const auto height = (uint32_t)round(*(std::get_if<double>(&(args->at(1)))));

  HWND hwnd = _pluginRegistrar->GetView()
                  ->GetNativeWindow(); // CreateWindowA("STATIC", "dummy", 0, 0,
                                       // 0, 1, 1, NULL, NULL, NULL, NULL);

  HDC whdc = GetDC(hwnd);
  if (whdc == NULL) {
    result->Error("ERROR", "No device context for temporary window", nullptr);
    return;
  }

  PIXELFORMATDESCRIPTOR pfd = {
      sizeof(PIXELFORMATDESCRIPTOR),
      1,
      PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER, // Flags
      PFD_TYPE_RGBA, // The kind of framebuffer. RGBA or palette.
      32,            // Colordepth of the framebuffer.
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      24, // Number of bits for the depthbuffer
      0,  // Number of bits for the stencilbuffer
      0,  // Number of Aux buffers in the framebuffer.
      PFD_MAIN_PLANE,
      0,
      0,
      0,
      0};

  int pixelFormat = ChoosePixelFormat(whdc, &pfd);
  SetPixelFormat(whdc, pixelFormat, &pfd);

  // We need a tmp context to retrieve and call wglCreateContextAttribsARB.
  HGLRC tempContext = wglCreateContext(whdc);
  if (!wglMakeCurrent(whdc, tempContext)) {
    result->Error("ERROR", "Failed to acquire temporary context", nullptr);
    return;
  }

  PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribs = nullptr;

  wglCreateContextAttribs =
      (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress(
          "wglCreateContextAttribsARB");

  if (!wglCreateContextAttribs) {
    result->Error("ERROR", "Failed to resolve wglCreateContextAttribsARB",
                  nullptr);
    return;
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

  hwnd = _pluginRegistrar->GetView()->GetNativeWindow();
  whdc = GetDC(hwnd);
  if (whdc == NULL) {
    result->Error("ERROR", "No device context for actual window", nullptr);
    return;
  }

  if (!_context || !wglMakeCurrent(whdc, _context)) {
    result->Error("ERROR", "Failed to create OpenGL context.");
    return;
  }

  _pixelData.reset(new uint8_t[width * height * 4]);

  glGenTextures(1, &_glTextureId);

  GLenum err = glGetError();

  if (err != GL_NO_ERROR) {
    result->Error("ERROR", "Failed to generate texture, GL error was %d", err);
    return;
  }

  glBindTexture(GL_TEXTURE_2D, _glTextureId);

  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, 0);

  err = glGetError();

  if (err != GL_NO_ERROR) {
    result->Error("ERROR", "Failed to generate texture, GL error was %d", err);
    return;
  }

  _pixelBuffer = std::make_unique<FlutterDesktopPixelBuffer>();
  _pixelBuffer->buffer = _pixelData.get();

  _pixelBuffer->width = size_t(width);
  _pixelBuffer->height = size_t(height);

  _texture =
      std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
          [=](size_t width,
              size_t height) -> const FlutterDesktopPixelBuffer * {
            if(!_context || !wglMakeCurrent(whdc, _context)) {
              std::cout << "Failed to switch OpenGL context." << std::endl;
            } else {
              uint8_t* data = new uint8_t[width*height*4];
              glBindTexture(GL_TEXTURE_2D, _glTextureId);
              glGetTexImage(GL_TEXTURE_2D,0,GL_RGBA,GL_UNSIGNED_BYTE,data);

              GLenum err = glGetError();

              if(err != GL_NO_ERROR) {
                if(err == GL_INVALID_OPERATION) {
                  std::cout << "Invalid op" << std::endl;
                } else if(err == GL_INVALID_VALUE) {
                std::cout << "Invalid value" << std::endl;
                } else if(err == GL_OUT_OF_MEMORY) {
                  std::cout << "Out of mem" << std::endl;
                } else if(err == GL_INVALID_ENUM ) {
                  std::cout << "Invalid enum" << std::endl;
                } else {
                  std::cout << "Unknown error" << std::endl;            
                }
              }

              _pixelData.reset(data);
              wglMakeCurrent(NULL, NULL);
            }
            _pixelBuffer->buffer = _pixelData.get();

            return _pixelBuffer.get();
          }));

  _flutterTextureId = _textureRegistrar->RegisterTexture(_texture.get());
  std::cout << "Registered flutter texture " << _flutterTextureId << std::endl;
  result->Success(flutter::EncodableValue(_flutterTextureId));
}

void PolyvoxFilamentPlugin::SetBackgroundImage(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto path = std::get_if<std::string>(&(args->at(0)));
  const auto fillHeight = std::get_if<bool>(&(args->at(1)));
  set_background_image(_viewer, path->c_str(), *fillHeight);
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
  set_background_color(_viewer, static_cast<float>(*r), static_cast<float>(*g),
                       static_cast<float>(*b), static_cast<float>(*a));
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
  load_skybox(_viewer, (*args).c_str());
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RemoveIbl(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  remove_ibl(_viewer);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::LoadIbl(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto path = std::get_if<std::string>(&(args->at(0)));
  const auto intensity = std::get_if<double>(&(args->at(1)));
  load_ibl(_viewer, (*path).c_str(), static_cast<float>(*intensity));
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RemoveSkybox(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  remove_skybox(_viewer);
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
  auto entityId = add_light(_viewer, type, color, intensity, posX, posY, posZ,
                            dirX, dirY, dirZ, shadows);
  result->Success(flutter::EncodableValue(entityId));
}

void PolyvoxFilamentPlugin::LoadGlb(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto path = *std::get_if<std::string>(&(args->at(1)));
  const auto unlit = *std::get_if<bool>(&(args->at(2)));
  auto entityId = load_glb((void *)assetManager, path.c_str(), unlit);
  result->Success(flutter::EncodableValue(entityId));
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
  remove_asset(_viewer, asset);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::TransformToUnitCube(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto assetManager = *std::get_if<int64_t>(&(args->at(0)));
  const auto asset = *std::get_if<int32_t>(&(args->at(1)));
  transform_to_unit_cube((void *)assetManager, asset);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RotateStart(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));

  grab_begin(_viewer, static_cast<float>(x), static_cast<float>(y), false);

  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RotateEnd(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  grab_end(_viewer);
  result->Success(flutter::EncodableValue("OK"));
}

void PolyvoxFilamentPlugin::RotateUpdate(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
  const auto x = *std::get_if<double>(&(args->at(0)));
  const auto y = *std::get_if<double>(&(args->at(1)));
  grab_update(_viewer, static_cast<float>(x), static_cast<float>(y));
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

// glfwInit();
// glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
// glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
// glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

// glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

// GLFWwindow* window = glfwCreateWindow(1024, 768, "", nullptr, nullptr);
// if (!window) {
//     std::cout << "Failed to create GLFW window" << std::endl;
//     glfwTerminate();
//     return;
// }

// glfwMakeContextCurrent(window);

// glClearColor(0.1f, 0.2f, 0.3f, 1.0f);
// glClear(GL_COLOR_BUFFER_BIT);

// auto data = new uint8_t[1024*768*4];
// glReadPixels(0,0, 1024, 768, GL_RGBA, GL_UNSIGNED_BYTE, data);
// _pixelData.reset(data);

// GLuint glTextureId = 0;

// auto textureData = new uint8_t[1024*768*4];
// for(int y = 0; y < 768; y++) {
//   for(int x=0; x < 1024; x++) {
//     textureData[y*768 + (x*4)] = 0;
//     textureData[y*768 + (x*4+1)] = 255;
//     textureData[y*768 + (x*4+2)] = 0;
//     textureData[y*768 + (x*4+3)] = 255;
//   }
// }

// glGenTextures(1, &glTextureId);

// glBindTexture(GL_TEXTURE_2D, glTextureId);

// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);

// glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1024, 768, 0, GL_RGBA,
//                 GL_UNSIGNED_BYTE, textureData);

// _pixelBuffer = std::make_unique<FlutterDesktopPixelBuffer>();
// _pixelBuffer->buffer = _pixelData.get();

// _pixelBuffer->width = 1024;
// _pixelBuffer->height = 768;

// _texture =
// std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
//     [=](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
//       std::cout << "Copying pixel buffer for " << width << "x" << height <<
//       std::endl;
//       // uint8_t* data = _pixelData.get();
//       uint8_t* data = new uint8_t[height*width*4];
//       glReadPixels(0,0, (GLsizei)width, (GLsizei)height, GL_RGB,
//       GL_UNSIGNED_BYTE, data); return _pixelBuffer.get();
//     }));

// std::cout << "Registering texture" << std::endl;

// _flutterTextureId = _textureRegistrar->RegisterTexture(_texture.get());
// _textureRegistrar->MarkTextureFrameAvailable(_flutterTextureId);
// std::cout << "Registered " << _flutterTextureId << std::endl;