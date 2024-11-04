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

void EGLTexture::Flush() {
  // glFlush();  // Ensure GL commands are completed
  // _D3D11DeviceContext->Flush();  
}

HANDLE EGLTexture::GetTextureHandle() {
  return _d3dTexture2DHandle;
}

EGLTexture::~EGLTexture() {
  // if (_eglDisplay != EGL_NO_DISPLAY && _eglSurface != EGL_NO_SURFACE) {
  //   eglReleaseTexImage(_eglDisplay, _eglSurface, EGL_BACK_BUFFER);
  // }
  // auto success = eglDestroySurface(this->_eglDisplay, this->_eglSurface);
  // if(success != EGL_TRUE) {
  //   std::cout << "Failed to destroy EGL Surface" << std::endl;
  // }
  _d3dTexture2D->Release();
  // glDeleteTextures(1, &this->glTextureId);
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

  // external
  auto hr = _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr,
                                     &_d3dTexture2D);
  if FAILED (hr) {
    std::cout << "Failed to create D3D texture" << std::endl;
    return;
    ;
  }
  auto resource = Microsoft::WRL::ComPtr<IDXGIResource>{};
  hr = _d3dTexture2D.As(&resource);

  if FAILED (hr) {
    std::cout << "Failed to create D3D texture" << std::endl;
    return;
    ;
  }
  hr = resource->GetSharedHandle(&_d3dTexture2DHandle);
  if FAILED (hr) {
    std::cout << "Failed to get shared handle to external D3D texture" << std::endl;
    return;
    ;
  }
  _d3dTexture2D->AddRef();

  std::cout << "Created external D3D texture " << width << "x" << height << std::endl;

      // Create render target view of the texture
    ID3D11RenderTargetView* rtv = nullptr;
    D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
    rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
    rtvDesc.Texture2D.MipSlice = 0;
    
    hr = _D3D11Device->CreateRenderTargetView(_d3dTexture2D.Get(), &rtvDesc, &rtv);
    if (FAILED(hr)) {
        std::cout << "Failed to create render target view" << std::endl;
        return;
    }

    // Clear the texture to blue
    float blueColor[4] = { 0.0f, 0.0f, 1.0f, 1.0f }; // RGBA
    _D3D11DeviceContext->ClearRenderTargetView(rtv, blueColor);
     _D3D11DeviceContext->Flush();  

    std::cout << "Filled  D3D texture blue" << std::endl;

  EGLint pbufferAttribs[] = {
      EGL_WIDTH,          width,          EGL_HEIGHT,         height,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
  };

  _eglSurface = eglCreatePbufferFromClientBuffer(
      _eglDisplay, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE,
      _d3dTexture2DHandle, _eglConfig, pbufferAttribs);

  if (!eglMakeCurrent(_eglDisplay, _eglSurface, _eglSurface, _eglContext)) {
    // eglMakeCurrent failed
    logEglError("eglMakeCurrent");
    return;
  }

  /******************
   * 
   * 
   *  THis is working
   * 
   * 
   */
  // // Clear to purple
  // glClearColor(0.5f, 0.0f, 0.5f, 1.0f);
  // glClear(GL_COLOR_BUFFER_BIT);

  // // Present the surface
  // eglSwapBuffers(_eglDisplay, _eglSurface);
  
  // // Synchronize
  // glFlush();


 if (!eglMakeCurrent(_eglDisplay, _eglSurface, _eglSurface, _eglContext)) {
    logEglError("eglMakeCurrent");
    return;
  }

  // Create and setup shaders for rendering the texture
  const char* vertexShaderSource = R"(#version 300 es
    precision mediump float;
    in vec2 position;
    in vec2 texcoord;
    out vec2 v_texcoord;
    void main() {
        gl_Position = vec4(position, 0.0, 1.0);
        v_texcoord = texcoord;
    }
  )";

  const char* fragmentShaderSource = R"(#version 300 es
    precision mediump float;
    in vec2 v_texcoord;
    uniform sampler2D u_texture;
    out vec4 fragColor;
    void main() {
        fragColor = texture(u_texture, v_texcoord);
    }
  )";

  // Create and compile vertex shader
  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vertexShaderSource, nullptr);
  glCompileShader(vertexShader);

  // Check vertex shader compilation
  GLint success;
  GLchar infoLog[512];
  glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
  if (!success) {
      glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
      std::cout << "Vertex shader compilation failed:\n" << infoLog << std::endl;
  }

  // Create and compile fragment shader
  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &fragmentShaderSource, nullptr);
  glCompileShader(fragmentShader);

  // Check fragment shader compilation
  glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
  if (!success) {
      glGetShaderInfoLog(fragmentShader, 512, nullptr, infoLog);
      std::cout << "Fragment shader compilation failed:\n" << infoLog << std::endl;
  }

  // Create shader program
  GLuint shaderProgram = glCreateProgram();
  glAttachShader(shaderProgram, vertexShader);
  glAttachShader(shaderProgram, fragmentShader);
  glLinkProgram(shaderProgram);

  // Check program linking
  glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
  if (!success) {
      glGetProgramInfoLog(shaderProgram, 512, nullptr, infoLog);
      std::cout << "Shader program linking failed:\n" << infoLog << std::endl;
  }

  // Create the source texture
  GLuint sourceTexture;
  glGenTextures(1, &sourceTexture);
  glBindTexture(GL_TEXTURE_2D, sourceTexture);
  
  // Fill texture with purple color
  uint8_t purplePixels[] = {
      128, 0, 128, 255  // Single purple pixel (RGBA)
  };
  
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, purplePixels);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  // Create vertex buffer for fullscreen quad
  float vertices[] = {
      // Position    // Texcoords
      -1.0f, -1.0f,  0.0f, 0.0f,  // Bottom left
       1.0f, -1.0f,  1.0f, 0.0f,  // Bottom right
      -1.0f,  1.0f,  0.0f, 1.0f,  // Top left
       1.0f,  1.0f,  1.0f, 1.0f   // Top right
  };

  GLuint vbo;
  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

  // Setup vertex attributes
  glUseProgram(shaderProgram);
  GLint posAttrib = glGetAttribLocation(shaderProgram, "position");
  GLint texAttrib = glGetAttribLocation(shaderProgram, "texcoord");
  
  if (posAttrib < 0 || texAttrib < 0) {
      std::cout << "Failed to get attribute locations. position: " << posAttrib 
                << " texcoord: " << texAttrib << std::endl;
  }

  glEnableVertexAttribArray(posAttrib);
  glEnableVertexAttribArray(texAttrib);
  
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), 0);
  glVertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

  // Set texture uniform
  GLint texUniform = glGetUniformLocation(shaderProgram, "u_texture");
  glUniform1i(texUniform, 0); // Use texture unit 0

  // Clear and render
  glViewport(0, 0, width, height);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  // Draw the fullscreen quad
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

  // Present the result
  eglSwapBuffers(_eglDisplay, _eglSurface);

  glFlush();
  
  // // Cleanup
  // glDeleteBuffers(1, &vbo);
  // glDeleteProgram(shaderProgram);
  // glDeleteShader(vertexShader);
  // glDeleteShader(fragmentShader);
  // glDeleteTextures(1, &sourceTexture);

  // Check for errors
  GLenum error = glGetError();
  if (error != GL_NO_ERROR) {
      std::cout << "GL error after rendering: " << error << std::endl;
  }

  std::cout << "FINISHED TEXTURE CREATION AND RENDERING" << std::endl;
  
 _D3D11DeviceContext->Flush();  

  char const *version;

  version = (char const *)glGetString(GL_VERSION);
  std::cout << "Got version " << version << std::endl;

  EGLint major, minor;
  glGetIntegerv(GL_MAJOR_VERSION, &major);
  glGetIntegerv(GL_MINOR_VERSION, &minor);

  std::cout << "FINISHED TEXTURE CREATION" << std::endl;

}

