import 'dart:typed_data';

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