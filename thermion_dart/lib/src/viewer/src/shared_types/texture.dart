import 'dart:typed_data';

import 'package:thermion_dart/thermion_dart.dart';

/// Defines the type of sampler to use with a texture
enum TextureSamplerType {
  /// 2D texture
  SAMPLER_2D,

  /// Cubemap texture
  SAMPLER_CUBEMAP,

  /// External texture (video/camera)
  SAMPLER_EXTERNAL,

  /// 3D texture
  SAMPLER_3D,

  /// 2D array texture
  SAMPLER_2D_ARRAY
}

/// Defines internal texture formats
enum TextureFormat {
  // 8-bits per element
  R8, // R 8-bits
  R8_SNORM, // R 8-bits (signed normalized)
  R8UI, // R 8-bits (unsigned integer)
  R8I, // R 8-bits (signed integer)
  STENCIL8, // Stencil 8-bits

  // 16-bits per element
  R16F, // R 16-bits (float)
  R16UI, // R 16-bits (unsigned integer)
  R16I, // R 16-bits (signed integer)
  RG8, // RG 8-bits each
  RG8_SNORM, // RG 8-bits each (signed normalized)
  RG8UI, // RG 8-bits each (unsigned integer)
  RG8I, // RG 8-bits each (signed integer)
  RGB565, // RGB 5-6-5 bits
  RGB9_E5, // RGB9_E5 format
  RGB5_A1, // RGB 5 bits each, A 1 bit
  RGBA4, // RGBA 4 bits each
  DEPTH16, // Depth 16-bits

  // 24-bits per element
  RGB8, // RGB 8-bits each
  SRGB8, // RGB 8-bits each (sRGB color space)
  RGB8_SNORM, // RGB 8-bits each (signed normalized)
  RGB8UI, // RGB 8-bits each (unsigned integer)
  RGB8I, // RGB 8-bits each (signed integer)
  DEPTH24, // Depth 24-bits

  // 32-bits per element
  R32F, // R 32-bits (float)
  R32UI, // R 32-bits (unsigned integer)
  R32I, // R 32-bits (signed integer)
  RG16F, // RG 16-bits each (float)
  RG16UI, // RG 16-bits each (unsigned integer)
  RG16I, // RG 16-bits each (signed integer)
  R11F_G11F_B10F, // R11F_G11F_B10F format
  RGBA8, // RGBA 8-bits each
  SRGB8_A8, // RGB 8-bits each (sRGB), A 8-bits
  RGBA8_SNORM, // RGBA 8-bits each (signed normalized)
  UNUSED, // used to be rgbm
  RGB10_A2, // RGB 10-bits each, A 2-bits
  RGBA8UI, // RGBA 8-bits each (unsigned integer)
  RGBA8I, // RGBA 8-bits each (signed integer)
  DEPTH32F, // Depth 32-bits (float)
  DEPTH24_STENCIL8, // Depth 24-bits, Stencil 8-bits
  DEPTH32F_STENCIL8, // Depth 32-bits (float), Stencil 8-bits

  // 48-bits per element
  RGB16F, // RGB 16-bits each (float)
  RGB16UI, // RGB 16-bits each (unsigned integer)
  RGB16I, // RGB 16-bits each (signed integer)

  // 64-bits per element
  RG32F, // RG 32-bits each (float)
  RG32UI, // RG 32-bits each (unsigned integer)
  RG32I, // RG 32-bits each (signed integer)
  RGBA16F, // RGBA 16-bits each (float)
  RGBA16UI, // RGBA 16-bits each (unsigned integer)
  RGBA16I, // RGBA 16-bits each (signed integer)

  // 96-bits per element
  RGB32F, // RGB 32-bits each (float)
  RGB32UI, // RGB 32-bits each (unsigned integer)
  RGB32I, // RGB 32-bits each (signed integer)

  // 128-bits per element
  RGBA32F, // RGBA 32-bits each (float)
  RGBA32UI, // RGBA 32-bits each (unsigned integer)
  RGBA32I, // RGBA 32-bits each (signed integer)

  // Compressed formats
  EAC_R11, // EAC R11 (compressed)
  EAC_R11_SIGNED, // EAC R11 (compressed, signed)
  EAC_RG11, // EAC RG11 (compressed)
  EAC_RG11_SIGNED, // EAC RG11 (compressed, signed)
  ETC2_RGB8, // ETC2 RGB8 (compressed)
  ETC2_SRGB8, // ETC2 RGB8 (compressed, sRGB)
  ETC2_RGB8_A1, // ETC2 RGB8A1 (compressed)
  ETC2_SRGB8_A1, // ETC2 RGB8A1 (compressed, sRGB)
  ETC2_EAC_RGBA8, // ETC2 RGBA8 (compressed)
  ETC2_EAC_SRGBA8, // ETC2 RGBA8 (compressed, sRGB)

