// ignore_for_file: unused_local_variable
import 'dart:ffi';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/src/swift/swift_bindings.g.dart';
import 'package:thermion_dart/src/utils/src/dart_resources.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/src/viewer/src/ffi/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:path/path.dart' as p;

Color kWhite = ColorFloat32(4)..setRgba(1.0, 1.0, 1.0, 1.0);
Color kRed = ColorFloat32(4)..setRgba(1.0, 0.0, 0.0, 1.0);
Color kGreen = ColorFloat32(4)..setRgba(0.0, 1.0, 0.0, 1.0);
Color kBlue = ColorFloat32(4)..setRgba(0.0, 0.0, 1.0, 1.0);

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
  if (fileName.contains('_test')) {
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

Future<Uint8List> savePixelBufferToBmp(
    Uint8List pixelBuffer, int width, int height, String outputPath) async {
  var data = await pixelBufferToBmp(pixelBuffer, width, height);
  File(outputPath).writeAsBytesSync(data);
  print("Wrote bitmap to ${outputPath}");
  return data;
}

Future<Uint8List> savePixelBufferToPng(
    Uint8List pixelBuffer, int width, int height, String outputPath) async {
  var data = await pixelBufferToPng(pixelBuffer, width, height);
  File(outputPath).writeAsBytesSync(data);
  print("Wrote bitmap to ${outputPath}");
  return data;
}

class TestHelper {
  late FFISwapChain swapChain;
  late Directory outDir;
  late String testDir;

  TestHelper(String dir) {
    final packageUri = findPackageRoot('thermion_dart').toFilePath();
    testDir = Directory("${packageUri}test").path;
    outDir = Directory("$testDir/output/${dir}");
    outDir.createSync(recursive: true);
    if (Platform.isMacOS) {
      DynamicLibrary.open('${testDir}/libThermionTextureSwift.dylib');
    }
  }

  ///
  ///
  ///
  Future<Uint8List> capture(View view, String? outputFilename) async {
    final rt = await view.getRenderTarget();
    var pixelBuffer = await FilamentApp.instance!
        .capture(view, captureRenderTarget: rt != null);
    var vp = await view.getViewport();

    if (outputFilename != null) {
      var outPath = p.join(outDir.path, "$outputFilename.png");
      await savePixelBufferToPng(pixelBuffer, vp.width, vp.height, outPath);
    }

    return pixelBuffer;
  }

  ///
  ///
  ///
  Future<List<Uint8List>> captureMultiple(
    ThermionViewer viewer,
    String? outputFilename, {
    View? view,
    SwapChain? swapChain,
    RenderTarget? renderTarget,
  }) async {
    throw UnimplementedError();

    // view ??= await viewer.view;
    // final targets = [
    //   (view: view!, swapChain: swapChain, renderTarget: renderTarget)
    // ];
    // var pixelBuffers = await viewer.capture(targets);

    // for (final entry in targets) {
    //   var vp = await entry.view.getViewport();
    //   if (outputFilename != null) {
    //     var outPath = p.join(outDir.path, "$outputFilename.png");
    //     await savePixelBufferToPng(
    //         pixelBuffers[targets.indexOf(entry)], vp.width, vp.height, outPath);
    //   }
    // }
    // return pixelBuffers;
  }

  ///
  ///
  ///
  Future<ThermionTextureSwift> createTexture(int width, int height,
      {bool depth = false}) async {
    final object = ThermionTextureSwift.new1();
    object.initWithWidth_height_isDepth_(width, height, depth);
    return object;
  }

  Future setup() async {
    final resourceLoader = calloc<ResourceLoaderWrapper>(1);

    var loadToOut = NativeCallable<
        Void Function(Pointer<Char>,
            Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);

    resourceLoader.ref.loadToOut = loadToOut.nativeFunction;

    var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
        DartResourceLoader.freeResource);

    resourceLoader.ref.freeResource = freeResource.nativeFunction;
    await FFIFilamentApp.create();

    await FilamentApp.instance!.setClearColor(0, 1, 0, 1);
  }

  ///
  ///
  ///
  Future withViewer(
    Future Function(ThermionViewer viewer) fn, {
    img.Color? bg,
    Vector3? cameraPosition,
    ({int width, int height}) viewportDimensions = (width: 512, height: 512),
    bool postProcessing = false,
    bool addSkybox = false,
    bool createRenderTarget = false,
  }) async {
    cameraPosition ??= Vector3(0, 2, 6);

    var swapChain = await FilamentApp.instance!
        .createHeadlessSwapChain(viewportDimensions.width, viewportDimensions.height) as FFISwapChain;

    FFIRenderTarget? renderTarget;
    if (createRenderTarget) {
      var metalColorTexture = await createTexture(
          viewportDimensions.width, viewportDimensions.height);
      var metalDepthTexture = await createTexture(
          viewportDimensions.width, viewportDimensions.height,
          depth: true);
      var color = await FilamentApp.instance!
          .createTexture(viewportDimensions.width, viewportDimensions.height,
              flags: {
                TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                TextureUsage.TEXTURE_USAGE_SAMPLEABLE
              },
              textureFormat: TextureFormat.RGB32F,
              importedTextureHandle: metalColorTexture.metalTextureAddress);
      var width = await color.getWidth();
      var height = await color.getHeight();
      var depth = await FilamentApp.instance!
          .createTexture(viewportDimensions.width, viewportDimensions.height,
              flags: {
                TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
                TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
              },
              textureFormat: TextureFormat.DEPTH32F,
              importedTextureHandle: metalDepthTexture.metalTextureAddress);

      renderTarget = await FilamentApp.instance!.createRenderTarget(
          viewportDimensions.width, viewportDimensions.height,
          color: color, depth: depth) as FFIRenderTarget;
    }

    var viewer = ThermionViewerFFI(
        loadAssetFromUri: (path) async =>
            File(path.replaceAll("file://", "")).readAsBytesSync());

    await viewer.initialized;
    await FilamentApp.instance!.register(swapChain, viewer.view);
    if (renderTarget != null) {
      await viewer.view.setRenderTarget(renderTarget);
    }
    await viewer.view
        .setViewport(
          viewportDimensions.width,
          viewportDimensions.height
      );

    if (addSkybox) {
      await viewer
          .loadSkybox("file://${testDir}/assets/default_env_skybox.ktx");
    }

    if (bg != null) {
      await viewer.setBackgroundColor(
          bg.r.toDouble(), bg.g.toDouble(), bg.b.toDouble(), bg.a.toDouble());
    }

    final camera = await viewer.getActiveCamera();

    await camera.setLensProjection(
        near: kNear, far: kFar, aspect: 1.0, focalLength: kFocalLength);

    await camera.lookAt(cameraPosition);

    await viewer.setPostProcessing(postProcessing);

    await viewer.setToneMapping(ToneMapper.LINEAR);

    await fn.call(viewer);
    await viewer.dispose();
  }
}

