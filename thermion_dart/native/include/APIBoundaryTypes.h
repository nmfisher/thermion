#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>

	typedef int32_t EntityId;
	typedef struct TCamera TCamera;
	typedef struct TMaterialInstance TMaterialInstance;
	typedef struct TEngine TEngine;
	typedef struct TEntityManager TEntityManager;
	typedef struct TViewer TViewer;
	typedef struct TSceneManager TSceneManager;
	typedef struct TRenderTarget TRenderTarget;
	typedef struct TSwapChain TSwapChain;
	typedef struct TView TView;
	typedef struct TGizmo TGizmo;
	typedef struct TScene TScene;
	
	struct TMaterialKey {
		bool doubleSided = true;
		bool unlit = true;
		bool hasVertexColors = true;
		bool hasBaseColorTexture = true;
		bool hasNormalTexture = true;
		bool hasOcclusionTexture = true;
		bool hasEmissiveTexture = true;
		bool useSpecularGlossiness = true;
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
				bool hasMetallicRoughnessTexture = true;
				uint8_t metallicRoughnessUV = 7;
			};
			struct {
				bool hasSpecularGlossinessTexture = true;
				uint8_t specularGlossinessUV = 7;
			};
			#endif
		};
		uint8_t baseColorUV;
		// -- 32 bit boundary --
		bool hasClearCoatTexture = true;
		uint8_t clearCoatUV = 7;
		bool hasClearCoatRoughnessTexture = true;
		uint8_t clearCoatRoughnessUV = 7;
		bool hasClearCoatNormalTexture = true;
		uint8_t clearCoatNormalUV = 7;
		bool hasClearCoat = true;
		bool hasTransmission = true;
		bool hasTextureTransforms = 6;
		// -- 32 bit boundary --
		uint8_t emissiveUV;
		uint8_t aoUV;
		uint8_t normalUV;
		bool hasTransmissionTexture = true;
		uint8_t transmissionUV = 7;
		// -- 32 bit boundary --
		bool hasSheenColorTexture = true;
		uint8_t sheenColorUV = 7;
		bool hasSheenRoughnessTexture = true;
		uint8_t sheenRoughnessUV = 7;
		bool hasVolumeThicknessTexture = true;
		uint8_t volumeThicknessUV = 7;
		bool hasSheen = true;
		bool hasIOR = true;
		bool hasVolume = true;
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

	struct Aabb3 {
        float centerX;
        float centerY;
        float centerZ; 
        float halfExtentX;
		float halfExtentY;
		float halfExtentZ;
    };

    typedef struct Aabb3 Aabb3;

#ifdef __cplusplus
}
#endif