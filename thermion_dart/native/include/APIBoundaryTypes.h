#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>

	typedef int32_t EntityId;
	typedef int32_t _ManipulatorMode;
	typedef struct TCamera TCamera;
	typedef struct TMaterialInstance TMaterialInstance;

	struct TMaterialKey {
		bool doubleSided = 1;
		bool unlit = 1;
		bool hasVertexColors = 1;
		bool hasBaseColorTexture = 1;
		bool hasNormalTexture = 1;
		bool hasOcclusionTexture = 1;
		bool hasEmissiveTexture = 1;
		bool useSpecularGlossiness = 1;
		int alphaMode = 4;
		bool enableDiagnostics = 4;
		union {
			#ifdef __cplusplus
			struct {
				bool hasMetallicRoughnessTexture;
				uint8_t metallicRoughnessUV;
			};
			struct {
				bool hasSpecularGlossinessTexture;
				uint8_t specularGlossinessUV;
			};
			#else
			struct {
				bool hasMetallicRoughnessTexture = 1;
				uint8_t metallicRoughnessUV = 7;
			};
			struct {
				bool hasSpecularGlossinessTexture = 1;
				uint8_t specularGlossinessUV = 7;
			};
			#endif
		};
		uint8_t baseColorUV;
		// -- 32 bit boundary --
		bool hasClearCoatTexture = 1;
		uint8_t clearCoatUV = 7;
		bool hasClearCoatRoughnessTexture = 1;
		uint8_t clearCoatRoughnessUV = 7;
		bool hasClearCoatNormalTexture = 1;
		uint8_t clearCoatNormalUV = 7;
		bool hasClearCoat = 1;
		bool hasTransmission = 1;
		bool hasTextureTransforms = 6;
		// -- 32 bit boundary --
		uint8_t emissiveUV;
		uint8_t aoUV;
		uint8_t normalUV;
		bool hasTransmissionTexture = 1;
		uint8_t transmissionUV = 7;
		// -- 32 bit boundary --
		bool hasSheenColorTexture = 1;
		uint8_t sheenColorUV = 7;
		bool hasSheenRoughnessTexture = 1;
		uint8_t sheenRoughnessUV = 7;
		bool hasVolumeThicknessTexture = 1;
		uint8_t volumeThicknessUV = 7;
		bool hasSheen = 1;
		bool hasIOR = 1;
		bool hasVolume = 1;
	} ;
	typedef struct TMaterialKey TMaterialKey; 

	typedef struct { 
		double x;
		double y; 
		double z;
		double w;
	} double4;

	typedef struct {
		double col1[4];
		double col2[4];
		double col3[4];
		double col4[4];
	} double4x4;

    struct Aabb2 {
        float minX;
        float minY;
        float maxX; 
        float maxY;
    };

    typedef struct Aabb2 Aabb2;

#ifdef __cplusplus
}
#endif