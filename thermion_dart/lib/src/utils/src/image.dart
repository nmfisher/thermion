import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:thermion_dart/thermion_dart.dart';

Future<Uint8List> pixelBufferToBmp(Uint8List pixelBuffer, int width, int height,
    {bool hasAlpha = true, bool isFloat = false}) async {
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

  Float32List? floatData;

  if (isFloat) {
    floatData = pixelBuffer.buffer.asFloat32List(
        pixelBuffer.offsetInBytes, width * height * (hasAlpha ? 4 : 3));
  }

  // Pixel data (BMP stores in BGR format)
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final srcIndex = (y * width + x) * (hasAlpha ? 4 : 3); // RGBA format
      final dstIndex = 54 + y * rowSize + x * 3; // BGR format

        data[dstIndex] = isFloat
            ? (floatData![srcIndex + 2] * 255).toInt()
            : pixelBuffer[srcIndex + 2]; // Blue
        data[dstIndex + 1] = isFloat
            ? (floatData![srcIndex + 1] * 255).toInt()
            : pixelBuffer[srcIndex + 1]; // Green
        data[dstIndex + 2] = isFloat
            ? (floatData![srcIndex] * 255).toInt()
            : pixelBuffer[srcIndex]; // Red

      // Alpha channel is discarded
    }
    // Add padding to the end of each row
    for (var p = 0; p < padding; p++) {
      data[54 + y * rowSize + width * 3 + p] = 0;
    }
  }

  return data;
}

Future<Uint8List> pixelBufferToPng(Uint8List pixelBuffer, int width, int height,
    {bool hasAlpha = true, bool isFloat = false, bool linearToSrgb = false, bool invertAces = false}) async {
  final image = img.Image(width: width, height: height);

  Float32List? floatData;
  if (isFloat) {
    floatData = pixelBuffer.buffer.asFloat32List(
        pixelBuffer.offsetInBytes, width * height * (hasAlpha ? 4 : 3));
  }

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int pixelIndex = (y * width + x) * (hasAlpha ? 4 : 3);
      
      double r, g, b, a;
      
      if (isFloat) {
        r = floatData![pixelIndex];
        g = floatData[pixelIndex + 1];
        b = floatData[pixelIndex + 2];
        a = hasAlpha ? floatData[pixelIndex + 3] : 1.0;
      } else {
        r = pixelBuffer[pixelIndex] / 255.0;
        g = pixelBuffer[pixelIndex + 1] / 255.0;
        b = pixelBuffer[pixelIndex + 2] / 255.0;
        a = hasAlpha ? pixelBuffer[pixelIndex + 3] / 255.0 : 1.0;
      }

      // Apply inverse ACES tone mapping
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
                  _linearToSRGB(r), _linearToSRGB(g), _linearToSRGB(b), a));
      } else {
        image.setPixel(
            x,
            y,
            img.ColorUint8(4)
              ..setRgba((r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt(),
                  (a * 255).toInt()));
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
