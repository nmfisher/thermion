import 'dart:io';
import 'dart:math';

import 'dart:typed_data';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:test/test.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math_64.dart';

/// Test files are run in a variety of ways, find this package root in all.
///
/// Test files can be run from source from any working directory. The Dart SDK
/// `tools/test.py` runs them from the root of the SDK for example.
///
/// Test files can be run from dill from the root of package. `package:test`
/// does this.
Uri findPackageRoot(String packageName) {
  final script = Platform.script;
  final fileName = script.name;
  if (fileName.endsWith('_test.dart')) {
    // We're likely running from source.
    var directory = script.resolve('.');
    while (true) {
      final dirName = directory.name;
      if (dirName == packageName) {
        return directory;
      }
      final parent = directory.resolve('..');
      if (parent == directory) break;
      directory = parent;
    }
  } else if (fileName.endsWith('.dill')) {
    final cwd = Directory.current.uri;
    final dirName = cwd.name;
    if (dirName == packageName) {
      return cwd;
    }
  }
  throw StateError("Could not find package root for package '$packageName'. "
      'Tried finding the package root via Platform.script '
      "'${Platform.script.toFilePath()}' and Directory.current "
      "'${Directory.current.uri.toFilePath()}'.");
}

extension on Uri {
  String get name => pathSegments.where((e) => e != '').last;
}

late String testDir;

Future<void> pixelBufferToBmp(
    Uint8List pixelBuffer, int width, int height, String outputPath) async {
  // BMP file header (14 bytes)
  final fileHeader = ByteData(14);
  fileHeader.setUint16(0, 0x4D42, Endian.little); // 'BM'
  final fileSize = 54 + width * height * 3; // 54 bytes header + RGB data
  fileHeader.setUint32(2, fileSize, Endian.little);
  fileHeader.setUint32(10, 54, Endian.little); // Offset to pixel data

  // BMP info header (40 bytes)
  final infoHeader = ByteData(40);
  infoHeader.setUint32(0, 40, Endian.little); // Info header size
  infoHeader.setInt32(4, width, Endian.little);
  infoHeader.setInt32(8, -height, Endian.little); // Negative for top-down
  infoHeader.setUint16(12, 1, Endian.little); // Number of color planes
  infoHeader.setUint16(14, 24, Endian.little); // Bits per pixel (RGB)
  infoHeader.setUint32(16, 0, Endian.little); // No compression
  infoHeader.setUint32(20, width * height * 3, Endian.little); // Image size
  infoHeader.setInt32(24, 2835, Endian.little); // X pixels per meter
  infoHeader.setInt32(28, 2835, Endian.little); // Y pixels per meter

  // Calculate row size and padding
  final rowSize = (width * 3 + 3) & ~3;
  final padding = rowSize - (width * 3);

  // Pixel data (BMP stores in BGR format)
  final bmpData = Uint8List(rowSize * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final srcIndex = (y * width + x) * 4; // RGBA format
      final dstIndex = y * rowSize + x * 3; // BGR format
      bmpData[dstIndex] = pixelBuffer[srcIndex + 2]; // Blue
      bmpData[dstIndex + 1] = pixelBuffer[srcIndex + 1]; // Green
      bmpData[dstIndex + 2] = pixelBuffer[srcIndex]; // Red
      // Alpha channel is discarded
    }
    // Add padding to the end of each row
    for (var p = 0; p < padding; p++) {
      bmpData[y * rowSize + width * 3 + p] = 0;
    }
  }

  // Write BMP file
  final file = File(outputPath);
  final sink = file.openWrite();
  sink.add(fileHeader.buffer.asUint8List());
  sink.add(infoHeader.buffer.asUint8List());
  sink.add(bmpData);
  await sink.close();

  print('BMP image saved to: $outputPath');
}

