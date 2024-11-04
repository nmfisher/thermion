#include "egl_texture.h"

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

namespace thermion::windows::egl {

static void logEglError(const char *name) noexcept {
  const char *err;
  switch (eglGetError()) {
  case EGL_NOT_INITIALIZED:
    err = "EGL_NOT_INITIALIZED";
    break;
  case EGL_BAD_ACCESS:
    err = "EGL_BAD_ACCESS";
    break;
  case EGL_BAD_ALLOC:
    err = "EGL_BAD_ALLOC";
    break;
  case EGL_BAD_ATTRIBUTE:
    err = "EGL_BAD_ATTRIBUTE";
    break;
  case EGL_BAD_CONTEXT:
    err = "EGL_BAD_CONTEXT";
    break;
  case EGL_BAD_CONFIG:
    err = "EGL_BAD_CONFIG";
    break;
  case EGL_BAD_CURRENT_SURFACE:
    err = "EGL_BAD_CURRENT_SURFACE";
    break;
  case EGL_BAD_DISPLAY:
    err = "EGL_BAD_DISPLAY";
    break;
  case EGL_BAD_SURFACE:
    err = "EGL_BAD_SURFACE";
    break;
  case EGL_BAD_MATCH:
    err = "EGL_BAD_MATCH";
    break;
  case EGL_BAD_PARAMETER:
    err = "EGL_BAD_PARAMETER";
    break;
  case EGL_BAD_NATIVE_PIXMAP:
    err = "EGL_BAD_NATIVE_PIXMAP";
    break;
  case EGL_BAD_NATIVE_WINDOW:
    err = "EGL_BAD_NATIVE_WINDOW";
    break;
  case EGL_CONTEXT_LOST:
    err = "EGL_CONTEXT_LOST";
    break;
  default:
    err = "unknown";
    break;
  }
  std::cout << name << " failed with " << err << std::endl;
}

void EGLTexture::RenderCallback() {
  glFinish();
  _D3D11DeviceContext->CopyResource(_externalD3DTexture2D.Get(),
                                    _internalD3DTexture2D.Get());
  _D3D11DeviceContext->Flush();
}

EGLTexture::~EGLTexture() {
  if (_eglDisplay != EGL_NO_DISPLAY && _eglSurface != EGL_NO_SURFACE) {
    eglReleaseTexImage(_eglDisplay, _eglSurface, EGL_BACK_BUFFER);
  }
  auto success = eglDestroySurface(this->_eglDisplay, this->_eglSurface);
  if(success != EGL_TRUE) {
    std::cout << "Failed to destroy EGL Surface" << std::endl;
  }
  _internalD3DTexture2D->Release();
  _externalD3DTexture2D->Release();
  glDeleteTextures(1, &this->glTextureId);
}

EGLTexture::EGLTexture(
    uint32_t width, uint32_t height, ID3D11Device *D3D11Device,
    ID3D11DeviceContext *D3D11DeviceContext, EGLConfig eglConfig,
    EGLDisplay eglDisplay, EGLContext eglContext,
    std::function<void(size_t, size_t)> onResizeRequested
    )
    : _width(width), _height(height), _D3D11Device(D3D11Device),
      _D3D11DeviceContext(D3D11DeviceContext), _eglConfig(eglConfig),
      _eglDisplay(eglDisplay), _eglContext(eglContext), _onResizeRequested(onResizeRequested) {

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
  auto hr = _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr,
                                          &_internalD3DTexture2D);
  if FAILED (hr) {
    // result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
    ;
  }
  auto resource = Microsoft::WRL::ComPtr<IDXGIResource>{};
  hr = _internalD3DTexture2D.As(&resource);

  if FAILED (hr) {
    // result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
    ;
  }
  hr = resource->GetSharedHandle(&_internalD3DTextureHandle);
  if FAILED (hr) {
    // result->Error("ERROR", "Failed to get shared handle to D3D texture",
    //               nullptr);
    return;
    ;
  }
  _internalD3DTexture2D->AddRef();

  std::cout << "Created internal D3D texture" << std::endl;

  // external
  hr = _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr,
                                     &_externalD3DTexture2D);
  if FAILED (hr) {
    // result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
    ;
  }
  hr = _externalD3DTexture2D.As(&resource);

  if FAILED (hr) {
    // result->Error("ERROR", "Failed to create D3D texture", nullptr);
    return;
    ;
  }
  hr = resource->GetSharedHandle(&_externalD3DTextureHandle);
  if FAILED (hr) {
    // result->Error("ERROR",
    //               "Failed to get shared handle to external D3D texture",
    //               nullptr);
    return;
    ;
  }
  _externalD3DTexture2D->AddRef();

  std::cout << "Created external D3D texture" << std::endl;

  EGLint pbufferAttribs[] = {
      EGL_WIDTH,          width,          EGL_HEIGHT,         height,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
  };

  _eglSurface = eglCreatePbufferFromClientBuffer(
      _eglDisplay, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE,
      _internalD3DTextureHandle, _eglConfig, pbufferAttribs);

  if (!eglMakeCurrent(_eglDisplay, _eglSurface, _eglSurface, _eglContext)) {
    // eglMakeCurrent failed
    logEglError("eglMakeCurrent");
    return;
  }

  glGenTextures(1, &glTextureId);

  if (glTextureId == 0) {
    std::cout
        << "Failed to generate OpenGL texture for ANGLE, OpenGL err was %d",
        glGetError();
    return;
  }

  glBindTexture(GL_TEXTURE_2D, glTextureId);
  eglBindTexImage(_eglDisplay, _eglSurface, EGL_BACK_BUFFER);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  //  clearGlError
  GLenum const error = glGetError();
  if (error != GL_NO_ERROR) {
    std::cout << "Ignoring pending GL error " << error << std::endl;
  }
  char const *version;

  version = (char const *)glGetString(GL_VERSION);
  std::cout << "Got version " << version << std::endl;

  EGLint major, minor;
  glGetIntegerv(GL_MAJOR_VERSION, &major);
  glGetIntegerv(GL_MINOR_VERSION, &minor);

  // _textureDescriptor = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
  // _textureDescriptor->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  // _textureDescriptor->handle = _externalD3DTextureHandle;
  // _textureDescriptor->width = _textureDescriptor->visible_width = width;
  // _textureDescriptor->height = _textureDescriptor->visible_height = height;
  // _textureDescriptor->release_context = nullptr;
  // _textureDescriptor->release_callback = [](void *release_context) {

  // };
  // _textureDescriptor->format = kFlutterDesktopPixelFormatBGRA8888;

  // texture =
  //     std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
  //         kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
  //         [&](size_t width, size_t height) { 
  //           if(width != this->_width || height != this->_height) {
  //             this->_onResizeRequested(width, height);
  //           }
  //           return _textureDescriptor.get(); 
  //         }));

}

} // namespace thermion_flutter