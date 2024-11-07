#pragma once

#include <functional>
#include <mutex>

#include <d3d.h>
#include <d3d11_1.h>
#include <dxgi1_2.h>  
#include <d3d11_4.h>
#include <Windows.h>
#include <wrl.h>

namespace thermion::windows::d3d {

class D3DTexture {
  public:
    D3DTexture(
        Microsoft::WRL::ComPtr<ID3D11Texture2D> d3dTexture2D,
        HANDLE d3dTexture2DHandle,
        uint32_t width,
        uint32_t height
    );    
    ~D3DTexture();

    void Flush();
    HANDLE GetTextureHandle();
       
    void SaveToBMP(const char* filename);

    uint32_t GetWidth() {
      return _width;
    }

    uint32_t GetHeight() {
      return _height;
    }
      
  private:
    uint32_t _width = 0;
    uint32_t _height = 0;
    
    Microsoft::WRL::ComPtr<ID3D11Texture2D> _d3dTexture2D;
    HANDLE _d3dTexture2DHandle = nullptr;

    bool SaveTextureAsBMP(ID3D11Texture2D* texture, const char* filename);

    
};

}