  // DXT formats
  DXT1_RGB, // DXT1 RGB (compressed)
  DXT1_RGBA, // DXT1 RGBA (compressed)
  DXT3_RGBA, // DXT3 RGBA (compressed)
  DXT5_RGBA, // DXT5 RGBA (compressed)
  DXT1_SRGB, // DXT1 sRGB (compressed)
  DXT1_SRGBA, // DXT1 sRGBA (compressed)
  DXT3_SRGBA, // DXT3 sRGBA (compressed)
  DXT5_SRGBA, // DXT5 sRGBA (compressed)

  // ASTC formats
  RGBA_ASTC_4x4, // ASTC 4x4 RGBA (compressed)
  RGBA_ASTC_5x4, // ASTC 5x4 RGBA (compressed)
  RGBA_ASTC_5x5, // ASTC 5x5 RGBA (compressed)
  RGBA_ASTC_6x5, // ASTC 6x5 RGBA (compressed)
  RGBA_ASTC_6x6, // ASTC 6x6 RGBA (compressed)
  RGBA_ASTC_8x5, // ASTC 8x5 RGBA (compressed)
  RGBA_ASTC_8x6, // ASTC 8x6 RGBA (compressed)
  RGBA_ASTC_8x8, // ASTC 8x8 RGBA (compressed)
  RGBA_ASTC_10x5, // ASTC 10x5 RGBA (compressed)
  RGBA_ASTC_10x6, // ASTC 10x6 RGBA (compressed)
  RGBA_ASTC_10x8, // ASTC 10x8 RGBA (compressed)
  RGBA_ASTC_10x10, // ASTC 10x10 RGBA (compressed)
  RGBA_ASTC_12x10, // ASTC 12x10 RGBA (compressed)
  RGBA_ASTC_12x12, // ASTC 12x12 RGBA (compressed)
  SRGB8_ALPHA8_ASTC_4x4, // ASTC 4x4 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_5x4, // ASTC 5x4 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_5x5, // ASTC 5x5 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_6x5, // ASTC 6x5 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_6x6, // ASTC 6x6 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_8x5, // ASTC 8x5 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_8x6, // ASTC 8x6 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_8x8, // ASTC 8x8 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_10x5, // ASTC 10x5 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_10x6, // ASTC 10x6 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_10x8, // ASTC 10x8 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_10x10, // ASTC 10x10 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_12x10, // ASTC 12x10 sRGBA (compressed)
  SRGB8_ALPHA8_ASTC_12x12, // ASTC 12x12 sRGBA (compressed)

  // RGTC formats
  RED_RGTC1, // BC4 unsigned
  SIGNED_RED_RGTC1, // BC4 signed
  RED_GREEN_RGTC2, // BC5 unsigned
  SIGNED_RED_GREEN_RGTC2, // BC5 signed

  // BPTC formats
  RGB_BPTC_SIGNED_FLOAT, // BC6H signed
  RGB_BPTC_UNSIGNED_FLOAT, // BC6H unsigned
  RGBA_BPTC_UNORM, // BC7
  SRGB_ALPHA_BPTC_UNORM, // BC7 sRGB
}

/// Defines texture usage flags that affect memory allocation
enum TextureUsage {
  /// Default texture usage, optimized for general use
  DEFAULT,

  /// Optimized for textures that will be used as color attachments
  COLOR_ATTACHMENT,

  /// Optimized for textures that will be used as depth attachments
  DEPTH_ATTACHMENT,

  /// Optimized for textures that will be sampled from shaders
  SAMPLEABLE
}

/// Defines texture filter types for magnification and minification
enum TextureFilter {
  /// Nearest neighbor sampling (pixelated look)
  NEAREST,

  /// Linear interpolation between texels
  LINEAR,

  /// Nearest neighbor filtering but uses mipmaps for minification
  NEAREST_MIPMAP_NEAREST,

  /// Linear filtering and uses nearest mipmap level
  LINEAR_MIPMAP_NEAREST,

  /// Nearest filtering but linearly interpolates between mipmap levels
  NEAREST_MIPMAP_LINEAR,

  /// Linear filtering and linear interpolation between mipmap levels (best quality)
  LINEAR_MIPMAP_LINEAR
}

/// Defines texture wrapping modes for when texture coordinates exceed [0,1]
enum TextureWrapMode {
  /// Repeats the texture (tiles)
  REPEAT,

  /// Mirrors the texture at each repeat
  MIRRORED_REPEAT,

  /// Clamps texture coordinates to edge, extending edge pixels
  CLAMP_TO_EDGE,