final viewportDimensions = (width: 500, height: 500);
void main() async {
  final packageUri = findPackageRoot('thermion_dart');
  testDir = Directory("${packageUri.toFilePath()}/test").path;
  final lib = ThermionDartTexture1(DynamicLibrary.open(
      '${packageUri.toFilePath()}/native/lib/macos/swift/libthermion_swift.dylib'));
  final object = ThermionDartTexture.new1(lib);
  object.initWithWidth_height_(
      viewportDimensions.width, viewportDimensions.height);

  final resourceLoader = calloc<ResourceLoaderWrapper>(1);
  var loadToOut = NativeCallable<
      Void Function(Pointer<Char>,
          Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);

  resourceLoader.ref.loadToOut = loadToOut.nativeFunction;
  var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
      DartResourceLoader.freeResource);
  resourceLoader.ref.freeResource = freeResource.nativeFunction;

  var viewer = ThermionViewerFFI(resourceLoader: resourceLoader.cast<Void>());

  await viewer.initialized;
  await viewer.createSwapChain(viewportDimensions.width.toDouble(),
      viewportDimensions.height.toDouble());
  await viewer.createRenderTarget(viewportDimensions.width.toDouble(),
      viewportDimensions.height.toDouble(), object.metalTextureAddress);
  await viewer.updateViewportAndCameraProjection(
      viewportDimensions.width.toDouble(),
      viewportDimensions.height.toDouble());

  var outDir = Directory("$testDir/output");

  // outDir.deleteSync(recursive: true);
  outDir.createSync();

  Future _capture(String outputFilename) async {
    var outPath = p.join(outDir.path, "$outputFilename.bmp");
    var pixelBuffer = await viewer.capture();
    await pixelBufferToBmp(pixelBuffer, viewportDimensions.width,
        viewportDimensions.height, outPath);
  }

  group('background', () {
    test('set background color to solid green', () async {
      await viewer.setRendering(true);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await _capture("bgcolor");
      await viewer.setRendering(false);
    });

    test('load skybox', () async {
      var outDir = Directory("$testDir/skybox");
      outDir.createSync();
      await viewer.setRendering(true);
      await viewer.loadSkybox(
          "file:///$testDir/../../examples/assets/default_env/default_env_skybox.ktx");
      await Future.delayed(Duration(seconds: 1));
      await _capture("skybox");
      await viewer.setRendering(false);
    });
  });

  group("gltf", () {
    test('load glb', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("load_glb");
      await viewer.setRendering(false);
    });

    test('create instance from glb when keepData is true', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
      await viewer.transformToUnitCube(model);
      var instance = await viewer.createInstance(model);
      await viewer.setPosition(instance, 0.5, 0.5, -0.5);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("glb_create_instance");
      await viewer.setRendering(false);
    });

    test('create instance from glb fails when keepData is false', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb", keepData: false);
      bool thrown = false;
      try {
        await viewer.createInstance(model);
      } catch (err) {
        thrown = true;
      }
      expect(thrown, true);
    });
  });

  group('Skinning & animations', () {
    test('get bone names', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var names = await viewer.getBoneNames(model);
      expect(names.first, "Bone");
    });

    test('reset bones', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      await viewer.resetBones(model);
    });
    test('set from BVH', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var animation = BVHParser.parse(
          File("$testDir/assets/animation.bvh").readAsStringSync(),
          boneRegex: RegExp(r"Bone$"));
      await viewer.addBoneAnimation(model, animation);
    });

    test('fade in/out', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var animation = BVHParser.parse(
          File("$testDir/assets/animation.bvh").readAsStringSync(),
          boneRegex: RegExp(r"Bone$"));
      await viewer.addBoneAnimation(model, animation,
          fadeInInSecs: 0.5, fadeOutInSecs: 0.5);
      await Future.delayed(Duration(seconds: 1));
    });

    test('create geometry', () async {
      // Define the vertices of the cube
      List<double> vertices = [
        // Front face
        -1, -1, 1,
        1, -1, 1,
        1, 1, 1,
        -1, 1, 1,

        // Back face
        -1, -1, -1,
        -1, 1, -1,
        1, 1, -1,
        1, -1, -1,

        // Top face
        -1, 1, -1,
        -1, 1, 1,
        1, 1, 1,
        1, 1, -1,

        // Bottom face
        -1, -1, -1,
        1, -1, -1,
        1, -1, 1,
        -1, -1, 1,

        // Right face
        1, -1, -1,
        1, 1, -1,
        1, 1, 1,
        1, -1, 1,

        // Left face
        -1, -1, -1,
        -1, -1, 1,
        -1, 1, 1,
        -1, 1, -1,
      ];

      // Define the indices for the cube
      List<int> indices = [
        0, 1, 2, 0, 2, 3, // Front face
        4, 5, 6, 4, 6, 7, // Back face
        8, 9, 10, 8, 10, 11, // Top face
        12, 13, 14, 12, 14, 15, // Bottom face
        16, 17, 18, 16, 18, 19, // Right face
        20, 21, 22, 20, 22, 23 // Left face
      ];
      await viewer.createIbl(1.0, 1.0, 1.0, 1000);
      await viewer.setCameraPosition(0, 0.5, 6);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setRendering(true);

      // Create the cube geometry
      await viewer.createGeometry(vertices, indices,
          primitiveType: PrimitiveType.TRIANGLES);

      await _capture("geometry_cube");
      await viewer.setRendering(false);
    });

    test('create sphere', () async {
      // Define the parameters for the sphere
      int latitudeBands = 30;
      int longitudeBands = 30;
      double radius = 1.0;

      List<double> vertices = [];
      List<int> indices = [];

      // Generate vertices
      for (int latNumber = 0; latNumber <= latitudeBands; latNumber++) {
        double theta = latNumber * pi / latitudeBands;
        double sinTheta = sin(theta);
        double cosTheta = cos(theta);

        for (int longNumber = 0; longNumber <= longitudeBands; longNumber++) {
          double phi = longNumber * 2 * pi / longitudeBands;
          double sinPhi = sin(phi);
          double cosPhi = cos(phi);

          double x = cosPhi * sinTheta;
          double y = cosTheta;
          double z = sinPhi * sinTheta;

          vertices.addAll([radius * x, radius * y, radius * z]);
        }
      }

      // Generate indices
      for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
        for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
          int first = (latNumber * (longitudeBands + 1)) + longNumber;
          int second = first + longitudeBands + 1;

          indices.addAll(
              [first, second, first + 1, second, second + 1, first + 1]);
        }
      }

      await viewer.createIbl(1.0, 1.0, 1.0, 1000);
      await viewer.setCameraPosition(0, 0.5, 10);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setRendering(true);

      // Create the sphere geometry
      // final sphere = await viewer.createGeometry(vertices, indices,
      //     primitiveType: PrimitiveType.TRIANGLES);

      // await viewer.gizmo!.attach(sphere);
      // await viewer.setPosition(sphere, -1.0, 0.0, -10.0);
      // await viewer.setRotationQuat(
      //     sphere, Quaternion.axisAngle(Vector3(1, 0, 0), pi / 8));
      await _capture("geometry_sphere");
      await viewer.setRendering(false);
    });

    test('enable grid overlay', () async {
      await viewer.setBackgroundColor(0, 0, 0, 1);
      await viewer.setCameraPosition(0, 0.5, 0);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.1));
      await viewer.setRendering(true);
      await viewer.setLayerEnabled(2, true);
      await _capture("grid");
      await viewer.setRendering(false);
    });

    test('point light', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      var light = await viewer.addLight(
          LightType.POINT, 6500, 1000000, 0, 2, 0, 0, -1, 0,
          falloffRadius: 10.0);
      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("point_light");
      await viewer.setRendering(false);
    });

    test('set point light position', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      var light = await viewer.addLight(
          LightType.POINT, 6500, 1000000, 0, 2, 0, 0, -1, 0,
          falloffRadius: 10.0);
      await viewer.setLightPosition(light, 0.5, 2, 0);
      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("move_point_light");
      await viewer.setRendering(false);
    });

    test('directional light', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("directional_light");
      await viewer.setRendering(false);
    });

    test('set directional light direction', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
      await viewer.setLightDirection(light, Vector3(-1, -1, -1));
      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setRendering(true);
      await _capture("set_directional_light_direction");
      await viewer.setRendering(false);
    });

    test('set stencil highlight', () async {
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      await viewer.setPostProcessing(true);

      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
      await viewer.setLightDirection(light, Vector3(-1, -1, -1));

      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await viewer.setStencilHighlight(model);
      await viewer.setRendering(true);
      await Future.delayed(Duration(milliseconds: 500));
      await _capture("stencil_highlight");
      await viewer.setRendering(false);
    });
  });
}
