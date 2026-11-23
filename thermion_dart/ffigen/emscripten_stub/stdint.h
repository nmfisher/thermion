// Parse-only stand-in for the C99 <stdint.h> shipped in an Emscripten
// sysroot; see emscripten.h. Clang's own resource stdint.h is hosted and
// falls through to /usr/include/stdint.h, which is not a wasm sysroot, so
// ffigen_js would otherwise parse every fixed-width type as `int`.
//
// The typedefs match the wasm32 ABI (ILP32): 8/16/32-bit types are the
// usual exact-width aliases and 64-bit types are long long. Only the names
// ffigen maps by spelling need to be present.
#pragma once

typedef signed char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long long int64_t;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

typedef int intptr_t;
typedef unsigned int uintptr_t;
typedef long long intmax_t;
typedef unsigned long long uintmax_t;

#define INT8_MIN (-128)
#define INT16_MIN (-32768)
#define INT32_MIN (-2147483647 - 1)
#define INT8_MAX 127
#define INT16_MAX 32767
#define INT32_MAX 2147483647
#define INT64_MAX 9223372036854775807LL
#define UINT8_MAX 255
#define UINT16_MAX 65535
#define UINT32_MAX 4294967295U
#define UINT64_MAX 18446744073709551615ULL
