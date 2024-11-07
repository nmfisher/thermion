#include "d3d_texture.h"
#include "utils.h"

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

namespace thermion::windows::d3d
{

  bool IsNTHandleSupported(ID3D11Device *device)
  {
    Microsoft::WRL::ComPtr<ID3D11Device5> device5;
    return SUCCEEDED(device->QueryInterface(IID_PPV_ARGS(&device5)));
  }

  D3DTexture::D3DTexture(
      Microsoft::WRL::ComPtr<ID3D11Texture2D> d3dTexture2D,
      HANDLE d3dTexture2DHandle, uint32_t width, uint32_t height) : _d3dTexture2D(d3dTexture2D), _d3dTexture2DHandle(d3dTexture2DHandle), _width(width), _height(height)
  {
  }

  D3DTexture::~D3DTexture() {
    if (_d3dTexture2DHandle) {
      CloseHandle(_d3dTexture2DHandle);
      _d3dTexture2DHandle = nullptr;
    }
    if (_d3dTexture2D) {
      _d3dTexture2D->Release();
      _d3dTexture2D = nullptr;
    }  
  }

  HANDLE D3DTexture::GetTextureHandle() { 
    return _d3dTexture2DHandle;
  }

  void D3DTexture::SaveToBMP(const char *filename)
  {
    // // Create render target view of the texture
    // ID3D11RenderTargetView* rtv = nullptr;
    // D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
    // rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    // rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
    // rtvDesc.Texture2D.MipSlice = 0;

    // HRESULT hr = _D3D11Device->CreateRenderTargetView(_d3dTexture2D.Get(), &rtvDesc, &rtv);
    // if (FAILED(hr)) {
    //     std::cout << "Failed to create render target view" << std::endl;
    //     return;
    // }

    // // Create staging texture for CPU read access
    // D3D11_TEXTURE2D_DESC stagingDesc = {};
    // _d3dTexture2D->GetDesc(&stagingDesc);
    // stagingDesc.Usage = D3D11_USAGE_STAGING;
    // stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    // stagingDesc.BindFlags = 0;
    // stagingDesc.MiscFlags = 0;

    // ID3D11Texture2D* stagingTexture = nullptr;
    // hr = _D3D11Device->CreateTexture2D(&stagingDesc, nullptr, &stagingTexture);
    // if (FAILED(hr)) {
    //     rtv->Release();
    //     std::cout << "Failed to create staging texture" << std::endl;
    //     return;
    // }

    // // Copy to staging texture
    // _D3D11DeviceContext->CopyResource(stagingTexture, _d3dTexture2D.Get());

    // // Save to BMP
    // bool success = SaveTextureAsBMP(stagingTexture, filename);

    // // Cleanup
    // stagingTexture->Release();
    // rtv->Release();

    // if (success) {
    //     std::cout << "Successfully saved texture to " << filename << std::endl;
    // } else {
    //     std::cout << "Texture save failed to " << filename << std::endl;
    // }
  }

  bool D3DTexture::SaveTextureAsBMP(ID3D11Texture2D *texture, const char *filename)
  {
    return false;
    // D3D11_TEXTURE2D_DESC desc;
    // texture->GetDesc(&desc);

    // // Map texture to get pixel data
    // D3D11_MAPPED_SUBRESOURCE mappedResource;
    // HRESULT hr = _D3D11DeviceContext->Map(texture, 0, D3D11_MAP_READ, 0, &mappedResource);
    // if (FAILED(hr)) {
    //     std::cout << "Failed to map texture" << std::endl;
    //     return false;
    // }

    // auto success = SavePixelsAsBMP(reinterpret_cast<uint8_t*>(mappedResource.pData), desc.Width, desc.Height, mappedResource.RowPitch, filename);

    // if(!success) {
    //   std::cout << "BMP write failed" << std::endl;
    // }

    // _D3D11DeviceContext->Unmap(texture, 0);
    // return success;
  }

} // namespace thermion_flutter

// Create render target view of the texture
// ID3D11RenderTargetView* rtv = nullptr;
// D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
// rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
// rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
// rtvDesc.Texture2D.MipSlice = 0;

// hr = _D3D11Device->CreateRenderTargetView(_d3dTexture2D.Get(), &rtvDesc, &rtv);
// if (FAILED(hr)) {
//     std::cout << "Failed to create render target view" << std::endl;
//     return;
// }

// // Clear the texture to blue
// float blueColor[4] = { 0.0f, 0.0f, 1.0f, 1.0f }; // RGBA
// _D3D11DeviceContext->ClearRenderTargetView(rtv, blueColor);