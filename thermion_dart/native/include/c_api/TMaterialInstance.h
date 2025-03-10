#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif

	// copied from SamplerCompareFunc in DriverEnums.h
	enum TSamplerCompareFunc
	{
		// don't change the enums values
		LE = 0, //!< Less or equal
		GE,		//!< Greater or equal
		L,		//!< Strictly less than
		G,		//!< Strictly greater than
		E,		//!< Equal
		NE,		//!< Not equal
		A,		//!< Always. Depth / stencil testing is deactivated.
		N		//!< Never. The depth / stencil test always fails.
	};

	// StencilOperation equivalent
	enum TStencilOperation
	{
		KEEP = 0,  // Keep the current value
		ZERO,	   // Set the value to zero
		REPLACE,   // Set the value to reference value
		INCR,	   // Increment the current value with saturation
		INCR_WRAP, // Increment the current value without saturation
		DECR,	   // Decrement the current value with saturation
		DECR_WRAP, // Decrement the current value without saturation
		INVERT	   // Invert the current value
	};

	enum TStencilFace
	{
		STENCIL_FACE_FRONT = 1,
		STENCIL_FACE_BACK = 2,
		STENCIL_FACE_FRONT_AND_BACK = 3
	};

	enum TCullingMode
	{
		CULLING_MODE_NONE = 0,
		CULLING_MODE_FRONT,
		CULLING_MODE_BACK,
		CULLING_MODE_FRONT_AND_BACK
	};

	enum TTransparencyMode { 
		//! the transparent object is drawn honoring the raster state
		DEFAULT,
		/**
		 * the transparent object is first drawn in the depth buffer,
		 * then in the color buffer, honoring the culling mode, but ignoring the depth test function
		 */
		TWO_PASSES_ONE_SIDE,

		/**
		 * the transparent object is drawn twice in the color buffer,
		 * first with back faces only, then with front faces; the culling
		 * mode is ignored. Can be combined with two-sided lighting
		 */
		TWO_PASSES_TWO_SIDES
	};

	EMSCRIPTEN_KEEPALIVE TMaterialInstance *Material_createInstance(TMaterial *tMaterial);
	EMSCRIPTEN_KEEPALIVE bool Material_hasParameter(TMaterial *tMaterial, const char *propertyName);
	EMSCRIPTEN_KEEPALIVE bool MaterialInstance_isStencilWriteEnabled(TMaterialInstance *materialInstance);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWrite(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setCullingMode(TMaterialInstance *materialInstance, TCullingMode culling);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance *materialInstance, const char *propertyName, double value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *propertyName, double x, double y);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3(TMaterialInstance *materialInstance, const char *propertyName, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3Array(TMaterialInstance *tMaterialInstance, const char *propertyName, double *raw, uint32_t length);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat4(TMaterialInstance *materialInstance, const char *propertyName, double x, double y, double w, double z);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance *materialInstance, const char *propertyName, int value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterBool(TMaterialInstance *materialInstance, const char *propertyName, bool value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTexture(TMaterialInstance *materialInstance, const char *propertyName, TTexture *texture, TTextureSampler *sampler);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthFunc(TMaterialInstance *materialInstance, TSamplerCompareFunc depthFunc);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpStencilFail(
		TMaterialInstance *materialInstance,
		TStencilOperation op,
		TStencilFace face);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthFail(
		TMaterialInstance *materialInstance,
		TStencilOperation op,
		TStencilFace face);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthStencilPass(
		TMaterialInstance *materialInstance,
		TStencilOperation op,
		TStencilFace face);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilCompareFunction(
		TMaterialInstance *materialInstance,
		TSamplerCompareFunc func,
		TStencilFace face);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReferenceValue(
		TMaterialInstance *materialInstance,
		uint8_t value,
		TStencilFace face);
	
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReadMask(
		TMaterialInstance *materialInstance,
		uint8_t mask);
	
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWriteMask(
		TMaterialInstance *materialInstance,
		uint8_t mask);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setTransparencyMode(
            TMaterialInstance *materialInstance,
            TTransparencyMode transparencyMode);


#ifdef __cplusplus
}
#endif
