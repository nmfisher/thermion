#pragma once

#include <functional>
#include <mutex>

#include <d3d.h>
#include <d3d11_1.h>
#include <dxgi1_2.h>  // Add this line
#include <d3d11_4.h>
#include <Windows.h>
#include <wrl.h>

namespace thermion::windows::d3d {

class D3DTexture {
  public:
    D3DTexture(
        uint32_t width,
        uint32_t height,
        std::function<void(size_t, size_t)> onResizeRequested
    );    
    ~D3DTexture();

    void Flush();
    HANDLE GetTextureHandle();
       
    static bool SavePixelsAsBMP(uint8_t* pixels, uint32_t width, uint32_t height, int rowPitch, const char* filename);

    void SaveToBMP(const char* filename);
    bool SaveTextureAsBMP(ID3D11Texture2D* texture, const char* filename);
    // Device
    ID3D11Device* _D3D11Device = nullptr;
      
  private:
    bool _error = false;
    uint32_t _width = 0;
    uint32_t _height = 0;
    bool logged = false;
    std::function<void(size_t, size_t)> _onResizeRequested;


    ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
    // Texture objects/shared handles
    Microsoft::WRL::ComPtr<ID3D11Texture2D> _d3dTexture2D;
    HANDLE _d3dTexture2DHandle = nullptr;
    
};

}