Uint8List poissonBlend(List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  // Initialize the result
  List<Vector4> result = List.generate(size, (_) => Vector4(0, 0, 0, 0));
  List<bool> validPixel = List.generate(size, (_) => false);

  // Compute gradients and perform simplified Poisson blending
  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      int index = y * width + x;
      Vector4 gradX = Vector4(0, 0, 0, 0);
      Vector4 gradY = Vector4(0, 0, 0, 0);
      bool hasValidData = false;

      for (int t = 0; t < numTextures; t++) {
        int i = index * 4;
        if (textures[t][i] == 0 &&
            textures[t][i + 1] == 0 &&
            textures[t][i + 2] == 0 &&
            textures[t][i + 3] == 0) {
          continue; // Skip this texture if the pixel is empty
        }

        hasValidData = true;
        int iLeft = (y * width + x - 1) * 4;
        int iRight = (y * width + x + 1) * 4;
        int iUp = ((y - 1) * width + x) * 4;
        int iDown = ((y + 1) * width + x) * 4;

        Vector4 gx = Vector4(
            (textures[t][iRight] - textures[t][iLeft]) / 2,
            (textures[t][iRight + 1] - textures[t][iLeft + 1]) / 2,
            (textures[t][iRight + 2] - textures[t][iLeft + 2]) / 2,
            (textures[t][iRight + 3] - textures[t][iLeft + 3]) / 2);

        Vector4 gy = Vector4(
            (textures[t][iDown] - textures[t][iUp]) / 2,
            (textures[t][iDown + 1] - textures[t][iUp + 1]) / 2,
            (textures[t][iDown + 2] - textures[t][iUp + 2]) / 2,
            (textures[t][iDown + 3] - textures[t][iUp + 3]) / 2);

        // Select the gradient with larger magnitude
        double magX = gx.r * gx.r + gx.g * gx.g + gx.b * gx.b + gx.a * gx.a;
        double magY = gy.r * gy.r + gy.g * gy.g + gy.b * gy.b + gy.a * gy.a;

        if (magX >
            gradX.r * gradX.r +
                gradX.g * gradX.g +
                gradX.b * gradX.b +
                gradX.a * gradX.a) {
          gradX = gx;
        }
        if (magY >
            gradY.r * gradY.r +
                gradY.g * gradY.g +
                gradY.b * gradY.b +
                gradY.a * gradY.a) {
          gradY = gy;
        }
      }

      if (hasValidData) {
        validPixel[index] = true;
        // Simplified Poisson equation solver (Jacobi iteration)
        result[index].r = (result[index - 1].r +
                result[index + 1].r +
                result[index - width].r +
                result[index + width].r +
                gradX.r -
                gradY.r) /
            4;
        result[index].g = (result[index - 1].g +
                result[index + 1].g +
                result[index - width].g +
                result[index + width].g +
                gradX.g -
                gradY.g) /
            4;
        result[index].b = (result[index - 1].b +
                result[index + 1].b +
                result[index - width].b +
                result[index + width].b +
                gradX.b -
                gradY.b) /
            4;
        result[index].a = (result[index - 1].a +
                result[index + 1].a +
                result[index - width].a +
                result[index + width].a +
                gradX.a -
                gradY.a) /
            4;
      }
    }
  }

  // Fill in gaps and normalize
  Uint8List finalResult = Uint8List(size * 4);
  for (int i = 0; i < size; i++) {
    if (validPixel[i]) {
      finalResult[i * 4] = (result[i].r.clamp(0, 255)).toInt();
      finalResult[i * 4 + 1] = (result[i].g.clamp(0, 255)).toInt();
      finalResult[i * 4 + 2] = (result[i].b.clamp(0, 255)).toInt();
      finalResult[i * 4 + 3] = (result[i].a.clamp(0, 255)).toInt();
    } else {
      // For invalid pixels, try to interpolate from neighbors
      List<int> validNeighbors = [];
      if (i > width && validPixel[i - width]) validNeighbors.add(i - width);
      if (i < size - width && validPixel[i + width])
        validNeighbors.add(i + width);
      if (i % width > 0 && validPixel[i - 1]) validNeighbors.add(i - 1);
      if (i % width < width - 1 && validPixel[i + 1]) validNeighbors.add(i + 1);

      if (validNeighbors.isNotEmpty) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int neighbor in validNeighbors) {
          r += result[neighbor].r;
          g += result[neighbor].g;
          b += result[neighbor].b;
          a += result[neighbor].a;
        }
        finalResult[i * 4] = (r / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 1] =
            (g / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 2] =
            (b / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 3] =
            (a / validNeighbors.length).clamp(0, 255).toInt();
      } else {
        // If no valid neighbors, set to transparent black
        finalResult[i * 4] = 0;
        finalResult[i * 4 + 1] = 0;
        finalResult[i * 4 + 2] = 0;
        finalResult[i * 4 + 3] = 0;
      }
    }
  }

  return finalResult;
}

