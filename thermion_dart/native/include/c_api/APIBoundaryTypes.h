#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include <stddef.h>
#include <stdint.h>

#include "APIExport.h"
	
	typedef int32_t EntityId;
	typedef struct TCamera TCamera;
	typedef struct TEngine TEngine;
	typedef struct TEntityManager TEntityManager;
	typedef struct TViewer TViewer;
	typedef struct TSceneManager TSceneManager;
	typedef struct TLightManager TLightManager;
	typedef struct TRenderer TRenderer;
	typedef struct TRenderTicker TRenderTicker;
	typedef struct TFence TFence;
	typedef struct TRenderTarget TRenderTarget;
	typedef struct TSwapChain TSwapChain;
	typedef struct TView TView;
	typedef struct TGizmo TGizmo;
	typedef struct TScene TScene;
	typedef struct TSkybox TSkybox;
	typedef struct TIndirectLight TIndirectLight;
	typedef struct TTransformManager TTransformManager;
	typedef struct TAnimationManager TAnimationManager;
	typedef struct TCollisionComponentManager TCollisionComponentManager;
	typedef struct TSceneAsset TSceneAsset;
	typedef struct TNameComponentManager TNameComponentManager;
	typedef struct TMaterial TMaterial;
	typedef struct TMaterialInstance TMaterialInstance;
	typedef struct TMaterialProvider TMaterialProvider;
	typedef struct TRenderableManager TRenderableManager;
	typedef struct TRenderableInstance TRenderableInstance;
	typedef struct TTexture TTexture;
	typedef struct TTextureSampler TTextureSampler;
	typedef struct TLinearImage TLinearImage;
	typedef struct TGltfAssetLoader TGltfAssetLoader;
	typedef struct TGltfResourceLoader TGltfResourceLoader;
	typedef struct TFilamentAsset TFilamentAsset;
	typedef struct TColorGrading TColorGrading;

	typedef struct { 
		double x;
		double y; 
		double z;
	} double3;

	typedef struct {
		double3 col1;
		double3 col2;
		double3 col3;
	} double3x3;

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

	enum TGizmoType {
		GIZMO_TYPE_TRANSLATION,
		GIZMO_TYPE_ROTATION
	};
	typedef enum TGizmoType TGizmoType;

	enum TPrimitiveType {
		// don't change the enums values (made to match GL)
		PRIMITIVETYPE_POINTS         = 0,    //!< points
		PRIMITIVETYPE_LINES          = 1,    //!< lines
		PRIMITIVETYPE_LINE_STRIP     = 3,    //!< line strip
		PRIMITIVETYPE_TRIANGLES      = 4,    //!< triangles
		PRIMITIVETYPE_TRIANGLE_STRIP = 5     //!< triangle strip
	};
	typedef enum TPrimitiveType TPrimitiveType;

	extern uint64_t TSWAP_CHAIN_CONFIG_TRANSPARENT;
	extern uint64_t TSWAP_CHAIN_CONFIG_READABLE;
	extern uint64_t TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
	extern uint64_t TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;

#ifdef __cplusplus
}
#endif