  /// Clamps to border color (usually transparent or black)
  CLAMP_TO_BORDER
}

/// Defines swizzle operations for texture components
enum TextureSwizzle {
  /// Use the component as is
  CHANNEL_0,

  /// Use the red channel
  CHANNEL_R,

  /// Use the green channel
  CHANNEL_G,

  /// Use the blue channel
  CHANNEL_B,

  /// Use the alpha channel
  CHANNEL_A,

  /// Use value 0
  ZERO,

  /// Use value 1
  ONE
}

/// Defines the texture sampler configuration
abstract class TextureSampler {
  /// Creates a new texture sampler with specified filtering and wrapping modes
  Future<TextureSampler> create(TextureFilter minFilter,
      TextureFilter magFilter, TextureWrapMode wrapS, TextureWrapMode wrapT,
      [TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE]);

  /// Creates a texture sampler with comparison mode for shadow mapping
  Future<TextureSampler> createComparisonSampler(
      TextureFilter minFilter,
      TextureFilter magFilter,
      TextureWrapMode wrapS,
      TextureWrapMode wrapT,
      SamplerCompareFunction compareMode,
      [TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE]);

  /// Disposes the sampler resources
  Future dispose();
}

/// Defines a texture object
abstract class Texture {
  /// Returns the width of the texture at the specified mipmap level
  Future<int> getWidth([int level = 0]);

  /// Returns the height of the texture at the specified mipmap level
  Future<int> getHeight([int level = 0]);

  /// Returns the depth of the texture at the specified mipmap level (for 3D textures)
  Future<int> getDepth([int level = 0]);

  /// Returns the number of mipmap levels this texture has
  Future<int> getLevels();

  /// Returns the sampler type of this texture
  Future<TextureSamplerType> getTarget();

  /// Returns the internal format of this texture
  Future<TextureFormat> getFormat();

  Future setLinearImage(covariant LinearImage image, PixelDataFormat format, PixelDataType type);

  /// Sets the image data for a 2D texture or a texture level
  Future setImage(
      int level, Uint8List buffer, PixelDataFormat format, PixelDataType type);

  /// Sets the image data for a region of a 2D texture
  Future setSubImage(int level, int xOffset, int yOffset, int width, int height,
      Uint8List buffer, PixelDataFormat format, PixelDataType type);

  /// Sets the image data for a 3D texture or cubemap
  Future setImage3D(
      int level,
      int xOffset,
      int yOffset,
      int zOffset,
      int width,
      int height,
      int depth,
      Uint8List buffer,
      PixelDataFormat format,
      PixelDataType type);

  /// Sets an external image (like a video or camera frame) as the texture source
  Future setExternalImage(dynamic externalImage);

  /// Generates mipmaps automatically for the texture
  Future generateMipmaps();

  /// Disposes the texture resources
  Future dispose();
}

enum PixelDataFormat {
  R,                 /// One Red channel, float
  R_INTEGER,         /// One Red channel, integer
  RG,                /// Two Red and Green channels, float
  RG_INTEGER,        /// Two Red and Green channels, integer
  RGB,               /// Three Red, Green and Blue channels, float
  RGB_INTEGER,       /// Three Red, Green and Blue channels, integer
  RGBA,              /// Four Red, Green, Blue and Alpha channels, float
  RGBA_INTEGER,      /// Four Red, Green, Blue and Alpha channels, integer
  UNUSED,            /// Used to be rgbm
  DEPTH_COMPONENT,   /// Depth, 16-bit or 24-bits usually
  DEPTH_STENCIL,     /// Two Depth (24-bits) + Stencil (8-bits) channels
  ALPHA              /// One Alpha channel, float
}

/// Pixel Data Type
enum PixelDataType {
  UBYTE,                /// Unsigned byte
  BYTE,                 /// Signed byte
  USHORT,               /// Unsigned short (16-bit)
  SHORT,                /// Signed short (16-bit)
  UINT,                 /// Unsigned int (32-bit)
  INT,                  /// Signed int (32-bit)
  HALF,                 /// Half-float (16-bit float)
  FLOAT,                /// Float (32-bits float)
  COMPRESSED,           /// Compressed pixels, see CompressedPixelDataType
  UINT_10F_11F_11F_REV, /// Three low precision floating-point numbers
  USHORT_565,           /// Unsigned int (16-bit), encodes 3 RGB channels
  UINT_2_10_10_10_REV,  /// Unsigned normalized 10 bits RGB, 2 bits alpha
}

@deprecated
typedef ThermionTexture = Texture;

abstract class LinearImage {
  Future destroy();
  Future<int> getWidth();
  Future<int> getHeight();
  Future<int> getChannels();
}
