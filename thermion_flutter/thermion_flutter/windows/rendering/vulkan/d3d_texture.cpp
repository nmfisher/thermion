#include "d3d_texture.h"
#include "utils.h"

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

namespace thermion::windows::d3d {

void D3DTexture::Flush() {
  // glFlush();  // Ensure GL commands are completed
  _D3D11DeviceContext->Flush();  
}

HANDLE D3DTexture::GetTextureHandle() {
  return _d3dTexture2DHandle;
}

D3DTexture::~D3DTexture() {
  _d3dTexture2D->Release();
}

bool IsNTHandleSupported(ID3D11Device* device) {
    Microsoft::WRL::ComPtr<ID3D11Device5> device5;
    return SUCCEEDED(device->QueryInterface(IID_PPV_ARGS(&device5)));
}

D3DTexture::D3DTexture(
    uint32_t width, uint32_t height,
    std::function<void(size_t, size_t)> onResizeRequested
    ) 
    : _width(width), _height(height), _onResizeRequested(onResizeRequested) {

  IDXGIAdapter *adapter_ = nullptr;

  auto feature_levels = {
      D3D_FEATURE_LEVEL_12_0,
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
      D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0,
      D3D_FEATURE_LEVEL_9_3,
  };
  
  IDXGIFactory1 *dxgi = nullptr;
  HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void **)&dxgi);
  if (FAILED(hr)) {
      std::cout << "Failed to create DXGI 1.1 factory" << std::endl;
      return;
  }
  dxgi->EnumAdapters(0, &adapter_);
  dxgi->Release();
  if (!adapter_) {
    std::cout << "Failed to locate default D3D adapter" << std::endl;
    return;
  }

  Microsoft::WRL::ComPtr<IDXGIFactory2> factory2;
if (SUCCEEDED(dxgi->QueryInterface(IID_PPV_ARGS(&factory2)))) {
    std::cout << "DXGI 1.2 or higher supported" << std::endl;
}

  DXGI_ADAPTER_DESC adapter_desc_;
  adapter_->GetDesc(&adapter_desc_);
  std::wcout << L"D3D adapter description: " << adapter_desc_.Description
             << std::endl;

  hr = ::D3D11CreateDevice(
      adapter_, D3D_DRIVER_TYPE_UNKNOWN, 0, D3D11_CREATE_DEVICE_BGRA_SUPPORT, feature_levels.begin(),
      static_cast<UINT>(feature_levels.size()), D3D11_SDK_VERSION,
      &_D3D11Device, 0, &_D3D11DeviceContext);

  if (FAILED(hr)) {
    std::cout << "Failed to create D3D device" << std::endl;
    return;
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device = nullptr;
  auto dxgi_device_success = _D3D11Device->QueryInterface(
      __uuidof(IDXGIDevice), (void **)&dxgi_device);
  if (SUCCEEDED(dxgi_device_success) && dxgi_device != nullptr) {
    dxgi_device->SetGPUThreadPriority(5); // Must be in interval [-7, 7].
  }

  auto level = _D3D11Device->GetFeatureLevel();
  std::cout << "Direct3D Feature Level: "
            << (((unsigned)level) >> 12) << "_"
            << ((((unsigned)level) >> 8) & 0xf) << std::endl;

  // Create texture
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
  d3d11_texture2D_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED | D3D11_RESOURCE_MISC_SHARED_NTHANDLE;
  
    hr = _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr, &_d3dTexture2D);
  if FAILED (hr) {
    std::cout << "Failed to create D3D texture (" << hr << ")" << std::endl;
    return;
  }
  auto resource = Microsoft::WRL::ComPtr<IDXGIResource1>{};
  hr = _d3dTexture2D.As(&resource);

  if FAILED (hr) {
    std::cout << "Failed to create D3D texture" << std::endl;
    return;
    ;
  }
  //hr = resource->GetSharedHandle(&_d3dTexture2DHandle);
  hr = resource->CreateSharedHandle(nullptr, GENERIC_ALL, nullptr, &_d3dTexture2DHandle);
  if FAILED (hr) {
    std::cout << "Failed to get shared handle to external D3D texture" << std::endl;
    return;
    ;
  }
  _d3dTexture2D->AddRef();

  std::cout << "Created external D3D texture " << width << "x" << height << std::endl;

}

void D3DTexture::FillBlueAndSaveToBMP(const char* filename) {
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

bool D3DTexture::SaveTextureAsBMP(ID3D11Texture2D* texture, const char* filename) {
    D3D11_TEXTURE2D_DESC desc;
    texture->GetDesc(&desc);
    
    // Map texture to get pixel data
    D3D11_MAPPED_SUBRESOURCE mappedResource;
    HRESULT hr = _D3D11DeviceContext->Map(texture, 0, D3D11_MAP_READ, 0, &mappedResource);
    if (FAILED(hr)) {
        std::cout << "Failed to map texture" << std::endl;
        return false;
    }

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