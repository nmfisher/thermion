import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';
import 'package:thermion_dart/src/filament/src/interface/surface_orientation.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_surface_orientation.dart';

void main() async {
  final testHelper = TestHelper("vertex_index_buffer");
  await testHelper.setup();
  group("VertexBufferBuilder tests", () {
    test('direct and BufferObject storage enforce their update APIs', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final manager = FilamentApp.instance!.renderableManager;

        final directBuilder = manager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);
        final direct = await directBuilder.build();
        expect(direct.storageMode, VertexBufferStorageMode.direct);

        final bufferObjectBuilder = manager.createBufferObjectBuilder()..size(3 * 3 * Float32List.bytesPerElement);
        final bufferObject = await bufferObjectBuilder.build();
        await bufferObject.setBuffer(Float32List.fromList([-1, -1, 0, 1, -1, 0, 0, 1, 0]));

        await expectLater(direct.setBufferObjectAt(0, bufferObject), throwsStateError);

        final bufferObjectVertexBuilder = manager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..enableBufferObjects()
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);
        final bufferObjectVertexBuffer = await bufferObjectVertexBuilder.build();
        expect(bufferObjectVertexBuffer.storageMode, VertexBufferStorageMode.bufferObjects);
        expect(bufferObjectVertexBuffer.supportsSetBufferAt, isFalse);
        await expectLater(bufferObjectVertexBuffer.setBufferAt(0, Float32List(9)), throwsStateError);
        await bufferObjectVertexBuffer.setBufferObjectAt(0, bufferObject);

        await bufferObjectVertexBuffer.destroy();
        await bufferObject.destroy();
        await direct.destroy();
      });
    });

    test('create and build simple vertex buffer', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create a simple vertex buffer with 3 vertices
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);

        final vertexBuffer = await vbBuilder.build();

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "vertex_buffer");

        // Verify vertex count
        expect(vertexBuffer.getVertexCount(), equals(3));

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('vertex buffer with position and UV attributes', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "vertex_buffer_uv_attributes");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('interleaved vertex buffer (position + UV)', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create interleaved buffer: position (12 bytes) + UV (8 bytes) = 20 bytes per vertex
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(1)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 20)
          ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2, byteOffset: 12, byteStride: 20);

        final vertexBuffer = await vbBuilder.build();

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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "interleaved_vertex_buffer");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('vertex buffer with color attribute', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with position and color
        final vbBuilder = renderableManager.createVertexBufferBuilder()
          ..bufferCount(2)
          ..vertexCount(3)
          ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
          ..attribute(VertexAttribute.COLOR, 1, VertexAttributeType.FLOAT4);

        final vertexBuffer = await vbBuilder.build();

        // Upload positions
        final positions = Float32List.fromList([0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 1.0, 0.0]);
        await vertexBuffer.setBufferAt(0, positions);

        // Upload colors (RGBA)
        final colors = Float32List.fromList([
          1.0, 0.0, 0.0, 1.0, // red
          0.0, 1.0, 0.0, 1.0, // green
          0.0, 0.0, 1.0, 1.0, // blue
        ]);
        await vertexBuffer.setBufferAt(1, colors);

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "vertex_buffer_color_attribute");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('normalized attribute (UBYTE color)', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "normalized_ubyte_color");

        // Cleanup
        await vertexBuffer.destroy();
      });
    });

    test('builder reuse throws error', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "index_buffer_ushort");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('index buffer with UINT type', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "index_buffer_uint");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('large index buffer', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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

        // only to flush the pipeline, this won't render anything
        await testHelper.capture(result.viewer.view, "large_index_buffer");

        // Cleanup
        await indexBuffer.destroy();
      });
    });

    test('builder reuse throws error', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
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
    test('render triangle with POSITION only', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with POSITION only
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
                .build();

        // Create index buffer
        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(3)
                  ..bufferType(IndexType.USHORT))
                .build();

        // Upload vertex data (positions only)
        final vertexData = Float32List.fromList([
          -0.5, -0.5, 0.0, // vertex 0
          0.5, -0.5, 0.0, // vertex 1
          0.0, 0.5, 0.0, // vertex 2
        ]);
        await vertexBuffer.setBufferAt(0, vertexData);

        // Upload index data
        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        // Create material using solidcolor.filamat (requires only POSITION)
        final material = await testHelper.loadSolidColorMaterial(r: 1.0, g: 0.0, b: 1.0); // Magenta

        // Create entity and renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material)
          ..castShadows(false)
          ..receiveShadows(false);

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "triangle_position_only");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });

    test('render triangle with POSITION + UV0 (interleaved)', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with interleaved POSITION + UV0
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 20)
                  ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2, byteOffset: 12, byteStride: 20))
                .build();

        // Create index buffer
        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
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

        // Create material using solidcolor.filamat (requires only POSITION)
        final material = await testHelper.loadSolidColorMaterial(r: 0.0, g: 1.0, b: 1.0); // Cyan

        // Create entity and renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material)
          ..castShadows(false)
          ..receiveShadows(false);

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "triangle_position_uv");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });

    test('render quad with custom vertex/index buffers', () async {
      final builder = ViewerBuilder(testHelper).setCameraLookAt(Vector3(1, 1, 1)).setBackgroundColor(kGrey);

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
        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
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
        final uvs = Float32List.fromList([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]);
        await vertexBuffer.setBufferAt(1, uvs);

        // Upload indices (2 triangles forming a quad)
        await indexBuffer.setBuffer(
          Uint16List.fromList([
            0, 1, 2, // first triangle
            2, 3, 0, // second triangle
          ]),
        );

        // Create material
        final material = await app.createUnlitMaterialInstance();
        await material.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);

        // Create renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 6)
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

    test('colored triangle with vertex colors', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer with position and color
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(2)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
                  ..attribute(VertexAttribute.COLOR, 1, VertexAttributeType.FLOAT4))
                .build();

        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(3)
                  ..bufferType(IndexType.USHORT))
                .build();

        // Upload positions
        await vertexBuffer.setBufferAt(0, Float32List.fromList([-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0]));

        // Upload colors (RGB corners)
        await vertexBuffer.setBufferAt(
          1,
          Float32List.fromList([
            1.0, 0.0, 0.0, 1.0, // red
            0.0, 1.0, 0.0, 1.0, // green
            0.0, 0.0, 1.0, 1.0, // blue
          ]),
        );

        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        // Create material that uses vertex colors
        final material = await app.createUbershaderMaterialInstance(hasVertexColors: true, unlit: true);
        await material.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 1.0);

        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material);

        await renderableBuilder.build(entity);
        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "colored_triangle");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });
  });

  group("Integration tests - Complex geometry", () {
    test('multiple attributes in single interleaved buffer', () async {
      final builder = ViewerBuilder(testHelper).setBackgroundColor(kGrey);

      await builder.execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create fully interleaved buffer: position(12) + normal(12) + UV(8) + color(16) = 48 bytes
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 48)
                  ..attribute(VertexAttribute.TANGENTS, 0, VertexAttributeType.FLOAT4, byteOffset: 12, byteStride: 48)
                  ..attribute(VertexAttribute.UV0, 0, VertexAttributeType.FLOAT2, byteOffset: 28, byteStride: 48)
                  ..attribute(VertexAttribute.COLOR, 0, VertexAttributeType.FLOAT4, byteOffset: 36, byteStride: 48))
                .build();

        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(3)
                  ..bufferType(IndexType.USHORT))
                .build();

        // Upload interleaved data
        final interleavedData = Float32List.fromList([
          // Vertex 0: pos.xyz, tangent.xyzw (w=handedness), uv.xy, color.rgba
          -0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
          // Vertex 1
          0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0,
          // Vertex 2
          0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.5, 1.0, 0.0, 0.0, 1.0, 1.0,
        ]);

        await vertexBuffer.setBufferAt(0, interleavedData);
        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        final material = await app.createUbershaderMaterialInstance(hasVertexColors: true, unlit: true);
        await material.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 1.0);

        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material);

        await renderableBuilder.build(entity);
        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "interleaved_all_attributes");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });

    test('buffer reuse across multiple renderables', () async {
      final builder = ViewerBuilder(testHelper).setBackgroundColor(kBlue);

      await builder.execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create shared vertex and index buffers
        final sharedVertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
                .build();

        final sharedIndexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(3)
                  ..bufferType(IndexType.USHORT))
                .build();

        // Upload shared data
        await sharedVertexBuffer.setBufferAt(0, Float32List.fromList([-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0]));
        await sharedIndexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        // Create 3 renderables using the same buffers
        final entities = <ThermionEntity>[];
        final materials = [kRed, kGreen, kBlue];
        final positions = [Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)];

        for (int i = 0; i < 3; i++) {
          final material = await app.createUnlitMaterialInstance();

          final entity = await app.createEntity();
          final renderableBuilder = renderableManager.createBuilder(1)
            ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
            ..geometry(0, PrimitiveType.TRIANGLES, sharedVertexBuffer, sharedIndexBuffer, 0, 3)
            ..material(0, material);

          await renderableBuilder.build(entity);

          // Position each triangle
          final transform = Matrix4.compose(positions[i], Quaternion.identity(), Vector3.all(1.0));
          await app.setTransform(entity, transform);

          final scene = await result.viewer.view.getScene();
          await scene.addEntity(entity);
          await material.setParameterFloat4(
            "baseColorFactor",
            materials[i].r.toDouble(),
            materials[i].g.toDouble(),
            materials[i].b.toDouble(),
            1.0,
          );

          entities.add(entity);
        }

        await testHelper.capture(result.viewer.view, "shared_buffers_3_triangles");
        await testHelper.capture(result.viewer.view, "shared_buffers_3_triangles");
        // Cleanup - buffers should still be valid after destroying renderables
        await sharedVertexBuffer.destroy();
        await sharedIndexBuffer.destroy();
      });
    });
  });

  // group("Performance/Stress tests", () {
  //   test('large mesh (10k vertices, 30k indices)', () async {
  //     final builder = ViewerBuilder(testHelper)
  //         ;

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

  group("RenderableBuilder instances tests", () {
    test('RenderableBuilder instances method', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kBlue).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Create vertex buffer
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(1)
                  ..vertexCount(3)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
                .build();

        // Create index buffer
        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(3)
                  ..bufferType(IndexType.USHORT))
                .build();

        // Upload vertex data
        await vertexBuffer.setBufferAt(0, Float32List.fromList([-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0]));

        // Upload index data
        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

        // Create material
        final material = await testHelper.loadSolidColorMaterial(r: 1.0, g: 0.0, b: 0.0);

        // Create entity and renderable with multiple instances
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3)
          ..material(0, material)
          ..instances(10); // Set 10 draw instances

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "triangle_10_instances");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });
  });

  group("SurfaceOrientationBuilder tests", () {
    test('generate tangents for simple quad', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Define a quad with positions, normals, and UVs
        final positions = Float32List.fromList([
          -0.5, -0.5, 0.0, // vertex 0
          0.5, -0.5, 0.0, // vertex 1
          0.5, 0.5, 0.0, // vertex 2
          -0.5, 0.5, 0.0, // vertex 3
        ]);

        // Face forward along +Z
        final normals = Float32List.fromList([
          0.0, 0.0, 1.0, // vertex 0
          0.0, 0.0, 1.0, // vertex 1
          0.0, 0.0, 1.0, // vertex 2
          0.0, 0.0, 1.0, // vertex 3
        ]);

        // Standard UV coordinates
        final uvs = Float32List.fromList([
          0.0, 0.0, // vertex 0
          1.0, 0.0, // vertex 1
          1.0, 1.0, // vertex 2
          0.0, 1.0, // vertex 3
        ]);

        // Triangle indices for quad (2 triangles)
        final indices = Uint32List.fromList([
          0, 1, 2, // first triangle
          2, 3, 0, // second triangle
        ]);

        // Create surface orientation builder
        final orientationBuilder = FFISurfaceOrientationBuilder()
          ..vertexCount(4)
          ..positions(positions)
          ..normals(normals)
          ..uvs(uvs)
          ..triangleCount(2)
          ..trianglesUint32(indices);

        // Build orientation
        final orientation = await orientationBuilder.build();

        // Get quaternions as float4
        final quats = await orientation.getQuats(QuaternionFormat.FLOAT4, 4) as Float32List;

        // Verify we got 4 quaternions (one per vertex)
        expect(quats.length, equals(16)); // 4 vertices * 4 components

        // Verify quaternion normalization (quaternions should be unit length)
        for (int i = 0; i < 4; i++) {
          final x = quats[i * 4];
          final y = quats[i * 4 + 1];
          final z = quats[i * 4 + 2];
          final w = quats[i * 4 + 3];
          final length = (x * x + y * y + z * z + w * w);
          // Allow for small floating point errors
          expect((length - 1.0).abs(), lessThan(0.001));
        }

        // Create vertex buffer with position + TANGENTS
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(2)
                  ..vertexCount(4)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
                  ..attribute(VertexAttribute.TANGENTS, 1, VertexAttributeType.FLOAT4))
                .build();

        // Create index buffer
        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(6)
                  ..bufferType(IndexType.UINT))
                .build();

        // Upload position data
        await vertexBuffer.setBufferAt(0, positions);

        // Upload generated tangent quaternions
        await vertexBuffer.setBufferAt(1, quats);

        // Upload index data
        await indexBuffer.setBuffer(indices);

        // Create a material that uses normals (for testing tangents)
        final material = await app.createUbershaderMaterialInstance(
          hasVertexColors: false,
          hasNormalTexture: false,
          unlit: false,
        );
        await material.setParameterFloat4("baseColorFactor", 1.0, 0.5, 0.5, 1.0); // Light red
        await material.setParameterFloat3("normalScale", 1.0, 1.0, 1.0);

        // Create entity and renderable
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 6)
          ..material(0, material)
          ..castShadows(true)
          ..receiveShadows(true);

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "quad_with_generated_tangents");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
        await orientation.destroy();
      });
    });

    test('generate tangents with different quaternion formats', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kGrey).execute((result) async {
        // Simple triangle data
        final positions = Float32List.fromList([0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 1.0, 0.0]);

        final normals = Float32List.fromList([0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0]);

        final uvs = Float32List.fromList([0.5, 0.0, 1.0, 1.0, 0.0, 1.0]);

        final indices = Uint16List.fromList([0, 1, 2]);

        // Test all quaternion formats
        for (final format in [QuaternionFormat.FLOAT4, QuaternionFormat.SHORT4, QuaternionFormat.HALF4]) {
          final orientationBuilder = FFISurfaceOrientationBuilder()
            ..vertexCount(3)
            ..positions(positions)
            ..normals(normals)
            ..uvs(uvs)
            ..triangleCount(1)
            ..trianglesUint16(indices);

          final orientation = await orientationBuilder.build();

          // Get quaternions in current format
          final quats = await orientation.getQuats(format, 3);

          // Verify size based on format
          switch (format) {
            case QuaternionFormat.FLOAT4:
              expect(quats.lengthInBytes, equals(48)); // 3 * 16 bytes
              break;
            case QuaternionFormat.SHORT4:
            case QuaternionFormat.HALF4:
              expect(quats.lengthInBytes, equals(24)); // 3 * 8 bytes
              break;
          }

          await orientation.destroy();
        }

        // Just capture something to verify test ran
        await testHelper.capture(result.viewer.view, "tangent_formats_test");
      });
    });

    test('generate flat normals from positions only', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        // Simple pyramid shape without normals
        final positions = Float32List.fromList([
          // Base vertices
          -0.5, -0.5, -0.5, // vertex 0
          0.5, -0.5, -0.5, // vertex 1
          0.5, -0.5, 0.5, // vertex 2
          -0.5, -0.5, 0.5, // vertex 3
          // Apex
          0.0, 0.5, 0.0, // vertex 4
        ]);

        // Indices for pyramid faces (4 triangular faces + base)
        final indices = Uint32List.fromList([
          // Side faces
          0, 1, 4, // front
          1, 2, 4, // right
          2, 3, 4, // back
          3, 0, 4, // left
          // Base
          0, 3, 2, // base triangle 1
          2, 1, 0, // base triangle 2
        ]);

        // Create orientation builder with positions only
        final orientationBuilder = FFISurfaceOrientationBuilder()
          ..vertexCount(5)
          ..positions(positions)
          ..triangleCount(6)
          ..trianglesUint32(indices);

        final orientation = await orientationBuilder.build();
        final quats = await orientation.getQuats(QuaternionFormat.FLOAT4, 5) as Float32List;

        // Verify we got quaternions for all vertices
        expect(quats.length, equals(20)); // 5 vertices * 4 components

        // Quaternions should be valid (not all zeros)
        for (int i = 0; i < 5; i++) {
          final sum = (quats[i * 4] + quats[i * 4 + 1] + quats[i * 4 + 2] + quats[i * 4 + 3]).abs();
          expect(sum, greaterThan(0.0));
        }

        await testHelper.capture(result.viewer.view, "pyramid_flat_normals");

        await orientation.destroy();
      });
    });

    test('tangent generation with existing tangents', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).execute((result) async {
        final positions = Float32List.fromList([0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 1.0, 0.0]);

        final normals = Float32List.fromList([0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0]);

        // Provide existing tangents (xyz direction + w handedness)
        final tangents = Float32List.fromList([
          1.0, 0.0, 0.0, 1.0, // vertex 0: tangent + handedness
          1.0, 0.0, 0.0, 1.0, // vertex 1
          1.0, 0.0, 0.0, 1.0, // vertex 2
        ]);

        final indices = Uint16List.fromList([0, 1, 2]);

        // Build orientation with existing tangents (positions are required when providing normals/tangents)
        final orientationBuilder = FFISurfaceOrientationBuilder()
          ..vertexCount(3)
          ..positions(positions)
          ..normals(normals)
          ..tangents(tangents)
          ..triangleCount(1)
          ..trianglesUint16(indices);

        final orientation = await orientationBuilder.build();
        final quats = await orientation.getQuats(QuaternionFormat.FLOAT4, 3) as Float32List;

        // Verify quaternions were generated
        expect(quats.length, equals(12));

        // The quaternions should incorporate the provided tangent data
        // (exact values depend on the internal algorithm)
        expect(quats.any((v) => v != 0.0), isTrue);

        await testHelper.capture(result.viewer.view, "triangle_with_tangents");

        await orientation.destroy();
      });
    });
  });
}
