#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif
	
	// EMSCRIPTEN_KEEPALIVE TMaterialProvider *MaterialProvider_create(TEngine *tEngine, uint8_t* data, size_t length);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *MaterialProvider_createMaterialInstance(
		TMaterialProvider *provider, 
		bool doubleSided,
		bool unlit,
		bool hasVertexColors,
		bool hasBaseColorTexture,
		bool hasNormalTexture,
		bool hasOcclusionTexture,
		bool hasEmissiveTexture,
		bool useSpecularGlossiness,
		int alphaMode,
		bool enableDiagnostics,
		bool hasMetallicRoughnessTexture,
		uint8_t metallicRoughnessUV,
		bool hasSpecularGlossinessTexture,
		uint8_t specularGlossinessUV,
		uint8_t baseColorUV,
		bool hasClearCoatTexture,
		uint8_t clearCoatUV,
		bool hasClearCoatRoughnessTexture,
		uint8_t clearCoatRoughnessUV,
		bool hasClearCoatNormalTexture,
		uint8_t clearCoatNormalUV,
		bool hasClearCoat,
		bool hasTransmission,
		bool hasTextureTransforms,
		uint8_t emissiveUV,
		uint8_t aoUV,
		uint8_t normalUV,
		bool hasTransmissionTexture,
		uint8_t transmissionUV,
		bool hasSheenColorTexture,
		uint8_t sheenColorUV,
		bool hasSheenRoughnessTexture,
		uint8_t sheenRoughnessUV,
		bool hasVolumeThicknessTexture,
		uint8_t volumeThicknessUV ,
		bool hasSheen,
		bool hasIOR,
		bool hasVolume
	);
	
#ifdef __cplusplus
}
#endif
