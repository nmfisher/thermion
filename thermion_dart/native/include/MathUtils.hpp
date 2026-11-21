#pragma once
#include <cstddef>
#include <cstring>
#include <type_traits>
#include <math/mat4.h>
#include <math/mat3.h>
#include "c_api/APIBoundaryTypes.h"

namespace thermion {

// Helper function to convert double* to filament::math::mat4f
static filament::math::mat4f convert_double_to_mat4f(double* data)
{
    return filament::math::mat4f {
        filament::math::float4{static_cast<float>(data[0]), static_cast<float>(data[1]), static_cast<float>(data[2]), static_cast<float>(data[3])},
        filament::math::float4{static_cast<float>(data[4]), static_cast<float>(data[5]), static_cast<float>(data[6]), static_cast<float>(data[7])},
        filament::math::float4{static_cast<float>(data[8]), static_cast<float>(data[9]), static_cast<float>(data[10]), static_cast<float>(data[11])},
        filament::math::float4{static_cast<float>(data[12]), static_cast<float>(data[13]), static_cast<float>(data[14]), static_cast<float>(data[15])}};
}

// Helper function to convert double* to filament::math::mat3f
static filament::math::mat3f convert_double_to_mat3f(double* data)
{
    return filament::math::mat3f {
        filament::math::float3{static_cast<float>(data[0]), static_cast<float>(data[1]), static_cast<float>(data[2])},
        filament::math::float3{static_cast<float>(data[3]), static_cast<float>(data[4]), static_cast<float>(data[5])},
        filament::math::float3{static_cast<float>(data[6]), static_cast<float>(data[7]), static_cast<float>(data[8])}};
}

// Both types store four consecutive columns of doubles. Copy their object
// representations without narrowing values or aliasing unrelated C++ types.
// Guard size/type assumptions here; matrix tests check column ordering too.
static_assert(std::is_same_v<filament::math::mat4::value_type, double>);
static_assert(std::is_trivially_copyable_v<filament::math::mat4>);
static_assert(std::is_trivially_copyable_v<double4x4>);
static_assert(std::is_standard_layout_v<double4x4>);
static_assert(sizeof(filament::math::mat4) == 16 * sizeof(double));
static_assert(sizeof(double4x4) == sizeof(filament::math::mat4));
static_assert(offsetof(double4x4, col1) == 0);
static_assert(offsetof(double4x4, col2) == 4 * sizeof(double));
static_assert(offsetof(double4x4, col3) == 8 * sizeof(double));
static_assert(offsetof(double4x4, col4) == 12 * sizeof(double));

static filament::math::mat4 load_mat4(const double* values)
{
    filament::math::mat4 result(filament::math::mat4::NO_INIT);
    std::memcpy(&result, values, sizeof(result));
    return result;
}

static void store_mat4(const filament::math::mat4& matrix, double* values)
{
    std::memcpy(values, &matrix, sizeof(matrix));
}

static double4x4 convert_mat4_to_double4x4(const filament::math::mat4 &mat)
{
    double4x4 result;
    std::memcpy(&result, &mat, sizeof(result));
    return result;
}

static filament::math::mat4 convert_double4x4_to_mat4(const double4x4 &d_mat)
{
    filament::math::mat4 result(filament::math::mat4::NO_INIT);
    std::memcpy(&result, &d_mat, sizeof(result));
    return result;
}
}
