#pragma once

#include "windows/import.h"

#include <d3d.h>
#include <d3d11_1.h>
#include <dxgi1_2.h>
#include <d3d11_4.h>

#include <wrl.h>
#include <wrl/client.h>

#include "d3d/D3DTexture.h"

namespace thermion::windows::d3d { 

    class DLL_EXPORT D3DContext {
        public:
            D3DContext(const uint8_t *vulkanLUID); 
            ~D3DContext();
            void Flush();
            std::unique_ptr<D3DTexture> CreateTexture(uint32_t width, uint32_t height);
            
            bool IsValid() {
                return _D3D11Device;
            }


        private:
            ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
            ID3D11Device* _D3D11Device = nullptr;
            Microsoft::WRL::ComPtr<ID3D11Device5> _D3D11Device5;
            Microsoft::WRL::ComPtr<ID3D11DeviceContext4> _D3D11DeviceContext4;
            Microsoft::WRL::ComPtr<ID3D11Fence> _sharedFence;


    };
}