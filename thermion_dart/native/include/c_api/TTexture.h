#ifndef _T_TEXTURE_H
#define _T_TEXTURE_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"

#ifdef __cplusplus
extern "C"
{
#endif

enum TTextureSamplerType
{
    SAMPLER_2D = 0,
    SAMPLER_2D_ARRAY = 1,
    SAMPLER_CUBEMAP=2,     
    SAMPLER_EXTERNAL=3,    
    SAMPLER_3D=4,
    SAMPLER_CUBEMAP_ARRAY=5
};

typedef enum TTextureSamplerType TTextureSamplerType;

enum TTextureFormat
{
    // 8-bits per element
    TEXTUREFORMAT_R8 = 0,                  // R 8-bits
    TEXTUREFORMAT_R8_SNORM,                // R 8-bits (signed normalized)
    TEXTUREFORMAT_R8UI,                    // R 8-bits (unsigned integer)
    TEXTUREFORMAT_R8I,                     // R 8-bits (signed integer)
    TEXTUREFORMAT_STENCIL8,                // Stencil 8-bits
    
    // 16-bits per element
    TEXTUREFORMAT_R16F,                    // R 16-bits (float)
    TEXTUREFORMAT_R16UI,                   // R 16-bits (unsigned integer)
    TEXTUREFORMAT_R16I,                    // R 16-bits (signed integer)
    TEXTUREFORMAT_RG8,                     // RG 8-bits each
    TEXTUREFORMAT_RG8_SNORM,               // RG 8-bits each (signed normalized)
    TEXTUREFORMAT_RG8UI,                   // RG 8-bits each (unsigned integer)
    TEXTUREFORMAT_RG8I,                    // RG 8-bits each (signed integer)
    TEXTUREFORMAT_RGB565,                  // RGB 5-6-5 bits
    TEXTUREFORMAT_RGB9_E5,                 // RGB9_E5 format
    TEXTUREFORMAT_RGB5_A1,                 // RGB 5 bits each, A 1 bit
    TEXTUREFORMAT_RGBA4,                   // RGBA 4 bits each
    TEXTUREFORMAT_DEPTH16,                 // Depth 16-bits
    
    // 24-bits per element
    TEXTUREFORMAT_RGB8,                    // RGB 8-bits each
    TEXTUREFORMAT_SRGB8,                   // RGB 8-bits each (sRGB color space)
    TEXTUREFORMAT_RGB8_SNORM,              // RGB 8-bits each (signed normalized)
    TEXTUREFORMAT_RGB8UI,                  // RGB 8-bits each (unsigned integer)
    TEXTUREFORMAT_RGB8I,                   // RGB 8-bits each (signed integer)
    TEXTUREFORMAT_DEPTH24,                 // Depth 24-bits
    
    // 32-bits per element
    TEXTUREFORMAT_R32F,                    // R 32-bits (float)
    TEXTUREFORMAT_R32UI,                   // R 32-bits (unsigned integer)
    TEXTUREFORMAT_R32I,                    // R 32-bits (signed integer)
    TEXTUREFORMAT_RG16F,                   // RG 16-bits each (float)
    TEXTUREFORMAT_RG16UI,                  // RG 16-bits each (unsigned integer)
    TEXTUREFORMAT_RG16I,                   // RG 16-bits each (signed integer)
    TEXTUREFORMAT_R11F_G11F_B10F,          // R11F_G11F_B10F format
    TEXTUREFORMAT_RGBA8,                   // RGBA 8-bits each
    TEXTUREFORMAT_SRGB8_A8,                // RGB 8-bits each (sRGB), A 8-bits
    TEXTUREFORMAT_RGBA8_SNORM,             // RGBA 8-bits each (signed normalized)
    TEXTUREFORMAT_UNUSED,                  // used to be rgbm
    TEXTUREFORMAT_RGB10_A2,                // RGB 10-bits each, A 2-bits
    TEXTUREFORMAT_RGBA8UI,                 // RGBA 8-bits each (unsigned integer)
    TEXTUREFORMAT_RGBA8I,                  // RGBA 8-bits each (signed integer)
    TEXTUREFORMAT_DEPTH32F,                // Depth 32-bits (float)
    TEXTUREFORMAT_DEPTH24_STENCIL8,        // Depth 24-bits, Stencil 8-bits
    TEXTUREFORMAT_DEPTH32F_STENCIL8,       // Depth 32-bits (float), Stencil 8-bits
    
    // 48-bits per element
    TEXTUREFORMAT_RGB16F,                  // RGB 16-bits each (float)
    TEXTUREFORMAT_RGB16UI,                 // RGB 16-bits each (unsigned integer)
    TEXTUREFORMAT_RGB16I,                  // RGB 16-bits each (signed integer)
    
    // 64-bits per element
    TEXTUREFORMAT_RG32F,                   // RG 32-bits each (float)
    TEXTUREFORMAT_RG32UI,                  // RG 32-bits each (unsigned integer)
    TEXTUREFORMAT_RG32I,                   // RG 32-bits each (signed integer)
    TEXTUREFORMAT_RGBA16F,                 // RGBA 16-bits each (float)
    TEXTUREFORMAT_RGBA16UI,                // RGBA 16-bits each (unsigned integer)
    TEXTUREFORMAT_RGBA16I,                 // RGBA 16-bits each (signed integer)
    
    // 96-bits per element
    TEXTUREFORMAT_RGB32F,                  // RGB 32-bits each (float)
    TEXTUREFORMAT_RGB32UI,                 // RGB 32-bits each (unsigned integer)
    TEXTUREFORMAT_RGB32I,                  // RGB 32-bits each (signed integer)
    
    // 128-bits per element
    TEXTUREFORMAT_RGBA32F,                 // RGBA 32-bits each (float)
    TEXTUREFORMAT_RGBA32UI,                // RGBA 32-bits each (unsigned integer)
    TEXTUREFORMAT_RGBA32I,                 // RGBA 32-bits each (signed integer)
    
    // Compressed formats
    TEXTUREFORMAT_EAC_R11,                 // EAC R11 (compressed)
    TEXTUREFORMAT_EAC_R11_SIGNED,          // EAC R11 (compressed, signed)
    TEXTUREFORMAT_EAC_RG11,                // EAC RG11 (compressed)
    TEXTUREFORMAT_EAC_RG11_SIGNED,         // EAC RG11 (compressed, signed)
    TEXTUREFORMAT_ETC2_RGB8,               // ETC2 RGB8 (compressed)
    TEXTUREFORMAT_ETC2_SRGB8,              // ETC2 RGB8 (compressed, sRGB)
    TEXTUREFORMAT_ETC2_RGB8_A1,            // ETC2 RGB8A1 (compressed)
    TEXTUREFORMAT_ETC2_SRGB8_A1,           // ETC2 RGB8A1 (compressed, sRGB)
    TEXTUREFORMAT_ETC2_EAC_RGBA8,          // ETC2 RGBA8 (compressed)
    TEXTUREFORMAT_ETC2_EAC_SRGBA8,         // ETC2 RGBA8 (compressed, sRGB)
    
    // DXT formats
    TEXTUREFORMAT_DXT1_RGB,                // DXT1 RGB (compressed)
    TEXTUREFORMAT_DXT1_RGBA,               // DXT1 RGBA (compressed)
    TEXTUREFORMAT_DXT3_RGBA,               // DXT3 RGBA (compressed)
    TEXTUREFORMAT_DXT5_RGBA,               // DXT5 RGBA (compressed)
    TEXTUREFORMAT_DXT1_SRGB,               // DXT1 sRGB (compressed)
    TEXTUREFORMAT_DXT1_SRGBA,              // DXT1 sRGBA (compressed)
    TEXTUREFORMAT_DXT3_SRGBA,              // DXT3 sRGBA (compressed)
    TEXTUREFORMAT_DXT5_SRGBA,              // DXT5 sRGBA (compressed)
    
    // ASTC formats
    TEXTUREFORMAT_RGBA_ASTC_4x4,           // ASTC 4x4 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_5x4,           // ASTC 5x4 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_5x5,           // ASTC 5x5 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_6x5,           // ASTC 6x5 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_6x6,           // ASTC 6x6 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_8x5,           // ASTC 8x5 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_8x6,           // ASTC 8x6 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_8x8,           // ASTC 8x8 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_10x5,          // ASTC 10x5 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_10x6,          // ASTC 10x6 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_10x8,          // ASTC 10x8 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_10x10,         // ASTC 10x10 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_12x10,         // ASTC 12x10 RGBA (compressed)
    TEXTUREFORMAT_RGBA_ASTC_12x12,         // ASTC 12x12 RGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_4x4,   // ASTC 4x4 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x4,   // ASTC 5x4 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x5,   // ASTC 5x5 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x5,   // ASTC 6x5 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x6,   // ASTC 6x6 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x5,   // ASTC 8x5 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x6,   // ASTC 8x6 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x8,   // ASTC 8x8 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x5,  // ASTC 10x5 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x6,  // ASTC 10x6 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x8,  // ASTC 10x8 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x10, // ASTC 10x10 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x10, // ASTC 12x10 sRGBA (compressed)
    TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x12, // ASTC 12x12 sRGBA (compressed)
    
    // RGTC formats
    TEXTUREFORMAT_RED_RGTC1,               // BC4 unsigned
    TEXTUREFORMAT_SIGNED_RED_RGTC1,        // BC4 signed
    TEXTUREFORMAT_RED_GREEN_RGTC2,         // BC5 unsigned
    TEXTUREFORMAT_SIGNED_RED_GREEN_RGTC2,  // BC5 signed
    
    // BPTC formats
    TEXTUREFORMAT_RGB_BPTC_SIGNED_FLOAT,   // BC6H signed
    TEXTUREFORMAT_RGB_BPTC_UNSIGNED_FLOAT, // BC6H unsigned
    TEXTUREFORMAT_RGBA_BPTC_UNORM,         // BC7
    TEXTUREFORMAT_SRGB_ALPHA_BPTC_UNORM    // BC7 sRGB
};
typedef enum TTextureFormat TTextureFormat;

//! Pixel Data Format
enum TPixelDataFormat {
    PIXELDATAFORMAT_R,                  //!< One Red channel, float
    PIXELDATAFORMAT_R_INTEGER,          //!< One Red channel, integer
    PIXELDATAFORMAT_RG,                 //!< Two Red and Green channels, float
    PIXELDATAFORMAT_RG_INTEGER,         //!< Two Red and Green channels, integer
    PIXELDATAFORMAT_RGB,                //!< Three Red, Green and Blue channels, float
    PIXELDATAFORMAT_RGB_INTEGER,        //!< Three Red, Green and Blue channels, integer
    PIXELDATAFORMAT_RGBA,               //!< Four Red, Green, Blue and Alpha channels, float
    PIXELDATAFORMAT_RGBA_INTEGER,       //!< Four Red, Green, Blue and Alpha channels, integer
    PIXELDATAFORMAT_UNUSED,             // used to be rgbm
    PIXELDATAFORMAT_DEPTH_COMPONENT,    //!< Depth, 16-bit or 24-bits usually
    PIXELDATAFORMAT_DEPTH_STENCIL,      //!< Two Depth (24-bits) + Stencil (8-bits) channels
    PIXELDATAFORMAT_ALPHA               //! One Alpha channel, float
};
typedef enum TPixelDataFormat TPixelDataFormat;

enum TPixelDataType {
    PIXELDATATYPE_UBYTE,                //!< unsigned byte
    PIXELDATATYPE_BYTE,                 //!< signed byte
    PIXELDATATYPE_USHORT,               //!< unsigned short (16-bit)
    PIXELDATATYPE_SHORT,                //!< signed short (16-bit)
    PIXELDATATYPE_UINT,                 //!< unsigned int (32-bit)
    PIXELDATATYPE_INT,                  //!< signed int (32-bit)
    PIXELDATATYPE_HALF,                 //!< half-float (16-bit float)
    PIXELDATATYPE_FLOAT,                //!< float (32-bits float)
    PIXELDATATYPE_COMPRESSED,           //!< compressed pixels, @see CompressedPixelDataType
    PIXELDATATYPE_UINT_10F_11F_11F_REV, //!< three low precision floating-point numbers
    PIXELDATATYPE_USHORT_565,           //!< unsigned int (16-bit), encodes 3 RGB channels
    PIXELDATATYPE_UINT_2_10_10_10_REV,  //!< unsigned normalized 10 bits RGB, 2 bits alpha
};
typedef enum TPixelDataType TPixelDataType;

enum TTextureUsage {
    TEXTURE_USAGE_NONE                = 0x0000,
    TEXTURE_USAGE_COLOR_ATTACHMENT    = 0x0001,            //!< Texture can be used as a color attachment
    TEXTURE_USAGE_DEPTH_ATTACHMENT    = 0x0002,            //!< Texture can be used as a depth attachment
    TEXTURE_USAGE_STENCIL_ATTACHMENT  = 0x0004,            //!< Texture can be used as a stencil attachment
    TEXTURE_USAGE_UPLOADABLE          = 0x0008,            //!< Data can be uploaded into this texture (default)
    TEXTURE_USAGE_SAMPLEABLE          = 0x0010,            //!< Texture can be sampled (default)
    TEXTURE_USAGE_SUBPASS_INPUT       = 0x0020,            //!< Texture can be used as a subpass input
    TEXTURE_USAGE_BLIT_SRC            = 0x0040,            //!< Texture can be used the source of a blit()
    TEXTURE_USAGE_BLIT_DST            = 0x0080,            //!< Texture can be used the destination of a blit()
    TEXTURE_USAGE_PROTECTED           = 0x0100,            //!< Texture can be used the destination of a blit()
    TEXTURE_USAGE_DEFAULT             = TEXTURE_USAGE_UPLOADABLE | TEXTURE_USAGE_SAMPLEABLE   //!< Default texture usage
};
typedef enum TTextureUsage TTextureUsage;

EMSCRIPTEN_KEEPALIVE TTexture *Texture_build(TEngine *engine, 
    uint32_t width, 
    uint32_t height, 
    uint32_t depth, 
    uint8_t levels, 
    uint16_t tUsage,
    intptr_t import,
    TTextureSamplerType sampler, 
    TTextureFormat format);
EMSCRIPTEN_KEEPALIVE size_t Texture_getLevels(TTexture *tTexture);
EMSCRIPTEN_KEEPALIVE bool Texture_loadImage(
    TEngine *tEngine,
    TTexture *tTexture,
    TLinearImage *tImage,
    TPixelDataFormat bufferFormat,
    TPixelDataType pixelDataType,
    int level
);
EMSCRIPTEN_KEEPALIVE bool Texture_setImage(
    TEngine *tEngine,
    TTexture *tTexture,
    uint32_t level,
    uint8_t *data,
    size_t size,
    uint32_t width,
    uint32_t height,
    uint32_t channels,
    uint32_t bufferFormat,
    uint32_t pixelDataType
);
EMSCRIPTEN_KEEPALIVE bool Texture_setImageWithDepth(
    TEngine *tEngine,
    TTexture *tTexture,
    uint32_t level,
    uint8_t *data,
    size_t size,
    uint32_t x_offset,
    uint32_t y_offset,
    uint32_t z_offset,
    uint32_t width,
    uint32_t height,
    uint32_t channels,
    uint32_t depth,
    uint32_t bufferFormat,
    uint32_t pixelDataType
);
EMSCRIPTEN_KEEPALIVE uint32_t Texture_getWidth(TTexture *tTexture, uint32_t level);
EMSCRIPTEN_KEEPALIVE uint32_t Texture_getHeight(TTexture *tTexture, uint32_t level);
EMSCRIPTEN_KEEPALIVE uint32_t Texture_getDepth(TTexture *tTexture, uint32_t level);
EMSCRIPTEN_KEEPALIVE TTextureUsage Texture_getUsage(TTexture *tTexture, uint32_t level);
EMSCRIPTEN_KEEPALIVE void Texture_generateMipMaps(TTexture *tTexture, TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE TKtx1Bundle* Ktx1Bundle_create(
    uint8_t *ktxData,
    size_t length
);
EMSCRIPTEN_KEEPALIVE void Ktx1Bundle_getSphericalHarmonics(
    TKtx1Bundle *tBundle,
    float *harmonics
);
EMSCRIPTEN_KEEPALIVE bool Ktx1Bundle_isCubemap(
    TKtx1Bundle *tBundle
);
EMSCRIPTEN_KEEPALIVE void Ktx1Bundle_destroy(
    TKtx1Bundle *tBundle
);

EMSCRIPTEN_KEEPALIVE TTexture* Ktx1Reader_createTexture(
    TEngine *tEngine,
    TKtx1Bundle *tBundle,
    uint32_t requestId,
    VoidCallback onTextureUploadComplete
);
EMSCRIPTEN_KEEPALIVE TLinearImage *Image_createEmpty(uint32_t width,uint32_t height,uint32_t channel);
EMSCRIPTEN_KEEPALIVE TLinearImage *Image_decode(uint8_t* data, size_t length, const char* name, bool alpha);
EMSCRIPTEN_KEEPALIVE float *Image_getBytes(TLinearImage *tLinearImage);
EMSCRIPTEN_KEEPALIVE void Image_destroy(TLinearImage *tLinearImage);
EMSCRIPTEN_KEEPALIVE uint32_t Image_getWidth(TLinearImage *tLinearImage);
EMSCRIPTEN_KEEPALIVE uint32_t Image_getHeight(TLinearImage *tLinearImage);
EMSCRIPTEN_KEEPALIVE uint32_t Image_getChannels(TLinearImage *tLinearImage);
EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getColorTexture(TRenderTarget *tRenderTarget);
EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getDepthTexture(TRenderTarget *tRenderTarget);

// Texture Sampler related enums
enum TSamplerWrapMode {
    WRAP_CLAMP_TO_EDGE,       // Clamp to edge wrapping mode
    WRAP_REPEAT,              // Repeat wrapping mode
    WRAP_MIRRORED_REPEAT      // Mirrored repeat wrapping mode
};
typedef enum TSamplerWrapMode TSamplerWrapMode;

enum TSamplerMinFilter {
    FILTER_NEAREST,                  // Nearest filtering
    FILTER_LINEAR,                   // Linear filtering
    FILTER_NEAREST_MIPMAP_NEAREST,   // Nearest mipmap nearest filtering
    FILTER_LINEAR_MIPMAP_NEAREST,    // Linear mipmap nearest filtering
    FILTER_NEAREST_MIPMAP_LINEAR,    // Nearest mipmap linear filtering
    FILTER_LINEAR_MIPMAP_LINEAR      // Linear mipmap linear filtering
};
typedef enum TSamplerMinFilter TSamplerMinFilter;

enum TSamplerMagFilter {
    MAG_FILTER_NEAREST,              // Nearest filtering
    MAG_FILTER_LINEAR                // Linear filtering
};
typedef enum TSamplerMagFilter TSamplerMagFilter;

enum TSamplerCompareMode {
    COMPARE_MODE_NONE,               // No comparison
    COMPARE_MODE_COMPARE_TO_TEXTURE  // Compare to texture
};
typedef enum TSamplerCompareMode TSamplerCompareMode;

typedef TSamplerCompareFunc TTextureSamplerCompareFunc ;

EMSCRIPTEN_KEEPALIVE TTextureSampler* TextureSampler_create();
EMSCRIPTEN_KEEPALIVE TTextureSampler* TextureSampler_createWithFiltering(
    TSamplerMinFilter minFilter, 
    TSamplerMagFilter magFilter, 
    TSamplerWrapMode wrapS, 
    TSamplerWrapMode wrapT, 
    TSamplerWrapMode wrapR
);
EMSCRIPTEN_KEEPALIVE TTextureSampler* TextureSampler_createWithComparison(
    TSamplerCompareMode compareMode, 
    TSamplerCompareFunc compareFunc);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilter(
    TTextureSampler* sampler, 
    TSamplerMinFilter filter);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilter(
    TTextureSampler* sampler, 
    TSamplerMagFilter filter);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeS(
    TTextureSampler* sampler, 
    TSamplerWrapMode mode);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeT(
    TTextureSampler* sampler, 
    TSamplerWrapMode mode);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeR(
    TTextureSampler* sampler, 
    TSamplerWrapMode mode);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropy(
    TTextureSampler* sampler, 
    double anisotropy);
EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareMode(
    TTextureSampler* sampler, 
    TSamplerCompareMode mode, 
    TTextureSamplerCompareFunc func);

EMSCRIPTEN_KEEPALIVE void TextureSampler_destroy(TTextureSampler* sampler);
    

#ifdef __cplusplus
}
#endif

#endif // _T_TEXTURE_H