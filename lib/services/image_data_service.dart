import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreparedImageData {
  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;

  const PreparedImageData({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });
}

class ImageDataService {
  const ImageDataService._();

  static PreparedImageData prepareForRealtime(
    Uint8List bytes, {
    int maxBytes = 650 * 1024,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('That image format could not be read.');
    }

    final oriented = img.bakeOrientation(decoded);
    var maxDimension = 1600;
    var quality = 82;

    for (var attempt = 0; attempt < 9; attempt++) {
      final resized = _resizeToFit(oriented, maxDimension);
      final encoded = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (encoded.length <= maxBytes) {
        return PreparedImageData(
          bytes: encoded,
          mimeType: 'image/jpeg',
          width: resized.width,
          height: resized.height,
        );
      }

      if (quality > 58) {
        quality -= 8;
      } else {
        maxDimension = (maxDimension * 0.82).round().clamp(700, 1600);
      }
    }

    throw StateError(
      'That image is too large for realtime sharing. Try a smaller crop or enable Firebase Storage for full-size images.',
    );
  }

  static img.Image _resizeToFit(img.Image source, int maxDimension) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= maxDimension) return source;

    if (source.width >= source.height) {
      return img.copyResize(source, width: maxDimension);
    }
    return img.copyResize(source, height: maxDimension);
  }
}
