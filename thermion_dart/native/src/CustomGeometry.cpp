#include "math.h"
#include <filament/Engine.h>
#include <filament/Frustum.h>
#include <filament/RenderableManager.h>
#include <filament/Texture.h>
#include <filament/TransformManager.h>
#include <filament/Viewport.h>
#include <filament/geometry/SurfaceOrientation.h>
#include <vector>

#include "CustomGeometry.hpp"
#include "Log.hpp"


namespace thermion {

using namespace filament;

CustomGeometry::CustomGeometry(float *vertices, uint32_t numVertices,
                               float *normals, uint32_t numNormals, float *uvs,
                               uint32_t numUvs, uint16_t *indices,
                               uint32_t numIndices,
                               RenderableManager::PrimitiveType primitiveType,
                               Engine *engine)
    : numVertices(numVertices), numIndices(numIndices), _engine(engine) {
  this->primitiveType = primitiveType;
  this->vertices = new float[numVertices];
  std::memcpy(this->vertices, vertices, numVertices * sizeof(float));

  if (numNormals > 0) {
    this->normals = new float[numNormals];
    std::memcpy(this->normals, normals, numNormals * sizeof(float));
  }

  if (numUvs > 0) {
    this->uvs = new float[numUvs];
    std::memcpy(this->uvs, uvs, numUvs * sizeof(float));
  } else {
    this->uvs = nullptr;
  }

  this->indices = new uint16_t[numIndices];
  std::memcpy(this->indices, indices, numIndices * sizeof(uint16_t));

  computeBoundingBox();
}

IndexBuffer *CustomGeometry::indexBuffer() const {
  IndexBuffer::BufferDescriptor::Callback indexCallback = [](void *buf, size_t,
                                                             void *data) {
    //   free((void *)buf);
  };

  auto indexBuffer = IndexBuffer::Builder()
                         .indexCount(numIndices)
                         .bufferType(IndexBuffer::IndexType::USHORT)
                         .build(*_engine);

  indexBuffer->setBuffer(*_engine,
                         IndexBuffer::BufferDescriptor(
                             this->indices,
                             indexBuffer->getIndexCount() * sizeof(uint16_t),
                             indexCallback));
  return indexBuffer;
}

VertexBuffer *CustomGeometry::vertexBuffer() const {
  VertexBuffer::BufferDescriptor::Callback vertexCallback =
      [](void *buf, size_t, void *data) {
        //   free((void *)buf);
      };

  // Use provided UVs or create dummy UV data
  std::vector<filament::math::float2> *uvData;
  if (this->uvs != nullptr) {
    uvData = new std::vector<filament::math::float2>(
        (filament::math::float2 *)this->uvs,
        (filament::math::float2 *)(this->uvs + numVertices * 2));
  } else {
    uvData = new std::vector<filament::math::float2>(
        numVertices, filament::math::float2{0.0f, 0.0f});
  }

  // Create dummy vertex color data (white color for all vertices)
  auto dummyColors = new std::vector<filament::math::float4>(
      numVertices, filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});

  auto vertexBufferBuilder =
      VertexBuffer::Builder()
          .vertexCount(numVertices)
          .attribute(VertexAttribute::POSITION, 0,
                     VertexBuffer::AttributeType::FLOAT3)
          .attribute(VertexAttribute::UV0, 1,
                     VertexBuffer::AttributeType::FLOAT2)
          .attribute(VertexAttribute::UV1, 2,
                     VertexBuffer::AttributeType::FLOAT2)
          .attribute(VertexAttribute::COLOR, 3,
                     VertexBuffer::AttributeType::FLOAT4);

  if (this->normals) {
    vertexBufferBuilder.bufferCount(5).attribute(
        VertexAttribute::TANGENTS, 4,
        filament::VertexBuffer::AttributeType::FLOAT4);
  } else {
    vertexBufferBuilder = vertexBufferBuilder.bufferCount(4);
  }
  auto vertexBuffer = vertexBufferBuilder.build(*_engine);

  vertexBuffer->setBufferAt(
      *_engine, 0,
      VertexBuffer::BufferDescriptor(
          this->vertices, vertexBuffer->getVertexCount() * sizeof(math::float3),
          vertexCallback));

  // Set UV0 buffer
  vertexBuffer->setBufferAt(
      *_engine, 1,
      VertexBuffer::BufferDescriptor(
          uvData->data(), uvData->size() * sizeof(math::float2),
          [](void *buf, size_t, void *data) {
            delete static_cast<std::vector<math::float2> *>(data);
          },
          uvData));

  // Set UV1 buffer (reusing UV0 data)
  vertexBuffer->setBufferAt(*_engine, 2,
                            VertexBuffer::BufferDescriptor(
                                uvData->data(),
                                uvData->size() * sizeof(math::float2),
                                [](void *buf, size_t, void *data) {
                                  // Do nothing here, as we're reusing the same
                                  // data as UV0
                                },
                                nullptr));

  // Set vertex color buffer
  vertexBuffer->setBufferAt(
      *_engine, 3,
      VertexBuffer::BufferDescriptor(
          dummyColors->data(), dummyColors->size() * sizeof(math::float4),
          [](void *buf, size_t, void *data) {
            delete static_cast<std::vector<math::float4> *>(data);
          },
          dummyColors));

  if (this->normals) {

    assert(this->primitiveType == RenderableManager::PrimitiveType::TRIANGLES);
    std::vector<filament::math::ushort3> triangles;
    for (int i = 0; i < numIndices; i += 3) {
      filament::math::ushort3 triangle;
      triangle.x = this->indices[i];
      triangle.y = this->indices[i + 1];
      triangle.z = this->indices[i + 2];
      triangles.push_back(triangle);
    }

    // Create a SurfaceOrientation builder
    geometry::SurfaceOrientation::Builder builder;
    builder.vertexCount(numVertices)
        .normals((filament::math::float3 *)normals)
        .positions((filament::math::float3 *)this->vertices)
        .triangleCount(triangles.size())
        .triangles(triangles.data());

    // Build the SurfaceOrientation object
    auto orientation = builder.build();

    // Retrieve the quaternions
    auto quats = new std::vector<filament::math::quatf>(numVertices);
    orientation->getQuats(quats->data(), numVertices);

    vertexBuffer->setBufferAt(*_engine, 4,
                              VertexBuffer::BufferDescriptor(
                                  quats->data(),
                                  quats->size() * sizeof(math::quatf),
                                  [](void *buf, size_t, void *data) {
                                    delete (std::vector<math::quatf> *)data;
                                  },
                                  (void *)quats));
  }
  return vertexBuffer;
}

CustomGeometry::~CustomGeometry() {
  delete[] vertices;
  delete[] indices;
  if (normals)
    delete[] normals;
  if (uvs)
    delete[] uvs;
}

void CustomGeometry::computeBoundingBox() {
  float minX = FLT_MAX, minY = FLT_MAX, minZ = FLT_MAX;
  float maxX = -FLT_MAX, maxY = -FLT_MAX, maxZ = -FLT_MAX;

  for (uint32_t i = 0; i < numVertices; i += 3) {
    minX = std::min(vertices[i], minX);
    minY = std::min(vertices[i + 1], minY);
    minZ = std::min(vertices[i + 2], minZ);
    maxX = std::max(vertices[i], maxX);
    maxY = std::max(vertices[i + 1], maxY);
    maxZ = std::max(vertices[i + 2], maxZ);
  }

  boundingBox = Box{{minX, minY, minZ}, {maxX, maxY, maxZ}};
}

Box CustomGeometry::getBoundingBox() const { return boundingBox; }

} // namespace thermion