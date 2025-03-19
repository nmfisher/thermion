#pragma once
#include <math/mat4.h>
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

// Helper function to convert filament::math::mat4 to double4x4
static double4x4 convert_mat4_to_double4x4(const filament::math::mat4 &mat)
{
    return double4x4{
        {mat[0][0], mat[0][1], mat[0][2], mat[0][3]},
        {mat[1][0], mat[1][1], mat[1][2], mat[1][3]},
        {mat[2][0], mat[2][1], mat[2][2], mat[2][3]},
        {mat[3][0], mat[3][1], mat[3][2], mat[3][3]},
    };
}

// Helper function to convert double4x4 to filament::math::mat4
static filament::math::mat4 convert_double4x4_to_mat4(const double4x4 &d_mat)
{
    return filament::math::mat4{
        filament::math::float4{float(d_mat.col1[0]), float(d_mat.col1[1]), float(d_mat.col1[2]), float(d_mat.col1[3])},
        filament::math::float4{float(d_mat.col2[0]), float(d_mat.col2[1]), float(d_mat.col2[2]), float(d_mat.col2[3])},
        filament::math::float4{float(d_mat.col3[0]), float(d_mat.col3[1]), float(d_mat.col3[2]), float(d_mat.col3[3])},
        filament::math::float4{float(d_mat.col4[0]), float(d_mat.col4[1]), float(d_mat.col4[2]), float(d_mat.col4[3])}};
}
}