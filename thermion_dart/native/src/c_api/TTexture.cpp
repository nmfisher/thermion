

#include <chrono>
#include <vector>

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <backend/DriverEnums.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>
#include <image/LinearImage.h>
#include <image/ColorTransform.h>
#include <backend/DriverEnums.h>

#include <ktxreader/Ktx1Reader.h>
#include <ktxreader/Ktx2Reader.h>

#include "c_api/TTexture.h"

#include "Log.hpp"

#include <third_party/stb/stb_image.h>

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament::backend;
        using namespace image;

#endif

        inline float to_float(uint8_t v)
        {
            return float(v);
        }

        EMSCRIPTEN_KEEPALIVE TLinearImage *Image_decode(uint8_t *data, size_t length, const char *name = "image", bool alpha = true)
        {

            auto start = std::chrono::high_resolution_clock::now();

            int width, height, channels;

            TRACE("Loading image from buffer of length %lu bytes (alpha : %s)", length, alpha ? "true" : "false");

            uint8_t *imgData = stbi_load_from_memory(data, length, &width, &height, &channels, alpha ? 4 : 3);

            if (!imgData)
            {
                ERROR("Failed to decode image");
                return nullptr;
            }

            LinearImage *linearImage;

            if (alpha)
            {
                linearImage = new LinearImage(toLinearWithAlpha<uint8_t>(
                    width,
                    height,
                    width * 4,
                    imgData,
                    to_float, sRGBToLinear<filament::math::float4>));
            }
            else
            {
                linearImage = new LinearImage(toLinear<uint8_t>(
                    width,
                    height,
                    width * 3,
                    imgData,
                    to_float, sRGBToLinear<filament::math::float3>));
            }

            // stbi_load_from_memory returns a malloc'd buffer we own. The
            // LinearImage above copied/converted from it; release the
            // intermediate before returning so it doesn't leak per decode
            // (significant on repeated PNG decodes — see web heap-diag).
            stbi_image_free(imgData);

            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

            TRACE("Image decoded successfully in %lld ms (%dx%dx%d)", duration.count(), width, height, channels);

            if (!linearImage->isValid())
            {
                Log("Failed to decode image.");
                delete linearImage;
                return nullptr;
            }

            return reinterpret_cast<TLinearImage *>(linearImage);
        }

        EMSCRIPTEN_KEEPALIVE TKtx1Bundle *Ktx1Bundle_create(uint8_t *ktxData, size_t length)
        {
            auto *bundle = new image::Ktx1Bundle(ktxData, static_cast<uint32_t>(length));
            return reinterpret_cast<TKtx1Bundle *>(bundle);
        }

        EMSCRIPTEN_KEEPALIVE bool Ktx1Bundle_isCubemap(TKtx1Bundle *tBundle)
        {
            auto *bundle = reinterpret_cast<image::Ktx1Bundle *>(tBundle);
            return bundle->isCubemap();
        }

        EMSCRIPTEN_KEEPALIVE void Ktx1Bundle_destroy(
            TKtx1Bundle *tBundle)
        {
            auto *bundle = reinterpret_cast<image::Ktx1Bundle *>(tBundle);
            delete bundle;
        }

        EMSCRIPTEN_KEEPALIVE void Ktx1Bundle_getSphericalHarmonics(TKtx1Bundle *tBundle, float *sphericalHarmonics)
        {
            auto *bundle = reinterpret_cast<image::Ktx1Bundle *>(tBundle);
            filament::math::float3 harmonics[9];
            if (sphericalHarmonics)
            {
                bundle->getSphericalHarmonics(harmonics);
                memcpy(sphericalHarmonics, harmonics, 27 * sizeof(float));
            }
        }

        // -------------------------------------------------------------------
        // KTX2
        // -------------------------------------------------------------------

        using IF = filament::Texture::InternalFormat;

        // KTX2 container constants (KTX2 spec §3, "File Structure").
        constexpr size_t kKtx2HeaderSize = 80;
        constexpr size_t kKtx2LevelCountOffset = 40;
        constexpr size_t kKtx2SupercompressionOffset = 44;
        constexpr size_t kKtx2DfdByteOffsetOffset = 48;
        constexpr size_t kKtx2DfdByteLengthOffset = 52;
        // Offset, within the DFD, of the word holding
        // colorModel | colorPrimaries | transferFunction | flags.
        // = 4 (dfdTotalSize) + 8 (basic block words 0 and 1).
        constexpr size_t kKtx2DfdColorWordOffset = 12;

        static const uint8_t kKtx2Identifier[12] = {
            0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A};

        struct Ktx2Metadata
        {
            bool valid = false;
            uint32_t levelCount = 0;
            uint32_t supercompressionScheme = 0;
            uint32_t colorModel = 0;
            uint32_t transferFunction = 0; // TKtx2TransferFunction
            uint32_t alphaMode = 0;        // TKtx2AlphaMode
        };

        static inline uint32_t readLe32(const uint8_t *p)
        {
            return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
                   ((uint32_t)p[3] << 24);
        }

        static inline void writeLe32(uint8_t *p, uint32_t v)
        {
            p[0] = (uint8_t)(v & 0xFF);
            p[1] = (uint8_t)((v >> 8) & 0xFF);
            p[2] = (uint8_t)((v >> 16) & 0xFF);
            p[3] = (uint8_t)((v >> 24) & 0xFF);
        }

        // Reads the KTX2 header + Data Format Descriptor.
        //
        // The DFD is the *normative* source of the transfer function: Filament's
        // Ktx2Reader checks the caller's requested transfer function against it and
        // fails the load outright on mismatch (Ktx2Reader.h:85-91). Any manifest- or
        // Dart-side declaration is therefore only ever a cross-check, never an input.
        static Ktx2Metadata parseKtx2Metadata(const uint8_t *data, size_t size)
        {
            Ktx2Metadata md;
            if (!data || size < kKtx2HeaderSize)
            {
                return md;
            }
            if (memcmp(data, kKtx2Identifier, sizeof(kKtx2Identifier)) != 0)
            {
                return md;
            }

            md.levelCount = readLe32(data + kKtx2LevelCountOffset);
            md.supercompressionScheme = readLe32(data + kKtx2SupercompressionOffset);

            const uint32_t dfdOffset = readLe32(data + kKtx2DfdByteOffsetOffset);
            const uint32_t dfdLength = readLe32(data + kKtx2DfdByteLengthOffset);

            if (dfdOffset < kKtx2HeaderSize || dfdLength < kKtx2DfdColorWordOffset + 4)
            {
                return md;
            }
            if ((size_t)dfdOffset + (size_t)dfdLength > size)
            {
                return md;
            }

            const uint32_t colorWord = readLe32(data + dfdOffset + kKtx2DfdColorWordOffset);
            md.colorModel = colorWord & 0xFF;
            md.transferFunction = (colorWord >> 16) & 0xFF;
            const uint32_t flags = (colorWord >> 24) & 0xFF;
            // KHR_DF_FLAG_ALPHA_PREMULTIPLIED == 1
            md.alphaMode = (flags & 1u) ? KTX2_ALPHA_PREMULTIPLIED : KTX2_ALPHA_STRAIGHT;
            md.valid = true;
            return md;
        }

        // Clamps the blob's declared mip level count in place.
        //
        // Ktx2Reader::load builds the texture with `.levels(transcoder->get_levels())`
        // and then transcodes + uploads *every* level, with no knob to stop early. The
        // only lever available from outside Filament is the blob's own header.
        //
        // basisu's ktx2_transcoder::init reads exactly `levelCount` entries from the
        // level index array at offset 80, and locates the DFD/KVD/level payloads solely
        // through the header's absolute byte offsets — it never derives an offset from
        // the level count, and never requires the level index to abut the DFD. Dropping
        // levelCount therefore leaves the now-unreferenced index entries and level
        // payloads as inert padding inside the buffer while remaining a well-formed
        // input. Level 0 is the base (largest) level, so no data movement is needed.
        //
        // Returns the original level count, and writes the clamped count via `outNew`.
        static uint32_t clampKtx2LevelCount(std::vector<uint8_t> &blob, int32_t maxMipLevels,
                                     uint32_t *outNew)
        {
            const uint32_t original =
                blob.size() >= kKtx2HeaderSize ? readLe32(blob.data() + kKtx2LevelCountOffset) : 0;
            *outNew = original;

            if (maxMipLevels <= 0 || original == 0 || original <= (uint32_t)maxMipLevels)
            {
                return original;
            }
            if (blob.size() < kKtx2HeaderSize ||
                memcmp(blob.data(), kKtx2Identifier, sizeof(kKtx2Identifier)) != 0)
            {
                return original;
            }

            const uint32_t clamped = (uint32_t)maxMipLevels;
            writeLe32(blob.data() + kKtx2LevelCountOffset, clamped);
            *outNew = clamped;
            return original;
        }

        static bool isSrgbInternalFormat(IF fmt)
        {
            switch (fmt)
            {
            case IF::SRGB8:
            case IF::SRGB8_A8:
            case IF::ETC2_SRGB8:
            case IF::ETC2_SRGB8_A1:
            case IF::ETC2_EAC_SRGBA8:
            case IF::DXT1_SRGB:
            case IF::DXT1_SRGBA:
            case IF::DXT3_SRGBA:
            case IF::DXT5_SRGBA:
            case IF::SRGB8_ALPHA8_ASTC_4x4:
            case IF::SRGB8_ALPHA8_ASTC_5x4:
            case IF::SRGB8_ALPHA8_ASTC_5x5:
            case IF::SRGB8_ALPHA8_ASTC_6x5:
            case IF::SRGB8_ALPHA8_ASTC_6x6:
            case IF::SRGB8_ALPHA8_ASTC_8x5:
            case IF::SRGB8_ALPHA8_ASTC_8x6:
            case IF::SRGB8_ALPHA8_ASTC_8x8:
            case IF::SRGB8_ALPHA8_ASTC_10x5:
            case IF::SRGB8_ALPHA8_ASTC_10x6:
            case IF::SRGB8_ALPHA8_ASTC_10x8:
            case IF::SRGB8_ALPHA8_ASTC_10x10:
            case IF::SRGB8_ALPHA8_ASTC_12x10:
            case IF::SRGB8_ALPHA8_ASTC_12x12:
            case IF::SRGB_ALPHA_BPTC_UNORM:
                return true;
            default:
                return false;
            }
        }

        static const char *internalFormatName(IF fmt)
        {
            switch (fmt)
            {
            case IF::SRGB8_ALPHA8_ASTC_4x4: return "SRGB8_ALPHA8_ASTC_4x4";
            case IF::RGBA_ASTC_4x4: return "RGBA_ASTC_4x4";
            case IF::SRGB_ALPHA_BPTC_UNORM: return "SRGB_ALPHA_BPTC_UNORM (BC7 sRGB)";
            case IF::RGBA_BPTC_UNORM: return "RGBA_BPTC_UNORM (BC7)";
            case IF::DXT5_SRGBA: return "DXT5_SRGBA (BC3 sRGB)";
            case IF::DXT5_RGBA: return "DXT5_RGBA (BC3)";
            case IF::DXT1_SRGB: return "DXT1_SRGB (BC1 sRGB)";
            case IF::DXT1_RGB: return "DXT1_RGB (BC1)";
            case IF::ETC2_EAC_SRGBA8: return "ETC2_EAC_SRGBA8";
            case IF::ETC2_EAC_RGBA8: return "ETC2_EAC_RGBA8";
            case IF::EAC_R11: return "EAC_R11";
            case IF::EAC_R11_SIGNED: return "EAC_R11_SIGNED";
            case IF::EAC_RG11: return "EAC_RG11";
            case IF::EAC_RG11_SIGNED: return "EAC_RG11_SIGNED";
            case IF::ETC2_RGB8: return "ETC2_RGB8";
            case IF::ETC2_SRGB8: return "ETC2_SRGB8";
            case IF::ETC2_RGB8_A1: return "ETC2_RGB8_A1";
            case IF::ETC2_SRGB8_A1: return "ETC2_SRGB8_A1";
            case IF::RED_RGTC1: return "RED_RGTC1";
            case IF::RED_GREEN_RGTC2: return "RED_GREEN_RGTC2";
            case IF::SRGB8_A8: return "SRGB8_A8";
            case IF::RGBA8: return "RGBA8";
            case IF::RGB565: return "RGB565";
            case IF::RGBA4: return "RGBA4";
            default: return "<other>";
            }
        }

        static const char *transferName(uint32_t transfer)
        {
            switch (transfer)
            {
            case KTX2_TRANSFER_LINEAR: return "LINEAR";
            case KTX2_TRANSFER_SRGB: return "sRGB";
            default: return "UNKNOWN";
            }
        }

        // The requested-format ladder, highest priority first.
        //
        // Ktx2Reader::createTexture filters this list by transfer function, so the sRGB
        // and LINEAR groups never compete; only the order *within* a group matters.
        //
        // sRGB group (new — thermion previously had no sRGB ASTC and no BC/DXT family at
        // all, which is why an sRGB-tagged UASTC albedo resolved to nothing on desktop):
        //   SRGB8_ALPHA8_ASTC_4x4  lossless UASTC -> ASTC transcode
        //   SRGB_ALPHA_BPTC_UNORM  BC7 sRGB, the high-quality desktop target
        //   DXT5_SRGBA             BC3 sRGB, desktop compatibility
        //   ETC2_EAC_SRGBA8        GLES3 mobile fallback
        //   SRGB8_A8               universal correctness fallback (uncompressed)
        //
        // DXT1_SRGBA and DXT3_SRGBA are deliberately absent: they exist as Filament
        // enums at v1.69.1 but are NOT mapped in Ktx2Reader::getFinalFormatInfo, so
        // requesting them can only ever return FORMAT_UNSUPPORTED. DXT1_SRGB is mapped
        // but drops alpha, so it is only valid for a normatively-opaque asset.
        //
        // The LINEAR group is thermion's pre-existing list, order preserved, so that
        // linear-tagged blobs (e.g. the producer's normal maps) resolve exactly as they
        // did before this change.
        static const IF kSrgbLadder[] = {
            IF::SRGB8_ALPHA8_ASTC_4x4,
            IF::SRGB_ALPHA_BPTC_UNORM,
            IF::DXT5_SRGBA,
            IF::ETC2_EAC_SRGBA8,
            IF::SRGB8_A8,
        };

        static const IF kLinearLadder[] = {
            IF::RGBA_ASTC_4x4,
            IF::EAC_R11,
            IF::EAC_R11_SIGNED,
            IF::EAC_RG11,
            IF::EAC_RG11_SIGNED,
            IF::ETC2_RGB8,
            IF::ETC2_SRGB8,
            IF::ETC2_RGB8_A1,
            IF::ETC2_SRGB8_A1,
            IF::ETC2_EAC_RGBA8,
            IF::RGBA8,
        };

        static void requestLadder(ktxreader::Ktx2Reader *reader, const IF *ladder, size_t count)
        {
            for (size_t i = 0; i < count; i++)
            {
                auto result = reader->requestFormat(ladder[i]);
                Log("KTX2 requestFormat %-24s Result : %d", internalFormatName(ladder[i]),
                    (int)result);
            }
        }

        struct Ktx2LoadResultImpl
        {
            filament::Texture *texture = nullptr;
            int32_t sourceTransfer = KTX2_TRANSFER_UNKNOWN;
            int32_t resolvedFormat = -1;
            int32_t hardwareSrgbDecode = 0;
            int32_t alphaMode = KTX2_ALPHA_UNKNOWN;
            int32_t uploadedMipCount = 0;
            int32_t sourceMipCount = 0;
        };

        EMSCRIPTEN_KEEPALIVE TKtx2LoadResult *Ktx2Reader_createTexture(
            TEngine *tEngine, uint8_t *data, size_t size, int32_t transferFunction,
            int32_t maxMipLevels)
        {
            auto *out = new Ktx2LoadResultImpl();

            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);

            const Ktx2Metadata md = parseKtx2Metadata(data, size);
            out->sourceTransfer = (int32_t)md.transferFunction;
            out->alphaMode = (int32_t)md.alphaMode;
            out->sourceMipCount = (int32_t)md.levelCount;

            if (!md.valid)
            {
                Log("KTX2 WARNING: could not parse the KTX2 header/DFD (%zu bytes); falling back "
                    "to the legacy sRGB-then-LINEAR probe.",
                    size);
            }

            // The caller may pin the transfer function, but the DFD wins when it is
            // readable — Filament treats the blob's own tag as binding.
            uint32_t requestedTransfer = md.valid ? md.transferFunction : KTX2_TRANSFER_UNKNOWN;
            if (transferFunction == KTX2_TRANSFER_LINEAR || transferFunction == KTX2_TRANSFER_SRGB)
            {
                if (md.valid && (uint32_t)transferFunction != md.transferFunction)
                {
                    Log("KTX2 WARNING: caller requested transfer %s but the blob's DFD declares "
                        "%s; the DFD wins.",
                        transferName((uint32_t)transferFunction), transferName(md.transferFunction));
                }
                else if (!md.valid)
                {
                    requestedTransfer = (uint32_t)transferFunction;
                }
            }

            std::vector<uint8_t> copy(data, data + size);
            uint32_t clampedLevels = md.levelCount;
            const uint32_t originalLevels = clampKtx2LevelCount(copy, maxMipLevels, &clampedLevels);
            if (clampedLevels != originalLevels)
            {
                Log("KTX2 mip clamp : source declares %u level(s), consuming %u", originalLevels,
                    clampedLevels);
            }

            auto *reader = new ktxreader::Ktx2Reader(*engine);

            filament::Texture *texture = nullptr;

            if (requestedTransfer == KTX2_TRANSFER_SRGB)
            {
                requestLadder(reader, kSrgbLadder, sizeof(kSrgbLadder) / sizeof(kSrgbLadder[0]));
                Log("Finished requesting KTX2 formats (sRGB), loading KTX2 data of length %zu bytes",
                    size);
                texture = reader->load(copy.data(), copy.size(),
                                       ktxreader::Ktx2Reader::TransferFunction::sRGB);
                if (!texture)
                {
                    Log("Failed to load with sRGB transfer function");
                }
            }
            else if (requestedTransfer == KTX2_TRANSFER_LINEAR)
            {
                requestLadder(reader, kLinearLadder,
                              sizeof(kLinearLadder) / sizeof(kLinearLadder[0]));
                Log("Finished requesting KTX2 formats (LINEAR), loading KTX2 data of length %zu "
                    "bytes",
                    size);
                texture = reader->load(copy.data(), copy.size(),
                                       ktxreader::Ktx2Reader::TransferFunction::LINEAR);
                if (!texture)
                {
                    Log("Failed to load with LINEAR transfer function");
                }
            }
            else
            {
                // Unreadable DFD: fall back to the legacy behaviour of probing both legs.
                requestLadder(reader, kSrgbLadder, sizeof(kSrgbLadder) / sizeof(kSrgbLadder[0]));
                requestLadder(reader, kLinearLadder,
                              sizeof(kLinearLadder) / sizeof(kLinearLadder[0]));
                Log("Finished requesting KTX2 formats (UNKNOWN transfer), loading KTX2 data of "
                    "length %zu bytes",
                    size);
                texture = reader->load(copy.data(), copy.size(),
                                       ktxreader::Ktx2Reader::TransferFunction::sRGB);
                if (!texture)
                {
                    Log("Failed to load with sRGB transfer function");
                    texture = reader->load(copy.data(), copy.size(),
                                           ktxreader::Ktx2Reader::TransferFunction::LINEAR);
                    if (!texture)
                    {
                        Log("Failed to load with LINEAR transfer function");
                    }
                    else
                    {
                        out->sourceTransfer = KTX2_TRANSFER_LINEAR;
                    }
                }
                else
                {
                    out->sourceTransfer = KTX2_TRANSFER_SRGB;
                }
            }

            delete reader;

            out->texture = texture;

            if (texture)
            {
                const IF resolved = texture->getFormat();
                out->resolvedFormat = (int32_t)resolved;
                out->hardwareSrgbDecode = isSrgbInternalFormat(resolved) ? 1 : 0;
                out->uploadedMipCount = (int32_t)texture->getLevels();
                Log("KTX2 RESOLVED : format=%s (%d) source=%s hwSrgbDecode=%d alpha=%s mips=%d/%d "
                    "%ux%u",
                    internalFormatName(resolved), (int)resolved,
                    transferName((uint32_t)out->sourceTransfer), out->hardwareSrgbDecode,
                    out->alphaMode == KTX2_ALPHA_PREMULTIPLIED ? "premultiplied" : "straight",
                    out->uploadedMipCount, out->sourceMipCount, texture->getWidth(),
                    texture->getHeight());
            }
            else
            {
                Log("KTX2 FAILED : no requested format could be resolved (source=%s, mips=%d)",
                    transferName((uint32_t)out->sourceTransfer), out->sourceMipCount);
            }

            return reinterpret_cast<TKtx2LoadResult *>(out);
        }

        EMSCRIPTEN_KEEPALIVE TTexture *Ktx2LoadResult_getTexture(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? reinterpret_cast<TTexture *>(result->texture) : nullptr;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getSourceTransfer(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->sourceTransfer : KTX2_TRANSFER_UNKNOWN;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getResolvedFormat(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->resolvedFormat : -1;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getHardwareSrgbDecode(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->hardwareSrgbDecode : 0;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getAlphaMode(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->alphaMode : KTX2_ALPHA_UNKNOWN;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getUploadedMipCount(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->uploadedMipCount : 0;
        }

        EMSCRIPTEN_KEEPALIVE int32_t Ktx2LoadResult_getSourceMipCount(TKtx2LoadResult *tResult)
        {
            auto *result = reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
            return result ? result->sourceMipCount : 0;
        }

        EMSCRIPTEN_KEEPALIVE void Ktx2LoadResult_destroy(TKtx2LoadResult *tResult)
        {
            delete reinterpret_cast<Ktx2LoadResultImpl *>(tResult);
        }

        EMSCRIPTEN_KEEPALIVE TTexture *Ktx1Reader_createTexture(
            TEngine *tEngine,
            TKtx1Bundle *tBundle,
            uint32_t requestId,
            VoidCallback onTextureUploadComplete)
        {

            auto engine = reinterpret_cast<filament::Engine *>(tEngine);

            auto *bundle = reinterpret_cast<image::Ktx1Bundle *>(tBundle);

            std::vector<void *> *callbackData = new std::vector<void *>{
                reinterpret_cast<void *>(onTextureUploadComplete),
                reinterpret_cast<void *>(requestId)};

            auto *texture =
                ktxreader::Ktx1Reader::createTexture(
                    engine, *bundle, false, [](void *userdata)
                    {
                        std::vector<void*>* vec = (std::vector<void*>*)userdata;
                        
                        void *callbackPtr = vec->at(0);
                        uintptr_t requestId = (uintptr_t)vec->at(1);

                        delete vec;
                        
                        if (callbackPtr)
                        {
                            auto callback = ((VoidCallback)callbackPtr);
                            callback(requestId);
                        } },
                    (void *)callbackData);
            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE float *Image_getBytes(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getPixelRef();
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Image_getWidth(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getWidth();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getHeight(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getHeight();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getChannels(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getChannels();
        }

        EMSCRIPTEN_KEEPALIVE void Image_destroy(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            delete linearImage;
        }

        ::filament::Texture::InternalFormat convertToFilamentFormat(TTextureFormat tFormat)
        {
            switch (tFormat)
            {
            // 8-bits per element
            case TEXTUREFORMAT_R8:
                return ::filament::Texture::InternalFormat::R8;
            case TEXTUREFORMAT_R8_SNORM:
                return ::filament::Texture::InternalFormat::R8_SNORM;
            case TEXTUREFORMAT_R8UI:
                return ::filament::Texture::InternalFormat::R8UI;
            case TEXTUREFORMAT_R8I:
                return ::filament::Texture::InternalFormat::R8I;
            case TEXTUREFORMAT_STENCIL8:
                return ::filament::Texture::InternalFormat::STENCIL8;

            // 16-bits per element
            case TEXTUREFORMAT_R16F:
                return ::filament::Texture::InternalFormat::R16F;
            case TEXTUREFORMAT_R16UI:
                return ::filament::Texture::InternalFormat::R16UI;
            case TEXTUREFORMAT_R16I:
                return ::filament::Texture::InternalFormat::R16I;
            case TEXTUREFORMAT_RG8:
                return ::filament::Texture::InternalFormat::RG8;
            case TEXTUREFORMAT_RG8_SNORM:
                return ::filament::Texture::InternalFormat::RG8_SNORM;
            case TEXTUREFORMAT_RG8UI:
                return ::filament::Texture::InternalFormat::RG8UI;
            case TEXTUREFORMAT_RG8I:
                return ::filament::Texture::InternalFormat::RG8I;
            case TEXTUREFORMAT_RGB565:
                return ::filament::Texture::InternalFormat::RGB565;
            case TEXTUREFORMAT_RGB9_E5:
                return ::filament::Texture::InternalFormat::RGB9_E5;
            case TEXTUREFORMAT_RGB5_A1:
                return ::filament::Texture::InternalFormat::RGB5_A1;
            case TEXTUREFORMAT_RGBA4:
                return ::filament::Texture::InternalFormat::RGBA4;
            case TEXTUREFORMAT_DEPTH16:
                return ::filament::Texture::InternalFormat::DEPTH16;

            // 24-bits per element
            case TEXTUREFORMAT_RGB8:
                return ::filament::Texture::InternalFormat::RGB8;
            case TEXTUREFORMAT_SRGB8:
                return ::filament::Texture::InternalFormat::SRGB8;
            case TEXTUREFORMAT_RGB8_SNORM:
                return ::filament::Texture::InternalFormat::RGB8_SNORM;
            case TEXTUREFORMAT_RGB8UI:
                return ::filament::Texture::InternalFormat::RGB8UI;
            case TEXTUREFORMAT_RGB8I:
                return ::filament::Texture::InternalFormat::RGB8I;
            case TEXTUREFORMAT_DEPTH24:
                return ::filament::Texture::InternalFormat::DEPTH24;

            // 32-bits per element
            case TEXTUREFORMAT_R32F:
                return ::filament::Texture::InternalFormat::R32F;
            case TEXTUREFORMAT_R32UI:
                return ::filament::Texture::InternalFormat::R32UI;
            case TEXTUREFORMAT_R32I:
                return ::filament::Texture::InternalFormat::R32I;
            case TEXTUREFORMAT_RG16F:
                return ::filament::Texture::InternalFormat::RG16F;
            case TEXTUREFORMAT_RG16UI:
                return ::filament::Texture::InternalFormat::RG16UI;
            case TEXTUREFORMAT_RG16I:
                return ::filament::Texture::InternalFormat::RG16I;
            case TEXTUREFORMAT_R11F_G11F_B10F:
                return ::filament::Texture::InternalFormat::R11F_G11F_B10F;
            case TEXTUREFORMAT_RGBA8:
                return ::filament::Texture::InternalFormat::RGBA8;
            case TEXTUREFORMAT_SRGB8_A8:
                return ::filament::Texture::InternalFormat::SRGB8_A8;
            case TEXTUREFORMAT_RGBA8_SNORM:
                return ::filament::Texture::InternalFormat::RGBA8_SNORM;
            case TEXTUREFORMAT_UNUSED:
                return ::filament::Texture::InternalFormat::UNUSED;
            case TEXTUREFORMAT_RGB10_A2:
                return ::filament::Texture::InternalFormat::RGB10_A2;
            case TEXTUREFORMAT_RGBA8UI:
                return ::filament::Texture::InternalFormat::RGBA8UI;
            case TEXTUREFORMAT_RGBA8I:
                return ::filament::Texture::InternalFormat::RGBA8I;
            case TEXTUREFORMAT_DEPTH32F:
                return ::filament::Texture::InternalFormat::DEPTH32F;
            case TEXTUREFORMAT_DEPTH24_STENCIL8:
                return ::filament::Texture::InternalFormat::DEPTH24_STENCIL8;
            case TEXTUREFORMAT_DEPTH32F_STENCIL8:
                return ::filament::Texture::InternalFormat::DEPTH32F_STENCIL8;

            // 48-bits per element
            case TEXTUREFORMAT_RGB16F:
                return ::filament::Texture::InternalFormat::RGB16F;
            case TEXTUREFORMAT_RGB16UI:
                return ::filament::Texture::InternalFormat::RGB16UI;
            case TEXTUREFORMAT_RGB16I:
                return ::filament::Texture::InternalFormat::RGB16I;

            // 64-bits per element
            case TEXTUREFORMAT_RG32F:
                return ::filament::Texture::InternalFormat::RG32F;
            case TEXTUREFORMAT_RG32UI:
                return ::filament::Texture::InternalFormat::RG32UI;
            case TEXTUREFORMAT_RG32I:
                return ::filament::Texture::InternalFormat::RG32I;
            case TEXTUREFORMAT_RGBA16F:
                return ::filament::Texture::InternalFormat::RGBA16F;
            case TEXTUREFORMAT_RGBA16UI:
                return ::filament::Texture::InternalFormat::RGBA16UI;
            case TEXTUREFORMAT_RGBA16I:
                return ::filament::Texture::InternalFormat::RGBA16I;

            // 96-bits per element
            case TEXTUREFORMAT_RGB32F:
                return ::filament::Texture::InternalFormat::RGB32F;
            case TEXTUREFORMAT_RGB32UI:
                return ::filament::Texture::InternalFormat::RGB32UI;
            case TEXTUREFORMAT_RGB32I:
                return ::filament::Texture::InternalFormat::RGB32I;

            // 128-bits per element
            case TEXTUREFORMAT_RGBA32F:
                return ::filament::Texture::InternalFormat::RGBA32F;
            case TEXTUREFORMAT_RGBA32UI:
                return ::filament::Texture::InternalFormat::RGBA32UI;
            case TEXTUREFORMAT_RGBA32I:
                return ::filament::Texture::InternalFormat::RGBA32I;

            // Compressed formats
            case TEXTUREFORMAT_EAC_R11:
                return ::filament::Texture::InternalFormat::EAC_R11;
            case TEXTUREFORMAT_EAC_R11_SIGNED:
                return ::filament::Texture::InternalFormat::EAC_R11_SIGNED;
            case TEXTUREFORMAT_EAC_RG11:
                return ::filament::Texture::InternalFormat::EAC_RG11;
            case TEXTUREFORMAT_EAC_RG11_SIGNED:
                return ::filament::Texture::InternalFormat::EAC_RG11_SIGNED;
            case TEXTUREFORMAT_ETC2_RGB8:
                return ::filament::Texture::InternalFormat::ETC2_RGB8;
            case TEXTUREFORMAT_ETC2_SRGB8:
                return ::filament::Texture::InternalFormat::ETC2_SRGB8;
            case TEXTUREFORMAT_ETC2_RGB8_A1:
                return ::filament::Texture::InternalFormat::ETC2_RGB8_A1;
            case TEXTUREFORMAT_ETC2_SRGB8_A1:
                return ::filament::Texture::InternalFormat::ETC2_SRGB8_A1;
            case TEXTUREFORMAT_ETC2_EAC_RGBA8:
                return ::filament::Texture::InternalFormat::ETC2_EAC_RGBA8;
            case TEXTUREFORMAT_ETC2_EAC_SRGBA8:
                return ::filament::Texture::InternalFormat::ETC2_EAC_SRGBA8;

            // DXT formats
            case TEXTUREFORMAT_DXT1_RGB:
                return ::filament::Texture::InternalFormat::DXT1_RGB;
            case TEXTUREFORMAT_DXT1_RGBA:
                return ::filament::Texture::InternalFormat::DXT1_RGBA;
            case TEXTUREFORMAT_DXT3_RGBA:
                return ::filament::Texture::InternalFormat::DXT3_RGBA;
            case TEXTUREFORMAT_DXT5_RGBA:
                return ::filament::Texture::InternalFormat::DXT5_RGBA;
            case TEXTUREFORMAT_DXT1_SRGB:
                return ::filament::Texture::InternalFormat::DXT1_SRGB;
            case TEXTUREFORMAT_DXT1_SRGBA:
                return ::filament::Texture::InternalFormat::DXT1_SRGBA;
            case TEXTUREFORMAT_DXT3_SRGBA:
                return ::filament::Texture::InternalFormat::DXT3_SRGBA;
            case TEXTUREFORMAT_DXT5_SRGBA:
                return ::filament::Texture::InternalFormat::DXT5_SRGBA;

            // ASTC formats
            case TEXTUREFORMAT_RGBA_ASTC_4x4:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_4x4;
            case TEXTUREFORMAT_RGBA_ASTC_5x4:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_5x4;
            case TEXTUREFORMAT_RGBA_ASTC_5x5:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_5x5;
            case TEXTUREFORMAT_RGBA_ASTC_6x5:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_6x5;
            case TEXTUREFORMAT_RGBA_ASTC_6x6:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_6x6;
            case TEXTUREFORMAT_RGBA_ASTC_8x5:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_8x5;
            case TEXTUREFORMAT_RGBA_ASTC_8x6:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_8x6;
            case TEXTUREFORMAT_RGBA_ASTC_8x8:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_8x8;
            case TEXTUREFORMAT_RGBA_ASTC_10x5:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_10x5;
            case TEXTUREFORMAT_RGBA_ASTC_10x6:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_10x6;
            case TEXTUREFORMAT_RGBA_ASTC_10x8:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_10x8;
            case TEXTUREFORMAT_RGBA_ASTC_10x10:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_10x10;
            case TEXTUREFORMAT_RGBA_ASTC_12x10:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_12x10;
            case TEXTUREFORMAT_RGBA_ASTC_12x12:
                return ::filament::Texture::InternalFormat::RGBA_ASTC_12x12;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_4x4:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_4x4;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x4:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_5x4;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x5:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_5x5;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x5:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_6x5;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x6:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_6x6;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x5:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x5;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x6:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x6;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x8:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x8;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x5:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x5;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x6:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x6;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x8:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x8;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x10:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x10;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x10:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_12x10;
            case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x12:
                return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_12x12;

            // RGTC formats
            case TEXTUREFORMAT_RED_RGTC1:
                return ::filament::Texture::InternalFormat::RED_RGTC1;
            case TEXTUREFORMAT_SIGNED_RED_RGTC1:
                return ::filament::Texture::InternalFormat::SIGNED_RED_RGTC1;
            case TEXTUREFORMAT_RED_GREEN_RGTC2:
                return ::filament::Texture::InternalFormat::RED_GREEN_RGTC2;
            case TEXTUREFORMAT_SIGNED_RED_GREEN_RGTC2:
                return ::filament::Texture::InternalFormat::SIGNED_RED_GREEN_RGTC2;

            // BPTC formats
            case TEXTUREFORMAT_RGB_BPTC_SIGNED_FLOAT:
                return ::filament::Texture::InternalFormat::RGB_BPTC_SIGNED_FLOAT;
            case TEXTUREFORMAT_RGB_BPTC_UNSIGNED_FLOAT:
                return ::filament::Texture::InternalFormat::RGB_BPTC_UNSIGNED_FLOAT;
            case TEXTUREFORMAT_RGBA_BPTC_UNORM:
                return ::filament::Texture::InternalFormat::RGBA_BPTC_UNORM;
            case TEXTUREFORMAT_SRGB_ALPHA_BPTC_UNORM:
                return ::filament::Texture::InternalFormat::SRGB_ALPHA_BPTC_UNORM;

            default:
                // Fallback to a common format if an unknown format is provided
                return ::filament::Texture::InternalFormat::RGBA8;
            }
        }

        EMSCRIPTEN_KEEPALIVE TTexture *Texture_build(
            TEngine *tEngine,
            uint32_t width,
            uint32_t height,
            uint32_t depth,
            uint8_t levels,
            uint16_t tUsage,
            intptr_t import,
            TTextureSamplerType tSamplerType,
            TTextureFormat tFormat)
        {
            TRACE("Creating texture %dx%d (depth %d), sampler type %d, format %d tUsage %d, %d levels", width, height, depth, static_cast<int>(tSamplerType), static_cast<int>(tFormat), tUsage, levels);
            auto *engine = reinterpret_cast<::filament::Engine *>(tEngine);
            auto format = convertToFilamentFormat(tFormat);
            auto samplerType = static_cast<::filament::Texture::Sampler>(static_cast<int>(tSamplerType));
            auto usage = static_cast<TextureUsage>(tUsage);

            auto builder = ::filament::Texture::Builder()
                               .width(width)
                               .height(height)
                               .depth(depth)
                               .levels(levels)
                               .sampler(samplerType)
                               .format(format)
                               .usage(usage);
            if (import == -1)
            {
                Log("Building external texture");
                builder.external();
            }
            else if (import)
            {
                Log("Importing texture with handle : %d", import);
                builder.import(import);
            }
            auto *texture = builder
                                .build(*engine);
            if (texture)
            {
                TRACE("Texture successfully created with %d levels", texture->getLevels());
            }
            else
            {
                Log("Error: failed to created texture");
            }

            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE void Texture_setExternalImage(TEngine *tEngine, TTexture *tTexture, void *externalImage)
        {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto *extImg = static_cast<filament::backend::Platform::ExternalImage *>(externalImage);
            auto handle = filament::backend::Platform::ExternalImageHandle(extImg);
            texture->setExternalImage(*engine, std::move(handle));
        }

        EMSCRIPTEN_KEEPALIVE size_t Texture_getLevels(TTexture *tTexture)
        {
            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getLevels();
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_loadImage(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage, TPixelDataFormat tBufferFormat, TPixelDataType tPixelDataType, int level)
        {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto image = reinterpret_cast<::image::LinearImage *>(tImage);
            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(static_cast<int>(tBufferFormat));
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(static_cast<int>(tPixelDataType));

            uint32_t w = image->getWidth();
            uint32_t h = image->getHeight();
            uint32_t channels = image->getChannels();

            size_t size;
            switch (bufferFormat)
            {
            case PixelBufferDescriptor::PixelDataFormat::RGB:
            case PixelBufferDescriptor::PixelDataFormat::RGBA:
                size = w * h * channels * sizeof(float);
                break;
            case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
            case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
                size = w * h * channels * sizeof(uint8_t);
                break;
            default:
                Log("Unsupported buffer format type : %d", bufferFormat);
                return false;
            }

            TRACE("Loading image from dimensions %d x %d, channels %d, size %d, buffer format %d and pixel data type %d", w, h, channels, size, bufferFormat, pixelDataType);

            // PixelBufferDescriptor retains the pixel pointer until the
            // backend has consumed the upload. Keep a shallow LinearImage
            // copy alive for that period; LinearImage copies share ownership
            // of their underlying pixel allocation.
            auto *retainedImage = new ::image::LinearImage(*image);
            filament::Texture::PixelBufferDescriptor buffer(
                retainedImage->getPixelRef(),
                size,
                bufferFormat,
                pixelDataType,
                1, // alignment
                0, // left
                0, // top
                0, // stride
                [](void *, size_t, void *user)
                {
                    delete static_cast<::image::LinearImage *>(user);
                },
                retainedImage);

            texture->setImage(*engine, level, std::move(buffer));
            return true;
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_setImage(
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
            uint32_t depth,
            uint32_t tBufferFormat,
            uint32_t tPixelDataType,
            void (*onRelease)(void *, size_t, void *),
            void *userData)
        {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);

            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(tBufferFormat);
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(tPixelDataType);
            TRACE("Setting texture image for level %d, offset %dx%dx%d, depth %d", level, x_offset, y_offset, z_offset, depth);

            filament::Texture::PixelBufferDescriptor pbd(
                data,
                size,
                bufferFormat,
                pixelDataType,
                1, // alignment
                0, // left
                0, // top
                0, // stride
                onRelease,
                userData);

            texture->setImage(
                *engine,
                level,
                x_offset,
                y_offset,
                z_offset,
                width,
                height,
                depth,
                std::move(pbd));

            return true;
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getWidth(TTexture *tTexture, uint32_t level)
        {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getWidth();
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getHeight(TTexture *tTexture, uint32_t level)
        {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getHeight();
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getDepth(TTexture *tTexture, uint32_t level)
        {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getDepth();
        }

        EMSCRIPTEN_KEEPALIVE TTextureFormat Texture_getFormat(TTexture *tTexture)
        {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return static_cast<TTextureFormat>(texture->getFormat());
        }

        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMaps(TTexture *tTexture, TEngine *tEngine)
        {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            texture->generateMipmaps(*engine);
        }

        EMSCRIPTEN_KEEPALIVE TLinearImage *Image_createEmpty(uint32_t width, uint32_t height, uint32_t channel)
        {
            auto *image = new ::image::LinearImage(width, height, channel);
            return reinterpret_cast<TLinearImage *>(image);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_create()
        {
            auto *sampler = new filament::TextureSampler();
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_createWithFiltering(
            TSamplerMinFilter minFilter,
            TSamplerMagFilter magFilter,
            TSamplerWrapMode wrapS,
            TSamplerWrapMode wrapT,
            TSamplerWrapMode wrapR)
        {

            filament::TextureSampler::MinFilter min = static_cast<filament::TextureSampler::MinFilter>(minFilter);
            filament::TextureSampler::MagFilter mag = static_cast<filament::TextureSampler::MagFilter>(magFilter);
            filament::TextureSampler::WrapMode s = static_cast<filament::TextureSampler::WrapMode>(wrapS);
            filament::TextureSampler::WrapMode t = static_cast<filament::TextureSampler::WrapMode>(wrapT);
            filament::TextureSampler::WrapMode r = static_cast<filament::TextureSampler::WrapMode>(wrapR);

            auto *sampler = new filament::TextureSampler(min, mag, s, t, r);
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_createWithComparison(
            TSamplerCompareMode compareMode,
            TSamplerCompareFunc compareFunc)
        {

            if (compareMode == COMPARE_MODE_NONE)
            {
                TRACE("COMPARE MODE NONE");
            }
            else if (compareMode == COMPARE_MODE_COMPARE_TO_TEXTURE)
            {
                TRACE("COMPARE MODE COMPARE TO TEXTURE");
            }
            else
            {
                TRACE("UNKNWON COMPARE MODE");
            }

            filament::TextureSampler::CompareMode mode = static_cast<filament::TextureSampler::CompareMode>(static_cast<int>(compareMode));
            filament::TextureSampler::CompareFunc func = static_cast<filament::TextureSampler::CompareFunc>(static_cast<int>(compareFunc));

            TRACE("Creating texture sampler with compare mode %d and compare func %d");

            auto *sampler = new filament::TextureSampler(mode, func);
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilter(
            TTextureSampler *sampler,
            TSamplerMinFilter filter)
        {
            auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
            textureSampler->setMinFilter(static_cast<filament::TextureSampler::MinFilter>(filter));
            TRACE("Set TextureSampler min filter to %d", filter);
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropy(
            TTextureSampler *sampler,
            double anisotropy)
        {
            auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
            textureSampler->setAnisotropy(static_cast<float>(anisotropy));
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilter(
            TTextureSampler *sampler,
            TSamplerMagFilter filter)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setMagFilter(static_cast<filament::TextureSampler::MagFilter>(filter));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeS(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeS(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeT(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeT(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeR(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeR(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareMode(
            TTextureSampler *sampler,
            TSamplerCompareMode mode,
            TSamplerCompareFunc func)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setCompareMode(
                    static_cast<filament::TextureSampler::CompareMode>(mode),
                    static_cast<filament::TextureSampler::CompareFunc>(func));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroy(TTextureSampler *sampler)
        {
            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                delete textureSampler;
            }
        }

        EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getColorTexture(TRenderTarget *tRenderTarget)
        {
            auto renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            auto texture = renderTarget->getTexture(filament::RenderTarget::AttachmentPoint::COLOR0);
            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getDepthTexture(TRenderTarget *tRenderTarget)
        {
            auto renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            auto texture = renderTarget->getTexture(filament::RenderTarget::AttachmentPoint::DEPTH);
            return reinterpret_cast<TTexture *>(texture);
        }

#ifdef __cplusplus
    }
}
#endif
