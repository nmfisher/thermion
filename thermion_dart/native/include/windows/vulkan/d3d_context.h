#pragma once

#include "import.h"
#include "d3d_texture.h"

#include <d3d.h>
#include <d3d11_1.h>
#include <dxgi1_2.h>  
#include <d3d11_4.h>
#include <Windows.h>
#include <wrl.h>

namespace thermion::windows::d3d { 

    class DLL_EXPORT D3DContext {
        public:
            D3DContext();
            ~D3DContext();
            void Flush();
            std::unique_ptr<D3DTexture> CreateTexture(uint32_t width, uint32_t height);

        private:
            ID3D11DeviceContext* _D3D11DeviceContext = nullptr;
            ID3D11Device* _D3D11Device = nullptr;
    };
}