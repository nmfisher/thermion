#pragma once
#include <cstddef>
#include <cmath>
#include <cstring>
#include <limits>
#include <type_traits>
#include <math/mat4.h>
#include <math/mat3.h>
#include <math/quat.h>
#include <math/vec3.h>
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

// ---------------------------------------------------------------------------
// Matrix TRS decomposition/composition.
//
// Hoisted from Filament's gltfio/math.h (Apache-2.0) so that core
// translation units such as TTransformManager.cpp do not include a gltfio
// header. They are header-only inline functions, so this still contributes
// no link-time reference in any build; the copies below are byte-for-byte
// the same arithmetic as the gltfio originals.
// ---------------------------------------------------------------------------
inline void decomposeMatrix(const filament::math::mat4f& mat, filament::math::float3* translation,
        filament::math::quatf* rotation, filament::math::float3* scale) {
    using namespace filament::math;

    // Extract translation.
    *translation = mat[3].xyz;

    // Extract upper-left for determinant computation.
    const float a = mat[0][0];
    const float b = mat[0][1];
    const float c = mat[0][2];
    const float d = mat[1][0];
    const float e = mat[1][1];
    const float f = mat[1][2];
    const float g = mat[2][0];
    const float h = mat[2][1];
    const float i = mat[2][2];
    const float A = e * i - f * h;
    const float B = f * g - d * i;
    const float C = d * h - e * g;

    // Extract scale.
    const float det(a * A + b * B + c * C);
    float scalex = length(float3({a, b, c}));
    float scaley = length(float3({d, e, f}));
    float scalez = length(float3({g, h, i}));
    float3 s = { scalex, scaley, scalez };
    if (det < 0) {
        s = -s;
    }
    *scale = s;

    // Remove scale from the matrix if it is not close to zero.
    mat4f clone = mat;
    if (std::abs(det) > std::numeric_limits<float>::epsilon()) {
        clone[0] /= s.x;
        clone[1] /= s.y;
        clone[2] /= s.z;
        // Extract rotation
        *rotation = clone.toQuaternion();
    } else {
        // Set to identity if close to zero
        *rotation = quatf(1.0f);
    }
}

inline filament::math::mat4f composeMatrix(const filament::math::float3& translation,
        const filament::math::quatf& rotation, const filament::math::float3& scale) {
    float tx = translation[0];
    float ty = translation[1];
    float tz = translation[2];
    float qx = rotation[0];
    float qy = rotation[1];
    float qz = rotation[2];
    float qw = rotation[3];
    float sx = scale[0];
    float sy = scale[1];
    float sz = scale[2];
    return filament::math::mat4f(
        (1 - 2 * qy*qy - 2 * qz*qz) * sx,
        (2 * qx*qy + 2 * qz*qw) * sx,
        (2 * qx*qz - 2 * qy*qw) * sx,
        0.f,
        (2 * qx*qy - 2 * qz*qw) * sy,
        (1 - 2 * qx*qx - 2 * qz*qz) * sy,
        (2 * qy*qz + 2 * qx*qw) * sy,
        0.f,
        (2 * qx*qz + 2 * qy*qw) * sz,
        (2 * qy*qz - 2 * qx*qw) * sz,
        (1 - 2 * qx*qx - 2 * qy*qy) * sz,
        0.f, tx, ty, tz, 1.f);
}
}
