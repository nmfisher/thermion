#pragma once

#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif

#include <stddef.h>
#include <stdint.h>

	typedef void (*VoidCallback)(int32_t requestId);
	
	typedef int32_t EntityId;
	typedef struct TCamera TCamera;
	typedef struct TEngine TEngine;
	typedef struct TEntityManager TEntityManager;
	typedef struct TViewer TViewer;
	typedef struct TSceneManager TSceneManager;
	typedef struct TLightManager TLightManager;
	typedef struct TRenderManager TRenderManager;
	typedef struct TRenderer TRenderer;
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
	typedef struct TKtx1Bundle TKtx1Bundle;
	typedef struct TDebugRegistry TDebugRegistry;
	typedef struct TRenderableBuilder TRenderableBuilder;
	typedef struct TVertexBuffer TVertexBuffer;
	typedef struct TIndexBuffer TIndexBuffer;
	typedef struct TVertexBufferBuilder TVertexBufferBuilder;
	typedef struct TIndexBufferBuilder TIndexBufferBuilder;
	typedef struct TBufferObject TBufferObject;
	typedef struct TBufferObjectBuilder TBufferObjectBuilder;
	typedef struct TSurfaceOrientation TSurfaceOrientation;
	typedef struct TSurfaceOrientationBuilder TSurfaceOrientationBuilder;
	
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

	enum TSceneAssetType {
		SCENE_ASSET_TYPE_GLTF = 0,
		SCENE_ASSET_TYPE_GEOMETRY = 1,
		SCENE_ASSET_TYPE_LIGHT = 2,
		SCENE_ASSET_TYPE_SKYBOX = 3,
		SCENE_ASSET_TYPE_IBL = 4,
		SCENE_ASSET_TYPE_IMAGE = 5,
		SCENE_ASSET_TYPE_GIZMO = 6
	};
	typedef enum TSceneAssetType TSceneAssetType;

	enum TVertexBufferStorageMode {
		VERTEX_BUFFER_STORAGE_MODE_UNKNOWN = 0,
		VERTEX_BUFFER_STORAGE_MODE_DIRECT = 1,
		VERTEX_BUFFER_STORAGE_MODE_BUFFER_OBJECTS = 2
	};
	typedef enum TVertexBufferStorageMode TVertexBufferStorageMode;

	enum TSceneAssetGeometryCapability {
		SCENE_ASSET_GEOMETRY_CAPABILITY_NONE = 0,
		SCENE_ASSET_GEOMETRY_CAPABILITY_FLAT_SHADING = 1 << 0,
		SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS = 1 << 1,
		SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES = 1 << 2,
		SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_GEOMETRY = 1 << 3,
		SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY = 1 << 4,
		SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS = 1 << 5
	};
	typedef enum TSceneAssetGeometryCapability TSceneAssetGeometryCapability;

	enum TFeatureLevel {
		FEATURE_LEVEL_0 = 0,
		FEATURE_LEVEL_1 = 1,
		FEATURE_LEVEL_2 = 2,
		FEATURE_LEVEL_3 = 3
	};
	typedef enum TFeatureLevel TFeatureLevel;

	enum TPrimitiveType {
		// don't change the enums values (made to match GL)
		PRIMITIVETYPE_POINTS         = 0,    //!< points
		PRIMITIVETYPE_LINES          = 1,    //!< lines
		PRIMITIVETYPE_LINE_STRIP     = 3,    //!< line strip
		PRIMITIVETYPE_TRIANGLES      = 4,    //!< triangles
		PRIMITIVETYPE_TRIANGLE_STRIP = 5     //!< triangle strip
	};
	typedef enum TPrimitiveType TPrimitiveType;

	// Vertex attribute types (must match filament::VertexAttribute)
	enum TVertexAttribute {
		TVERTEX_ATTRIBUTE_POSITION        = 0,
		TVERTEX_ATTRIBUTE_TANGENTS        = 1,
		TVERTEX_ATTRIBUTE_COLOR           = 2,
		TVERTEX_ATTRIBUTE_UV0             = 3,
		TVERTEX_ATTRIBUTE_UV1             = 4,
		TVERTEX_ATTRIBUTE_BONE_INDICES    = 5,
		TVERTEX_ATTRIBUTE_BONE_WEIGHTS    = 6,
		TVERTEX_ATTRIBUTE_CUSTOM0         = 8,
		TVERTEX_ATTRIBUTE_CUSTOM1         = 9,
		TVERTEX_ATTRIBUTE_CUSTOM2         = 10,
		TVERTEX_ATTRIBUTE_CUSTOM3         = 11,
		TVERTEX_ATTRIBUTE_CUSTOM4         = 12,
		TVERTEX_ATTRIBUTE_CUSTOM5         = 13,
		TVERTEX_ATTRIBUTE_CUSTOM6         = 14,
		TVERTEX_ATTRIBUTE_CUSTOM7         = 15
	};
	typedef enum TVertexAttribute TVertexAttribute;

	// Attribute element types (must match backend::ElementType)
	enum TVertexAttributeType {
		TVERTEXATTRIBUTE_TYPE_BYTE     = 0,
		TVERTEXATTRIBUTE_TYPE_BYTE2    = 1,
		TVERTEXATTRIBUTE_TYPE_BYTE3    = 2,
		TVERTEXATTRIBUTE_TYPE_BYTE4    = 3,
		TVERTEXATTRIBUTE_TYPE_UBYTE    = 4,
		TVERTEXATTRIBUTE_TYPE_UBYTE2   = 5,
		TVERTEXATTRIBUTE_TYPE_UBYTE3   = 6,
		TVERTEXATTRIBUTE_TYPE_UBYTE4   = 7,
		TVERTEXATTRIBUTE_TYPE_SHORT    = 8,
		TVERTEXATTRIBUTE_TYPE_SHORT2   = 9,
		TVERTEXATTRIBUTE_TYPE_SHORT3   = 10,
		TVERTEXATTRIBUTE_TYPE_SHORT4   = 11,
		TVERTEXATTRIBUTE_TYPE_USHORT   = 12,
		TVERTEXATTRIBUTE_TYPE_USHORT2  = 13,
		TVERTEXATTRIBUTE_TYPE_USHORT3  = 14,
		TVERTEXATTRIBUTE_TYPE_USHORT4  = 15,
		TVERTEXATTRIBUTE_TYPE_INT      = 16,
		TVERTEXATTRIBUTE_TYPE_UINT     = 17,
		TVERTEXATTRIBUTE_TYPE_FLOAT    = 18,
		TVERTEXATTRIBUTE_TYPE_FLOAT2   = 19,
		TVERTEXATTRIBUTE_TYPE_FLOAT3   = 20,
		TVERTEXATTRIBUTE_TYPE_FLOAT4   = 21,
		TVERTEXATTRIBUTE_TYPE_HALF     = 22,
		TVERTEXATTRIBUTE_TYPE_HALF2    = 23,
		TVERTEXATTRIBUTE_TYPE_HALF3    = 24,
		TVERTEXATTRIBUTE_TYPE_HALF4    = 25
	};
	typedef enum TVertexAttributeType TVertexAttributeType;

	// Index buffer types
	// Note: These are abstract values that get mapped to backend::ElementType internally
	enum TIndexType {
		TINDEX_TYPE_USHORT = 0,  // 16-bit indices
		TINDEX_TYPE_UINT   = 1   // 32-bit indices
	};
	typedef enum TIndexType TIndexType;

	extern uint64_t TSWAP_CHAIN_CONFIG_TRANSPARENT;
	extern uint64_t TSWAP_CHAIN_CONFIG_READABLE;
	extern uint64_t TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
	extern uint64_t TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;

#ifdef __cplusplus
}
#endif
