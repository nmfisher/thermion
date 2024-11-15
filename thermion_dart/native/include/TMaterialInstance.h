#pragma once

#ifdef _WIN32
#ifdef IS_DLL
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif
#else
#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE __attribute__((visibility("default")))
#endif
#endif

// we copy the LLVM <stdbool.h> here rather than including,
// because on Windows it's difficult to pin the exact location which confuses dart ffigen

#ifndef __STDBOOL_H
#define __STDBOOL_H

#define __bool_true_false_are_defined 1

#if defined(__STDC_VERSION__) && __STDC_VERSION__ > 201710L
/* FIXME: We should be issuing a deprecation warning here, but cannot yet due
 * to system headers which include this header file unconditionally.
 */
#elif !defined(__cplusplus)
#define bool _Bool
#define true 1
#define false 0
#elif defined(__GNUC__) && !defined(__STRICT_ANSI__)
/* Define _Bool as a GNU extension. */
#define _Bool bool
#if defined(__cplusplus) && __cplusplus < 201103L
/* For C++98, define bool, false, true as a GNU extension. */
#define bool bool
#define false false
#define true true
#endif
#endif

#endif /* __STDBOOL_H */

#if defined(__APPLE__) || defined(__EMSCRIPTEN__)
#include <stddef.h>
#endif

typedef struct TMaterialInstance TMaterialInstance;

// copied from SamplerCompareFunc in DriverEnums.h
enum TDepthFunc { 
	// don't change the enums values
	LE = 0,     //!< Less or equal
	GE,         //!< Greater or equal
	L,          //!< Strictly less than
	G,          //!< Strictly greater than
	E,          //!< Equal
	NE,         //!< Not equal
	A,          //!< Always. Depth / stencil testing is deactivated.
	N           //!< Never. The depth / stencil test always fails.
};
	

#ifdef __cplusplus
extern "C"
{
#endif
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance* materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance* materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat4(TMaterialInstance* materialInstance, const char* name, double x, double y, double w, double z);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance* materialInstance, const char* name, double x, double y);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance* materialInstance, const char* name, double value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance* materialInstance, const char* name, int value);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthFunc(TMaterialInstance* materialInstance, TDepthFunc depthFunc);
    #ifdef __cplusplus
}
#endif