Uint8List medianImages(List<Uint8List> images) {
  if (images.isEmpty) {
    return Uint8List(0);
  }

  int imageSize = images[0].length;
  Uint8List result = Uint8List(imageSize);
  int numImages = images.length;

  for (int i = 0; i < imageSize; i++) {
    List<int> pixelValues = [];
    for (int j = 0; j < numImages; j++) {
      pixelValues.add(images[j][i]);
    }

    pixelValues.sort();
    int medianIndex = numImages ~/ 2;
    result[i] = pixelValues[medianIndex];
  }

  return result;
}

Uint8List maxIntensityProjection(
    List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  // Initialize the result with the first texture
  Uint8List result = Uint8List.fromList(textures[0]);

  // Iterate through all textures and perform max intensity projection
  for (int t = 1; t < numTextures; t++) {
    for (int i = 0; i < size * 4; i += 4) {
      // Calculate intensity (using luminance formula)
      double intensityCurrent =
          0.299 * result[i] + 0.587 * result[i + 1] + 0.114 * result[i + 2];
      double intensityNew = 0.299 * textures[t][i] +
          0.587 * textures[t][i + 1] +
          0.114 * textures[t][i + 2];

      // If the new texture has higher intensity, use its values
      if (intensityNew > intensityCurrent) {
        result[i] = textures[t][i]; // R
        result[i + 1] = textures[t][i + 1]; // G
        result[i + 2] = textures[t][i + 2]; // B
        result[i + 3] = textures[t][i + 3]; // A
      }
    }
  }

  return result;
}

// Helper function to blend MIP result with Poisson blending
Uint8List blendMIPWithPoisson(
    Uint8List mipResult, Uint8List poissonResult, double alpha) {
  final int size = mipResult.length;
  Uint8List blendedResult = Uint8List(size);

  for (int i = 0; i < size; i++) {
    blendedResult[i] = (mipResult[i] * (1 - alpha) + poissonResult[i] * alpha)
        .round()
        .clamp(0, 255);
  }

  return blendedResult;
}

Uint8List pngToPixelBuffer(Uint8List pngData) {
  // Decode the PNG image
  final image = img.decodePng(pngData);

  if (image == null) {
    throw Exception('Failed to decode PNG image');
  }

  // Create a buffer for the raw pixel data
  final rawPixels = Uint8List(image.width * image.height * 4);

  // Convert the image to RGBA format
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final i = (y * image.width + x) * 4;
      rawPixels[i] = pixel.r.toInt(); // Red
      rawPixels[i + 1] = pixel.g.toInt(); // Green
      rawPixels[i + 2] = pixel.b.toInt(); // Blue
      rawPixels[i + 3] = pixel.a.toInt(); // Alpha
    }
  }

  return rawPixels;
}

Uint8List medianBlending(List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  Uint8List result = Uint8List(size * 4);

  for (int i = 0; i < size; i++) {
    List<int> values = [];
    for (int t = 0; t < numTextures; t++) {
      if (textures[t][i * 4] != 0 ||
          textures[t][i * 4 + 1] != 0 ||
          textures[t][i * 4 + 2] != 0 ||
          textures[t][i * 4 + 3] != 0) {
        values.addAll(textures[t].sublist(i * 4, i * 4 + 4));
      }
    }

    if (values.isNotEmpty) {
      values.sort();
      result[i] = values[values.length ~/ 2];
    } else {
      result[i] = 0; // If no valid data, set to transparent
    }
  }

  return result;
}