void EGLTexture::FillBlueAndSaveToBMP(const char* filename) {
    // Create render target view of the texture
    ID3D11RenderTargetView* rtv = nullptr;
    D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
    rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
    rtvDesc.Texture2D.MipSlice = 0;
    
    HRESULT hr = _D3D11Device->CreateRenderTargetView(_d3dTexture2D.Get(), &rtvDesc, &rtv);
    if (FAILED(hr)) {
        std::cout << "Failed to create render target view" << std::endl;
        return;
    }

    // Clear the texture to blue
    float blueColor[4] = { 0.0f, 0.0f, 1.0f, 1.0f }; // RGBA
    _D3D11DeviceContext->ClearRenderTargetView(rtv, blueColor);
    
    // Create staging texture for CPU read access
    D3D11_TEXTURE2D_DESC stagingDesc = {};
    _d3dTexture2D->GetDesc(&stagingDesc);
    stagingDesc.Usage = D3D11_USAGE_STAGING;
    stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    stagingDesc.BindFlags = 0;
    stagingDesc.MiscFlags = 0;

    ID3D11Texture2D* stagingTexture = nullptr;
    hr = _D3D11Device->CreateTexture2D(&stagingDesc, nullptr, &stagingTexture);
    if (FAILED(hr)) {
        rtv->Release();
        std::cout << "Failed to create staging texture" << std::endl;
        return;
    }

    // Copy to staging texture
    _D3D11DeviceContext->CopyResource(stagingTexture, _d3dTexture2D.Get());
    
    // Save to BMP
    bool success = SaveTextureAsBMP(stagingTexture, filename);
    
    // Cleanup
    stagingTexture->Release();
    rtv->Release();
    
    if (success) {
        std::cout << "Successfully saved texture to " << filename << std::endl;
    }
}

