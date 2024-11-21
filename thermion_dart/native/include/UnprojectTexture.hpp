#include <filament/Engine.h>
#include <filament/Camera.h>
#include <filament/Texture.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <math/mat4.h>
#include <math/vec2.h>
#include <math/vec3.h>
#include <math/vec4.h>
#include <utils/EntityManager.h>
#include <backend/PixelBufferDescriptor.h>

#include <vector>
#include <algorithm>

#include "scene/CustomGeometry.hpp"

namespace thermion {

class UnprojectTexture {
public:
    UnprojectTexture(const CustomGeometry * geometry, Camera& camera, Engine* engine)
        : _geometry(geometry), _camera(camera), _engine(engine) {}

    void unproject(utils::Entity entity, const uint8_t* inputTexture, uint8_t* outputTexture, uint32_t inputWidth, uint32_t inputHeight,
                       uint32_t outputWidth, uint32_t outputHeight);

private:
    const CustomGeometry * _geometry;
    const Camera& _camera;
    Engine* _engine;

    math::float3 doUnproject(const math::float2& screenPos, float depth, const math::mat4& invViewProj);
    bool isInsideTriangle(const math::float2& p, const math::float2& a, const math::float2& b, const math::float2& c);
    math::float3 barycentric(const math::float2& p, const math::float2& a, const math::float2& b, const math::float2& c);
};
}