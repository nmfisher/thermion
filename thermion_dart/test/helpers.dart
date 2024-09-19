import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/thermion_viewer_ffi.dart';

final viewportDimensions = (width: 500, height: 500);

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

Future<Uint8List> bmpToPng(Uint8List pixelBuffer, int width, int height) async {
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

      // Convert from linear to sRGB
      final int sRgbR = _linearToSRGB(r);
      final int sRgbG = _linearToSRGB(g);
      final int sRgbB = _linearToSRGB(b);

      image.setPixel(
          x, y, img.ColorUint8(4)..setRgba(sRgbR, sRgbG, sRgbB, 1.0));
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

Future<ThermionViewer> createViewer() async {
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
  return viewer;
}
