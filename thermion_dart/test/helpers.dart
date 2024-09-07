import 'dart:io';

import 'dart:typed_data';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

List<double> cubeVertices = [
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
List<int> cubeIndices = [
  // Front face
  0, 3, 2,  0, 2, 1,
  // Back face
  4, 7, 6,  4, 6, 5,
  // Top face
  8, 11, 10,  8, 10, 9,
  // Bottom face
  12, 15, 14,  12, 14, 13,
  // Right face
  16, 19, 18,  16, 18, 17,
  // Left face
  20, 23, 22,  20, 22, 21
];

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
