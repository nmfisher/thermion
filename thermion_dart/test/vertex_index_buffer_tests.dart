import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("vertex_index_buffer");
  await testHelper.setup();
  group("VertexBufferBuilder tests", () {
    test('create and build simple vertex buffer', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create a simple vertex buffer with 3 vertices
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);

        final vertexBuffer = await vbBuilder.build();

        await testHelper.capture(result.viewer.view, "vertex_buffer");

        // Verify vertex count
        expect(vertexBuffer.getVertexCount(), equals(3));

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('vertex buffer with position and UV attributes', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with position and UV in separate buffers
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(2)
          ..vertexCount(4)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
          ..attribute(VertexAttribute.UV0, 1, VertexAttributeType.FLOAT2);

        final vertexBuffer = await vbBuilder.build();

        expect(vertexBuffer.getVertexCount(), equals(4));

        // Upload position data
        final positions = Float32List.fromList([
          0.0, 0.0, 0.0, // vertex 0
          1.0, 0.0, 0.0, // vertex 1
          1.0, 1.0, 0.0, // vertex 2
          0.0, 1.0, 0.0, // vertex 3
        ]);
        await vertexBuffer.setBufferAt(0, positions);

        // Upload UV data
        final uvs = Float32List.fromList([
          0.0, 0.0, // vertex 0
          1.0, 0.0, // vertex 1
          1.0, 1.0, // vertex 2
          0.0, 1.0, // vertex 3
        ]);
        await vertexBuffer.setBufferAt(1, uvs);

        await testHelper.capture(
            result.viewer.view, "vertex_buffer_uv_attributes");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('interleaved vertex buffer (position + UV)', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create interleaved buffer: position (12 bytes) + UV (8 bytes) = 20 bytes per vertex
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3,
              byteOffset: 0, byteStride: 20)
          ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2,
              byteOffset: 12, byteStride: 20);

        final vertexBuffer = await vbBuilder.build();

        await testHelper.capture(
            result.viewer.view, "interleaved_vertex_buffer");

        // Interleaved data: X, Y, Z, U, V repeated
        final interleavedData = Float32List.fromList([
          // vertex 0: position XYZ, UV
          -0.5, -0.5, 0.0, 0.0, 0.0,
          // vertex 1: position XYZ, UV
          0.5, -0.5, 0.0, 1.0, 0.0,
          // vertex 2: position XYZ, UV
          0.0, 0.5, 0.0, 0.5, 1.0,
        ]);

        await vertexBuffer.setBufferAt(0, interleavedData);

        expect(vertexBuffer.getVertexCount(), equals(3));

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('vertex buffer with color attribute', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with position and color
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(2)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
          ..attribute(VertexAttribute.COLOR, 1, VertexAttributeType.FLOAT4);

        final vertexBuffer = await vbBuilder.build();

        await testHelper.capture(
            result.viewer.view, "vertex_buffer_color_attribute");

        // Upload positions
        final positions = Float32List.fromList([
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.5,
          1.0,
          0.0,
        ]);
        await vertexBuffer.setBufferAt(0, positions);

        // Upload colors (RGBA)
        final colors = Float32List.fromList([
          1.0, 0.0, 0.0, 1.0, // red
          0.0, 1.0, 0.0, 1.0, // green
          0.0, 0.0, 1.0, 1.0, // blue
        ]);
        await vertexBuffer.setBufferAt(1, colors);

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('normalized attribute (UBYTE color)', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with normalized UBYTE4 color
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.COLOR, 0, VertexAttributeType.UBYTE4)
          ..normalized(VertexAttribute.COLOR, normalize: true);

        final vertexBuffer = await vbBuilder.build();

        // Upload UBYTE colors (will be normalized to 0-1 range by GPU)
        final colors = Uint8List.fromList([
          255, 0, 0, 255, // red
          0, 255, 0, 255, // green
          0, 0, 255, 255, // blue
        ]);
        await vertexBuffer.setBufferAt(0, colors);

        await testHelper.capture(result.viewer.view, "normalized_ubyte_color");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('builder reuse throws error', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);

        // Build once
        final vertexBuffer1 = await vbBuilder.build();

        // Try to build again - should throw
        expect(() async => await vbBuilder.build(), throwsA(isA<StateError>()));

        await testHelper.capture(result.viewer.view, "vertex_buffer_builder_reuse");

        // Cleanup
        await vertexBuffer1.destroy();
      });
    });
  });

  group("IndexBufferBuilder tests", () {
    test('create and build simple index buffer (USHORT)', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create index buffer with USHORT indices
        final ibBuilder = renderableManager.createIndexBufferBuilder()
          ..indexCount(3)
          ..bufferType(IndexType.USHORT);

        final indexBuffer = await ibBuilder.build();

        expect(indexBuffer.getIndexCount(), equals(3));

        // Upload index data
        final indices = Uint16List.fromList([0, 1, 2]);
        await indexBuffer.setBuffer(indices);

        await testHelper.capture(result.viewer.view, "index_buffer_ushort");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('index buffer with UINT type', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create index buffer with UINT indices
        final ibBuilder = renderableManager.createIndexBufferBuilder()
          ..indexCount(6)
          ..bufferType(IndexType.UINT);

        final indexBuffer = await ibBuilder.build();

        expect(indexBuffer.getIndexCount(), equals(6));

        // Upload index data for 2 triangles
        final indices = Uint32List.fromList([0, 1, 2, 2, 3, 0]);
        await indexBuffer.setBuffer(indices);

        await testHelper.capture(result.viewer.view, "index_buffer_uint");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('large index buffer', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create a large index buffer
        final indexCount = 30000; // 10,000 triangles
        final ibBuilder = renderableManager.createIndexBufferBuilder()
          ..indexCount(indexCount)
          ..bufferType(IndexType.USHORT);

        final indexBuffer = await ibBuilder.build();

        expect(indexBuffer.getIndexCount(), equals(indexCount));

        // Generate index data
        final indices = Uint16List(indexCount);
        for (int i = 0; i < indexCount; i++) {
          indices[i] = i % 10000; // Reuse vertices
        }
        await indexBuffer.setBuffer(indices);

        await testHelper.capture(result.viewer.view, "large_index_buffer");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('builder reuse throws error', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        final ibBuilder = renderableManager.createIndexBufferBuilder()
          ..indexCount(3)
          ..bufferType(IndexType.USHORT);

        // Build once
        final indexBuffer1 = await ibBuilder.build();

        // Try to build again - should throw
        expect(() async => await ibBuilder.build(), throwsA(isA<StateError>()));

        await testHelper.capture(result.viewer.view, "index_buffer_builder_reuse");

        // Cleanup
        await indexBuffer1.destroy();
      });
    });
  });

  group("Integration tests - Simple shapes", () {
    test('render triangle with custom vertex/index buffers', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kBlue)
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3,
                      byteOffset: 0, byteStride: 20)
                  ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2,
                      byteOffset: 12, byteStride: 20))
                .build();

        // Create index buffer
        final indexBuffer = await (renderableManager.createIndexBufferBuilder()
              ..indexCount(3)
              ..bufferType(IndexType.USHORT))
            .build();

        // Upload interleaved vertex data
        final vertexData = Float32List.fromList([
          // vertex 0: position XYZ, UV
          -0.5, -0.5, 0.0, 0.0, 0.0,
          // vertex 1: position XYZ, UV
          0.5, -0.5, 0.0, 1.0, 0.0,
          // vertex 2: position XYZ, UV
          0.0, 0.5, 0.0, 0.5, 1.0,
        ]);
        await vertexBuffer.setBufferAt(0, vertexData);

        // Upload index data
        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        // Create material
        final material = await app.createUnlitMaterialInstance();
        await material.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);

        // Create entity and renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(
              Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(
              0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material)
          ..castShadows(false)
          ..receiveShadows(false);

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        // Add to scene

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        // Capture
        await testHelper.capture(result.viewer.view, "triangle_custom_buffers");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });

    test('render quad with custom vertex/index buffers', () async {
      final builder = ViewerBuilder(testHelper)
          .setRenderTargetEnabled(true)
          .setBackgroundColor(kGrey);

      await builder.execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer for quad (4 vertices)
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(2)
                  ..vertexCount(4)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
                  ..attribute(VertexAttribute.UV0, 1, VertexAttributeType.FLOAT2))
                .build();

        // Create index buffer for 2 triangles
        final indexBuffer = await (renderableManager.createIndexBufferBuilder()
              ..indexCount(6)
              ..bufferType(IndexType.USHORT))
            .build();

        // Upload vertex positions
        final positions = Float32List.fromList([
          -0.5, -0.5, 0.0, // bottom-left
          0.5, -0.5, 0.0, // bottom-right
          0.5, 0.5, 0.0, // top-right
          -0.5, 0.5, 0.0, // top-left
        ]);
        await vertexBuffer.setBufferAt(0, positions);

        // Upload UVs
        final uvs = Float32List.fromList([
          0.0,
          0.0,
          1.0,
          0.0,
          1.0,
          1.0,
          0.0,
          1.0,
        ]);
        await vertexBuffer.setBufferAt(1, uvs);

        // Upload indices (2 triangles forming a quad)
        await indexBuffer.setBuffer(Uint16List.fromList([
          0, 1, 2, // first triangle
          2, 3, 0, // second triangle
        ]));

        // Create material
        final material = await app.createUnlitMaterialInstance();
        await material.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

        // Create renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(
              Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(
              0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 6)
          ..material(0, material);

        await renderableBuilder.build(entity);
        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        // Capture
        await testHelper.capture(result.viewer.view, "quad_custom_buffers");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });
  });

  //   test('colored triangle with vertex colors', () async {
  //     final builder = ViewerBuilder(testHelper)
  //         .setRenderTargetEnabled(true)
  //         .setBackgroundColor(kWhite);

  //     await builder.execute((result) async {
  //       final app = FilamentApp.instance!;
  //       final renderableManager = app.renderableManager;

  //       // Create vertex buffer with position and color
  //       final vertexBuffer = await (renderableManager.createVertexBufferBuilder()
  //             ..bufferCount(2)
  //             ..vertexCount(3)
  //             ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
  //             ..attribute(VertexAttribute.COLOR, 1, VertexAttributeType.FLOAT4))
  //           .build();

  //       final indexBuffer = await (renderableManager.createIndexBufferBuilder()
  //             ..indexCount(3)
  //             ..bufferType(IndexType.USHORT))
  //           .build();

  //       // Upload positions
  //       await vertexBuffer.setBufferAt(
  //           0,
  //           Float32List.fromList([
  //             -0.5, -0.5, 0.0,
  //             0.5, -0.5, 0.0,
  //             0.0, 0.5, 0.0,
  //           ]));

  //       // Upload colors (RGB corners)
  //       await vertexBuffer.setBufferAt(
  //           1,
  //           Float32List.fromList([
  //             1.0, 0.0, 0.0, 1.0, // red
  //             0.0, 1.0, 0.0, 1.0, // green
  //             0.0, 0.0, 1.0, 1.0, // blue
  //           ]));

  //       await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

  //       // Create material that uses vertex colors
  //       final material = await app.createUnlitMaterialInstance();

  //       final entity = await app.createEntity();
  //       final renderableBuilder = renderableManager.createBuilder(1)
  //         ..boundingBox(
  //             Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
  //         ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
  //         ..material(0, material);

  //       await renderableBuilder.build(entity);
  //       await result.viewer.addToScene(entity);

  //       await testHelper.capture(result.viewer.view, "colored_triangle");

  //       // Cleanup
  //       await vertexBuffer.destroy();
  //       await indexBuffer.destroy();
  //     });
  //   });
  // });

  // group("Integration tests - Complex geometry", () {
  //   test('multiple attributes in single interleaved buffer', () async {
  //     final builder = ViewerBuilder(testHelper)
  //         .setRenderTargetEnabled(true)
  //         .setBackgroundColor(kGrey);

  //     await builder.execute((result) async {
  //       final app = FilamentApp.instance!;
  //       final renderableManager = app.renderableManager;

  //       // Create fully interleaved buffer: position(12) + normal(12) + UV(8) + color(16) = 48 bytes
  //       final vertexBuffer = await (renderableManager.createVertexBufferBuilder()
  //             ..bufferCount(1)
  //             ..vertexCount(3)
  //             ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3,
  //                 byteOffset: 0, byteStride: 48)
  //             ..attribute(VertexAttribute.TANGENTS, 0, VertexAttributeType.FLOAT4,
  //                 byteOffset: 12, byteStride: 48)
  //             ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2,
  //                 byteOffset: 28, byteStride: 48)
  //             ..attribute(VertexAttribute.COLOR, 0, VertexAttributeType.FLOAT4,
  //                 byteOffset: 36, byteStride: 48))
  //           .build();

  //       final indexBuffer = await (renderableManager.createIndexBufferBuilder()
  //             ..indexCount(3)
  //             ..bufferType(IndexType.USHORT))
  //           .build();

  //       // Upload interleaved data
  //       final interleavedData = Float32List.fromList([
  //         // Vertex 0: pos.xyz, tangent.xyzw (w=handedness), uv.xy, color.rgba
  //         -0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
  //         // Vertex 1
  //         0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0,
  //         // Vertex 2
  //         0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.5, 1.0, 0.0, 0.0, 1.0, 1.0,
  //       ]);

  //       await vertexBuffer.setBufferAt(0, interleavedData);
  //       await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

  //       final material = await app.createUnlitMaterialInstance();

  //       final entity = await app.createEntity();
  //       final renderableBuilder = renderableManager.createBuilder(1)
  //         ..boundingBox(
  //             Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
  //         ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
  //         ..material(0, material);

  //       await renderableBuilder.build(entity);
  //       await result.viewer.addToScene(entity);

  //       await testHelper.capture(
  //           result.viewer.view, "interleaved_all_attributes");

  //       // Cleanup
  //       await vertexBuffer.destroy();
  //       await indexBuffer.destroy();
  //     });
  //   });

  //   test('buffer reuse across multiple renderables', () async {
  //     final builder = ViewerBuilder(testHelper)
  //         .setRenderTargetEnabled(true)
  //         .setBackgroundColor(kBlue);

  //     await builder.execute((result) async {
  //       final app = FilamentApp.instance!;
  //       final renderableManager = app.renderableManager;

  //       // Create shared vertex and index buffers
  //       final sharedVertexBuffer =
  //           await (renderableManager.createVertexBufferBuilder()
  //                 ..bufferCount(1)
  //                 ..vertexCount(3)
  //                 ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
  //               .build();

  //       final sharedIndexBuffer =
  //           await (renderableManager.createIndexBufferBuilder()
  //                 ..indexCount(3)
  //                 ..bufferType(IndexType.USHORT))
  //               .build();

  //       // Upload shared data
  //       await sharedVertexBuffer.setBufferAt(
  //           0,
  //           Float32List.fromList([
  //             -0.5, -0.5, 0.0,
  //             0.5, -0.5, 0.0,
  //             0.0, 0.5, 0.0,
  //           ]));
  //       await sharedIndexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

  //       // Create 3 renderables using the same buffers
  //       final entities = <ThermionEntity>[];
  //       final materials = [kRed, kGreen, kBlue];
  //       final positions = [
  //         Vector3(-1.0, 0.0, 0.0),
  //         Vector3(0.0, 0.0, 0.0),
  //         Vector3(1.0, 0.0, 0.0)
  //       ];

  //       for (int i = 0; i < 3; i++) {
  //         final material = await app.createUnlitMaterialInstance();
  //         await material.setParameterFloat4("baseColorFactor",
  //             materials[i].r.toDouble(), materials[i].g.toDouble(), materials[i].b.toDouble(), 1.0);

  //         final entity = await app.createEntity();
  //         final renderableBuilder = renderableManager.createBuilder(1)
  //           ..boundingBox(
  //               Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
  //           ..geometry(
  //               0, PrimitiveType.TRIANGLES, sharedVertexBuffer, sharedIndexBuffer, 0, 3)
  //           ..material(0, material);

  //         await renderableBuilder.build(entity);

  //         // Position each triangle
  //         final transform = Matrix4.compose(
  //             positions[i], Quaternion.identity(), Vector3.all(1.0));
  //         await app.setTransform(entity, transform);

  //         await result.viewer.addToScene(entity);
  //         entities.add(entity);
  //       }

  //       await testHelper.capture(result.viewer.view, "shared_buffers_3_triangles");

  //       // Cleanup - buffers should still be valid after destroying renderables
  //       await sharedVertexBuffer.destroy();
  //       await sharedIndexBuffer.destroy();
  //     });
  //   });
  // });

  // group("Performance/Stress tests", () {
  //   test('large mesh (10k vertices, 30k indices)', () async {
  //     final builder = ViewerBuilder(testHelper)
  //         .setRenderTargetEnabled(true);

  //     await builder.execute((result) async {
  //       final app = FilamentApp.instance!;
  //       final renderableManager = app.renderableManager;

  //       final vertexCount = 10000;
  //       final indexCount = 30000;

  //       final stopwatch = Stopwatch()..start();

  //       // Create large vertex buffer
  //       final vertexBuffer = await (renderableManager.createVertexBufferBuilder()
  //             ..bufferCount(1)
  //             ..vertexCount(vertexCount)
  //             ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
  //           .build();

  //       print("Vertex buffer creation: ${stopwatch.elapsedMilliseconds}ms");
  //       stopwatch.reset();

  //       // Create large index buffer
  //       final indexBuffer = await (renderableManager.createIndexBufferBuilder()
  //             ..indexCount(indexCount)
  //             ..bufferType(IndexType.USHORT))
  //           .build();

  //       print("Index buffer creation: ${stopwatch.elapsedMilliseconds}ms");
  //       stopwatch.reset();

  //       // Generate vertex data (sphere-like distribution)
  //       final positions = Float32List(vertexCount * 3);
  //       for (int i = 0; i < vertexCount; i++) {
  //         final theta = (i / vertexCount) * 6.28; // 0 to 2π
  //         final phi = ((i % 100) / 100) * 3.14; // 0 to π
  //         positions[i * 3] = 0.5 * Math.sin(phi) * Math.cos(theta);
  //         positions[i * 3 + 1] = 0.5 * Math.sin(phi) * Math.sin(theta);
  //         positions[i * 3 + 2] = 0.5 * Math.cos(phi);
  //       }
  //       await vertexBuffer.setBufferAt(0, positions);

  //       print("Vertex data upload: ${stopwatch.elapsedMilliseconds}ms");
  //       stopwatch.reset();

  //       // Generate index data
  //       final indices = Uint16List(indexCount);
  //       for (int i = 0; i < indexCount; i += 3) {
  //         indices[i] = (i ~/ 3) % vertexCount;
  //         indices[i + 1] = ((i ~/ 3) + 1) % vertexCount;
  //         indices[i + 2] = ((i ~/ 3) + 2) % vertexCount;
  //       }
  //       await indexBuffer.setBuffer(indices);

  //       print("Index data upload: ${stopwatch.elapsedMilliseconds}ms");
  //       stopwatch.reset();

  //       // Create renderable
  //       final material = await app.createUnlitMaterialInstance();
  //       final entity = await app.createEntity();
  //       final renderableBuilder = renderableManager.createBuilder(1)
  //         ..boundingBox(
  //             Aabb3.minMax(Vector3(-0.5, -0.5, -0.5), Vector3(0.5, 0.5, 0.5)))
  //         ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0,
  //             indexCount)
  //         ..material(0, material);

  //       await renderableBuilder.build(entity);
  //       await result.viewer.addToScene(entity);

  //       print("Renderable creation: ${stopwatch.elapsedMilliseconds}ms");
  //       stopwatch.reset();

  //       await testHelper.capture(result.viewer.view, "large_mesh");

  //       print("Render: ${stopwatch.elapsedMilliseconds}ms");

  //       // Verify buffers were created
  //       expect(vertexBuffer.getVertexCount(), equals(vertexCount));
  //       expect(indexBuffer.getIndexCount(), equals(indexCount));

  //       // Cleanup
  //       await vertexBuffer.destroy();
  //       await indexBuffer.destroy();
  //     });
  //   }, timeout: Timeout(Duration(seconds: 30)));
  // });
}