bool EGLTexture::SaveTextureAsBMP(ID3D11Texture2D* texture, const char* filename) {
    D3D11_TEXTURE2D_DESC desc;
    texture->GetDesc(&desc);
    
    // Map texture to get pixel data
    D3D11_MAPPED_SUBRESOURCE mappedResource;
    HRESULT hr = _D3D11DeviceContext->Map(texture, 0, D3D11_MAP_READ, 0, &mappedResource);
    if (FAILED(hr)) {
        std::cout << "Failed to map texture" << std::endl;
        return false;
    }

    // BMP file header
    #pragma pack(push, 1)
    struct BMPHeader {
        uint16_t signature;
        uint32_t fileSize;
        uint32_t reserved;
        uint32_t dataOffset;
        uint32_t headerSize;
        int32_t width;
        int32_t height;
        uint16_t planes;
        uint16_t bitsPerPixel;
        uint32_t compression;
        uint32_t imageSize;
        int32_t xPixelsPerMeter;
        int32_t yPixelsPerMeter;
        uint32_t totalColors;
        uint32_t importantColors;
    };
    #pragma pack(pop)

    // Create and fill header
    BMPHeader header = {};
    header.signature = 0x4D42;  // 'BM'
    header.fileSize = sizeof(BMPHeader) + desc.Width * desc.Height * 4;
    header.dataOffset = sizeof(BMPHeader);
    header.headerSize = 40;
    header.width = desc.Width;
    header.height = desc.Height;
    header.planes = 1;
    header.bitsPerPixel = 32;
    header.compression = 0;
    header.imageSize = desc.Width * desc.Height * 4;
    header.xPixelsPerMeter = 2835;  // 72 DPI
    header.yPixelsPerMeter = 2835;  // 72 DPI

    // Write to file
    FILE* file = nullptr;
    fopen_s(&file, filename, "wb");
    if (!file) {
        _D3D11DeviceContext->Unmap(texture, 0);
        return false;
    }

    fwrite(&header, sizeof(header), 1, file);

    // Write pixel data (need to flip rows as BMP is bottom-up)
    uint8_t* srcData = reinterpret_cast<uint8_t*>(mappedResource.pData);
    for (int y = desc.Height - 1; y >= 0; y--) {
        uint8_t* rowData = srcData + y * mappedResource.RowPitch;
        fwrite(rowData, desc.Width * 4, 1, file);
    }

    fclose(file);
    _D3D11DeviceContext->Unmap(texture, 0);
    return true;
}

} // namespace thermion_flutter