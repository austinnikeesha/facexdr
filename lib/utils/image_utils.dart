import 'dart:io';
import 'package:image/image.dart' as img;

/// Utility functions for image processing
class ImageUtils {
  /// Decode image from file
  static img.Image? decodeImage(File file) {
    try {
      final bytes = file.readAsBytesSync();
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  /// Decode image from bytes
  static img.Image? decodeImageFromBytes(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  /// Encode image to JPEG bytes
  static Uint8List encodeJpg(img.Image image, {int quality = 90}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Encode image to PNG bytes
  static Uint8List encodePng(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Resize image maintaining aspect ratio
  static img.Image resize(img.Image image, int width, int height) {
    return img.copyResize(image, width: width, height: height);
  }

  /// Crop image to rectangle
  static img.Image crop(img.Image image, int x, int y, int width, int height) {
    return img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  /// Convert to grayscale
  static img.Image grayscale(img.Image image) {
    return img.grayscale(image);
  }

  /// Apply Gaussian blur
  static img.Image gaussianBlur(img.Image image, int radius) {
    return img.gaussianBlur(image, radius);
  }

  /// Save image to file
  static Future<void> saveImage(img.Image image, String path) async {
    final file = File(path);
    if (path.endsWith('.png')) {
      await file.writeAsBytes(encodePng(image));
    } else {
      await file.writeAsBytes(encodeJpg(image));
    }
  }

  /// Get image dimensions from file
  static Future<Map<String, int>?> getImageDimensions(File file) async {
    try {
      final image = decodeImage(file);
      if (image != null) {
        return {'width': image.width, 'height': image.height};
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

/// Typedef for Uint8List
typedef Uint8List = List<int>;