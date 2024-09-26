import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/src/thermion_viewer_ffi.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:path/path.dart' as p;

Color kWhite = ColorFloat32(4)..setRgba(1.0, 1.0, 1.0, 1.0);
Color kRed = ColorFloat32(4)..setRgba(1.0, 0.0, 0.0, 1.0);

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

Future<Uint8List> savePixelBufferToBmp(
    Uint8List pixelBuffer, int width, int height, String outputPath) async {
  var data = await pixelBufferToBmp(pixelBuffer, width, height);
  File(outputPath).writeAsBytesSync(data);
  print("Wrote bitmap to ${outputPath}");
  return data;
}

class TestHelper {
  late Directory outDir;

  TestHelper(String dir) {
    final packageUri = findPackageRoot('thermion_dart');
    testDir = Directory("${packageUri.toFilePath()}/test").path;

    var outDir = Directory("$testDir/output/${dir}");
    // outDir.deleteSync(recursive: true);
    outDir.createSync();
  }

  Future capture(ThermionViewer viewer, String outputFilename) async {
    await Future.delayed(Duration(milliseconds: 10));
    var outPath = p.join(outDir.path, "$outputFilename.bmp");
    var pixelBuffer = await viewer.capture();
    await savePixelBufferToBmp(
        pixelBuffer,
        viewer.viewportDimensions.$1.toInt(),
        viewer.viewportDimensions.$2.toInt(),
        outPath);
    return pixelBuffer;
  }
}

Future<Uint8List> pixelBufferToBmp(
    Uint8List pixelBuffer, int width, int height) async {
  final rowSize = (width * 3 + 3) & ~3;
  final padding = rowSize - (width * 3);
  final fileSize = 54 + rowSize * height;

  final data = Uint8List(fileSize);
  final buffer = data.buffer;
  final bd = ByteData.view(buffer);

  // BMP file header (14 bytes)
  bd.setUint16(0, 0x4D42, Endian.little); // 'BM'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(10, 54, Endian.little); // Offset to pixel data

  // BMP info header (40 bytes)
  bd.setUint32(14, 40, Endian.little); // Info header size
  bd.setInt32(18, width, Endian.little);
  bd.setInt32(22, -height, Endian.little); // Negative for top-down
  bd.setUint16(26, 1, Endian.little); // Number of color planes
  bd.setUint16(28, 24, Endian.little); // Bits per pixel (RGB)
  bd.setUint32(30, 0, Endian.little); // No compression
  bd.setUint32(34, rowSize * height, Endian.little); // Image size
  bd.setInt32(38, 2835, Endian.little); // X pixels per meter
  bd.setInt32(42, 2835, Endian.little); // Y pixels per meter

  // Pixel data (BMP stores in BGR format)
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final srcIndex = (y * width + x) * 4; // RGBA format
      final dstIndex = 54 + y * rowSize + x * 3; // BGR format
      data[dstIndex] = pixelBuffer[srcIndex + 2]; // Blue
      data[dstIndex + 1] = pixelBuffer[srcIndex + 1]; // Green
      data[dstIndex + 2] = pixelBuffer[srcIndex]; // Red
      // Alpha channel is discarded
    }
    // Add padding to the end of each row
    for (var p = 0; p < padding; p++) {
      data[54 + y * rowSize + width * 3 + p] = 0;
    }
  }

  return data;
}

Future<Uint8List> pixelsToPng(Uint8List pixelBuffer, int width, int height,
    {bool linearToSrgb = false}) async {
  final image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int pixelIndex = (y * width + x) * 4;
      double r = pixelBuffer[pixelIndex] / 255.0;
      double g = pixelBuffer[pixelIndex + 1] / 255.0;
      double b = pixelBuffer[pixelIndex + 2] / 255.0;
      int a = pixelBuffer[pixelIndex + 3];

      // Apply inverse ACES tone mapping
      bool invertAces = false;
      if (invertAces) {
        r = _inverseACESToneMapping(r);
        g = _inverseACESToneMapping(g);
        b = _inverseACESToneMapping(b);
      }

      if (linearToSrgb) {
        // Convert from linear to sRGB

        image.setPixel(
            x,
            y,
            img.ColorUint8(4)
              ..setRgba(
                  _linearToSRGB(r), _linearToSRGB(g), _linearToSRGB(b), 1.0));
      } else {
        image.setPixel(
            x,
            y,
            img.ColorUint8(4)
              ..setRgba((r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt(),
                  1.0));
      }
    }
  }

  return img.encodePng(image);
}

double _inverseACESToneMapping(double x) {
  const double a = 2.51;
  const double b = 0.03;
  const double c = 2.43;
  const double d = 0.59;
  const double e = 0.14;

  // Ensure x is in the valid range [0, 1]
  x = x.clamp(0.0, 1.0);

  // Inverse ACES filmic tone mapping function
  return (x * (x * a + b)) / (x * (x * c + d) + e);
}

int _linearToSRGB(double linearValue) {
  if (linearValue <= 0.0031308) {
    return (linearValue * 12.92 * 255.0).round().clamp(0, 255);
  } else {
    return ((1.055 * pow(linearValue, 1.0 / 2.4) - 0.055) * 255.0)
        .round()
        .clamp(0, 255);
  }
}

Future<ThermionViewer> createViewer(
    {img.Color? bg,
    Vector3? cameraPosition,
    viewportDimensions = (width: 500, height: 500)}) async {
  final packageUri = findPackageRoot('thermion_dart');

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
  if (bg != null) {
    await viewer.setBackgroundColor(
        bg.r.toDouble(), bg.g.toDouble(), bg.b.toDouble(), bg.a.toDouble());
  }

  if (cameraPosition != null) {
    await viewer.setCameraPosition(
        cameraPosition.x, cameraPosition.y, cameraPosition.z);
  }
  return viewer;
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
