import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility functions for tensor operations and conversions
class TensorUtils {
  /// Normalize image to [-1, 1] range for model input
  /// Returns Float32List in CHW format
  static Float32List imageToNormalizedTensor(
    img.Image image,
    int width,
    int height,
  ) {
    final resized = img.copyResize(image, width: width, height: height);
    final tensor = Float32List(3 * width * height);
    int idx = 0;

    // R channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        tensor[idx++] = (pixel.r / 255.0 - 0.5) / 0.5;
      }
    }
    // G channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        tensor[idx++] = (pixel.g / 255.0 - 0.5) / 0.5;
      }
    }
    // B channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        tensor[idx++] = (pixel.b / 255.0 - 0.5) / 0.5;
      }
    }

    return tensor;
  }

  /// Convert CHW tensor back to image
  /// Expects tensor in [-1, 1] range, outputs image
  static img.Image tensorToImage(
    Float32List tensor,
    int width,
    int height,
  ) {
    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        final r = ((tensor[idx] * 0.5 + 0.5) * 255).clamp(0, 255).toInt();
        final g = ((tensor[height * width + idx] * 0.5 + 0.5) * 255)
            .clamp(0, 255)
            .toInt();
        final b = ((tensor[2 * height * width + idx] * 0.5 + 0.5) * 255)
            .clamp(0, 255)
            .toInt();
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  /// L2 normalize a vector
  static Float32List l2Normalize(Float32List vector) {
    double sum = 0;
    for (final v in vector) {
      sum += v * v;
    }
    final norm = sqrt(sum);
    if (norm == 0) return vector;

    final result = Float32List(vector.length);
    for (int i = 0; i < vector.length; i++) {
      result[i] = vector[i] / norm;
    }
    return result;
  }

  /// Cosine similarity between two vectors
  static double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) return 0.0;

    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Softmax function
  static Float32List softmax(Float32List logits) {
    final maxLogit = logits.reduce(max);
    final exps = Float32List(logits.length);
    double sum = 0;

    for (int i = 0; i < logits.length; i++) {
      exps[i] = exp(logits[i] - maxLogit);
      sum += exps[i];
    }

    for (int i = 0; i < exps.length; i++) {
      exps[i] /= sum;
    }

    return exps;
  }

  /// Argmax - returns index of maximum value
  static int argmax(Float32List values) {
    int maxIdx = 0;
    double maxVal = values[0];
    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxVal) {
        maxVal = values[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }
}