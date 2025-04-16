#include "d3d_context.h"
#include <iostream>

namespace thermion::windows::d3d
{

    D3DContext::D3DContext()
    {
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
        if (FAILED(hr))
        {
            std::cout << "Failed to create DXGI 1.1 factory" << std::endl;
            return;
        }
        dxgi->EnumAdapters(0, &adapter_);
        dxgi->Release();
        if (!adapter_)
        {
            std::cout << "Failed to locate default D3D adapter" << std::endl;
            return;
        }

        Microsoft::WRL::ComPtr<IDXGIFactory2> factory2;
        if (SUCCEEDED(dxgi->QueryInterface(IID_PPV_ARGS(&factory2))))
        {
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

        if (FAILED(hr))
        {
            std::cout << "Failed to create D3D device" << std::endl;
            return;
        }

        Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device = nullptr;
        auto dxgi_device_success = _D3D11Device->QueryInterface(
            __uuidof(IDXGIDevice), (void **)&dxgi_device);
        if (SUCCEEDED(dxgi_device_success) && dxgi_device != nullptr)
        {
            dxgi_device->SetGPUThreadPriority(5); // Must be in interval [-7, 7].
        }

        auto level = _D3D11Device->GetFeatureLevel();
        std::cout << "Direct3D Feature Level: "
                  << (((unsigned)level) >> 12) << "_"
                  << ((((unsigned)level) >> 8) & 0xf) << std::endl;
    }

    D3DContext::~D3DContext() { 
        if (_D3D11DeviceContext) {
            _D3D11DeviceContext->Release();
        }
        if (_D3D11Device) {
            _D3D11Device->Release();
        }
        std::cerr << "D3DContext destroyed" << std::endl;
    }

    std::unique_ptr<D3DTexture> D3DContext::CreateTexture(uint32_t width, uint32_t height)
    {
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

        Microsoft::WRL::ComPtr<ID3D11Texture2D> d3dTexture2D;
        
        auto hr = _D3D11Device->CreateTexture2D(&d3d11_texture2D_desc, nullptr, &d3dTexture2D);

        if FAILED (hr)
        {
            std::cout << "Failed to create D3D texture (" << hr << ")" << std::endl;
            return nullptr;
        }
        auto resource = Microsoft::WRL::ComPtr<IDXGIResource1>{};
        hr = d3dTexture2D.As(&resource);

        if FAILED (hr)
        {
            std::cout << "Failed to create D3D texture" << std::endl;
            return nullptr;
        }
        HANDLE d3dTexture2DHandle = nullptr;
        //hr = resource->GetSharedHandle(&d3dTexture2DHandle);
        hr = resource->CreateSharedHandle(nullptr, GENERIC_ALL, nullptr, &d3dTexture2DHandle);
        if FAILED (hr)
        {
            std::cout << "Failed to get shared handle to external D3D texture" << std::endl;
            return nullptr;
        }

        d3dTexture2D->AddRef();

        Flush();
        
        std::cout << "Created external D3D texture " << width << "x" << height << std::endl;
        auto texture =  std::make_unique<D3DTexture>(d3dTexture2D, d3dTexture2DHandle, width, height);

        ID3D11RenderTargetView* rtv = nullptr;
        D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
        rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
        rtvDesc.Texture2D.MipSlice = 0;

        hr = _D3D11Device->CreateRenderTargetView(d3dTexture2D.Get(), &rtvDesc, &rtv);
        if (FAILED(hr)) {
            std::cout << "Failed to create render target view" << std::endl;
            return std::nullptr_t();
        }

        // Clear the texture to blue
        float blueColor[4] = { 1.0f, 0.0f, 1.0f, 1.0f }; // RGBA
        _D3D11DeviceContext->ClearRenderTargetView(rtv, blueColor);

        Flush();
        return texture;
    }

    void D3DContext::Flush()
    {
        _D3D11DeviceContext->Flush();
    }

}