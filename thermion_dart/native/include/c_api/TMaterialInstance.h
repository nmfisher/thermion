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

	// StencilFace equivalent
	enum TStencilFace
	{
		STENCIL_FACE_FRONT = 1,
		STENCIL_FACE_BACK = 2,
		STENCIL_FACE_FRONT_AND_BACK = 3
	};

	// Add these enum definitions at the top with the other enums
	enum TCullingMode
	{
		CULLING_MODE_NONE = 0,
		CULLING_MODE_FRONT,
		CULLING_MODE_BACK,
		CULLING_MODE_FRONT_AND_BACK
	};

	EMSCRIPTEN_KEEPALIVE bool MaterialInstance_isStencilWriteEnabled(TMaterialInstance *materialInstance);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWrite(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setCullingMode(TMaterialInstance *materialInstance, TCullingMode culling);

	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat4(TMaterialInstance *materialInstance, const char *name, double x, double y, double w, double z);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *name, double x, double y);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance *materialInstance, const char *name, double value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance *materialInstance, const char *name, int value);
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


#ifdef __cplusplus
}
#endif
