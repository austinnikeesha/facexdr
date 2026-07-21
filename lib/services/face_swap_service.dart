import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:image/image.dart' as img;

class FaceDetection {
  final double score;
  final List<int> bbox; // [x1, y1, x2, y2]
  final List<List<double>> landmarks; // 5 x [x, y]

  const FaceDetection({
    required this.score,
    required this.bbox,
    required this.landmarks,
  });
}

class FaceSwapService {
  late OrtSession _detectorSession;
  late OrtSession _embeddingSession;
  late OrtSession _swapperSession;
  bool _isInitialized = false;

  // Standard 5-point facial landmark template for 112x112 alignment (ArcFace)
  static final List<List<double>> _arcfaceTemplate = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

  // ─────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    OrtEnv.instance.init();

    final detectorPath = await _copyAssetToFile('blazeface.onnx');
    final embeddingPath = await _copyAssetToFile('arcface.onnx');
    final swapperPath = await _copyAssetToFile('inswapper_mobile.onnx');

    final opts = OrtSessionOptions()
      ..setInterOpNumThreads(2)
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    _detectorSession = OrtSession.fromFile(File(detectorPath), opts);
    _embeddingSession = OrtSession.fromFile(File(embeddingPath), opts);
    _swapperSession = OrtSession.fromFile(File(swapperPath), opts);

    _isInitialized = true;
  }

  Future<String> _copyAssetToFile(String assetName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$assetName');
    if (!file.existsSync()) {
      final data = await rootBundle.load('assets/$assetName');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    return file.path;
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 1 & 2: FACE DETECTION with BlazeFace
  // ─────────────────────────────────────────────────────────────

  Future<List<FaceDetection>> detectFaces(img.Image image) async {
    // Resize to 128x128 for BlazeFace
    final resized = img.copyResize(image, width: 128, height: 128);
    final inputTensor = _imageToNormalizedTensor(resized, 128, 128);

    final inputValue = OrtValueTensor.createTensorWithDataList(
      inputTensor,
      [1, 3, 128, 128],
    );

    final inputs = <String, OrtValue>{
      'input': inputValue,
    };

    final outputs = await _detectorSession.runAsync(
      OrtRunOptions(),
      inputs,
    );

    inputValue.release();

    // Parse BlazeFace outputs: boxes + landmarks
    return _parseBlazeFaceOutput(outputs as List<OrtValue>, image.width, image.height);
  }

  List<FaceDetection> _parseBlazeFaceOutput(
    List<OrtValue> outputs,
    int origW,
    int origH,
  ) {
    final detections = <FaceDetection>[];

    if (outputs.isEmpty) return detections;

    final scoresData =
        (outputs[0].value as List<List<double>>?) ?? [];
    final boxesData =
        (outputs[1].value as List<List<double>>?) ?? [];

    for (int i = 0; i < scoresData.length; i++) {
      final score = scoresData[i][0];
      if (score < 0.75) continue;

      final box = boxesData[i];
      // box: [ymin, xmin, ymax, xmax, lm0x, lm0y, ... lm4x, lm4y]
      final ymin = (box[0] * origH).clamp(0, origH).toInt();
      final xmin = (box[1] * origW).clamp(0, origW).toInt();
      final ymax = (box[2] * origH).clamp(0, origH).toInt();
      final xmax = (box[3] * origW).clamp(0, origW).toInt();

      final landmarks = <List<double>>[];
      for (int l = 0; l < 5; l++) {
        landmarks.add([
          box[4 + l * 2] * origW,
          box[5 + l * 2] * origH,
        ]);
      }

      detections.add(FaceDetection(
        score: score,
        bbox: [xmin, ymin, xmax, ymax],
        landmarks: landmarks,
      ));
    }

    for (final v in outputs) {
      v.release();
    }
    return detections;
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 2: FACE ALIGNMENT with OpenCV (sync API for opencv_dart 1.x)
  // ─────────────────────────────────────────────────────────────

  cv.Mat alignFace(cv.Mat imageMat, List<List<double>> landmarks) {
    // Source points from detection
    final srcPoints = cv.VecPoint2f.fromList(
      landmarks.map((p) => cv.Point2f(p[0], p[1])).toList(),
    );

    // Destination points from ArcFace 112x112 template
    final dstPoints = cv.VecPoint2f.fromList(
      _arcfaceTemplate.map((p) => cv.Point2f(p[0], p[1])).toList(),
    );

    // Estimate similarity transform (scale, rotation, translation) - sync API
    final result = cv.estimateAffinePartial2D(
      srcPoints,
      dstPoints,
      method: cv.RANSAC,
    );
    final transform = result.$1;
    final inliers = result.$2;

    // Warp face to 112x112 aligned template - use tuple (int, int) for dsize
    final aligned = cv.Mat.zeros(112, 112, cv.MatType.CV_8UC3);
    cv.warpAffine(
      imageMat,
      transform,
      (112, 112),  // tuple (int, int) for dsize
      dst: aligned,
      flags: cv.INTER_LINEAR,
      borderMode: cv.BORDER_REFLECT,
    );

    srcPoints.dispose();
    dstPoints.dispose();
    transform.dispose();
    inliers.dispose();

    return aligned;
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 3: SOURCE EMBEDDING with ArcFace
  // ─────────────────────────────────────────────────────────────

  Future<List<double>> extractEmbedding(img.Image faceImage) async {
    // ArcFace expects 112x112 normalized input
    final resized = img.copyResize(faceImage, width: 112, height: 112);
    final tensor = _imageToNormalizedTensor(resized, 112, 112);

    final inputValue = OrtValueTensor.createTensorWithDataList(
      tensor,
      [1, 3, 112, 112],
    );

    final inputs = <String, OrtValue>{
      'input.1': inputValue,
    };

    final outputs = await _embeddingSession.runAsync(
      OrtRunOptions(),
      inputs,
    ) as List<OrtValue>;

    inputValue.release();

    final rawEmbedding =
        (outputs[0].value as List<List<double>>?)?.first ??
            List.filled(512, 0.0);

    for (final v in outputs) {
      v.release();
    }

    // L2 normalize the embedding
    return _l2Normalize(rawEmbedding);
  }

  List<double> _l2Normalize(List<double> vec) {
    final norm = sqrt(vec.fold(0.0, (s, x) => s + x * x));
    if (norm == 0) return vec;
    return vec.map((x) => x / norm).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 4: FACE SWAP with Inswapper
  // ─────────────────────────────────────────────────────────────

  cv.Mat runSwapper(
    cv.Mat alignedFaceMat,
    List<double> sourceEmbedding,
  ) {
    // Resize aligned face to 128x128 for inswapper - use tuple (int, int)
    final resizedMat = cv.Mat.zeros(128, 128, cv.MatType.CV_8UC3);
    cv.resize(alignedFaceMat, (128, 128), dst: resizedMat);

    // Convert Mat to float32 tensor [1, 3, 128, 128]
    final imageTensor = _matToNormalizedTensor(resizedMat, 128, 128);
    final embeddingTensor = Float32List.fromList(
      sourceEmbedding.map((e) => e.toDouble()).toList(),
    );

    final targetValue = OrtValueTensor.createTensorWithDataList(
      imageTensor,
      [1, 3, 128, 128],
    );
    final sourceValue = OrtValueTensor.createTensorWithDataList(
      embeddingTensor,
      [1, 512],
    );

    final inputs = <String, OrtValue>{
      'target': targetValue,
      'source': sourceValue,
    };

    final outputs = _swapperSession.run(
      OrtRunOptions(),
      inputs,
    ) as List<OrtValue>;

    targetValue.release();
    sourceValue.release();

    // Convert output tensor back to Mat
    final outputData =
        (outputs[0].value as List?)?.cast<double>() ??
            List.filled(3 * 128 * 128, 0.0);

    for (final v in outputs) {
      v.release();
    }
    resizedMat.dispose();

    return _tensorToMat(outputData, 128, 128);
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 5: FACE BLENDING back onto target
  // ─────────────────────────────────────────────────────────────

  cv.Mat blendFaceBack(
    cv.Mat targetMat,
    cv.Mat swappedFaceMat,
    List<List<double>> landmarks,
    List<int> bbox,
  ) {
    final int x1 = bbox[0], y1 = bbox[1];
    final int x2 = bbox[2], y2 = bbox[3];
    final int faceW = x2 - x1;
    final int faceH = y2 - y1;

    // Resize swapped face to original face bounding box size - use tuple
    final resizedSwapped = cv.Mat.zeros(faceH, faceW, cv.MatType.CV_8UC3);
    cv.resize(swappedFaceMat, (faceW, faceH), dst: resizedSwapped);

    // Create feathered mask for seamless blending
    final mask = cv.Mat.zeros(faceH, faceW, cv.MatType.CV_8UC3);
    final center = cv.Point(faceW ~/ 2, faceH ~/ 2);
    cv.ellipse(
      mask,
      center,
      cv.Point((faceW * 0.45).toInt(), (faceH * 0.48).toInt()),
      0, 0, 360,
      cv.Scalar.all(255),
      thickness: -1,
    );

    // Gaussian blur the mask for feathering - use tuple (int, int)
    cv.gaussianBlur(mask, (31, 31), 11.0, dst: mask);

    // Poisson seamless cloning
    final cloneCenter = cv.Point(
      x1 + faceW ~/ 2,
      y1 + faceH ~/ 2,
    );

    final result = cv.seamlessClone(
      resizedSwapped,
      targetMat,
      mask,
      cloneCenter,
      cv.NORMAL_CLONE,
    );

    mask.dispose();
    resizedSwapped.dispose();

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // COMPLETE PIPELINE: process single image
  // ─────────────────────────────────────────────────────────────

  Future<img.Image?> processImage(
    img.Image targetImage,
    img.Image sourceImage,
  ) async {
    // 1. Extract source embedding
    final sourceEmbedding = await extractEmbedding(sourceImage);

    // 2. Convert target to OpenCV Mat
    final targetMat = _imgImageToMat(targetImage);

    // 3. Detect faces in target
    final detections = await detectFaces(targetImage);
    if (detections.isEmpty) {
      targetMat.dispose();
      return null;
    }

    var resultMat = targetMat.clone();

    // 4. Process each detected face
    for (final detection in detections) {
      // Align detected face
      final alignedFace = alignFace(targetMat, detection.landmarks);

      // Run swapper
      final swappedFace = runSwapper(alignedFace, sourceEmbedding);

      // Blend back
      final blended = blendFaceBack(
        resultMat,
        swappedFace,
        detection.landmarks,
        detection.bbox,
      );

      resultMat.dispose();
      resultMat = blended;
      alignedFace.dispose();
      swappedFace.dispose();
    }

    targetMat.dispose();

    // Convert result Mat back to img.Image
    final result = _matToImgImage(resultMat);
    resultMat.dispose();
    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // TENSOR / MAT CONVERSION UTILITIES
  // ─────────────────────────────────────────────────────────────

  Float32List _imageToNormalizedTensor(
    img.Image image,
    int width,
    int height,
  ) {
    final tensor = Float32List(3 * width * height);
    int idx = 0;

    // R channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        tensor[idx++] = (pixel.r / 255.0 - 0.5) / 0.5;
      }
    }
    // G channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        tensor[idx++] = (pixel.g / 255.0 - 0.5) / 0.5;
      }
    }
    // B channel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        tensor[idx++] = (pixel.b / 255.0 - 0.5) / 0.5;
      }
    }

    return tensor;
  }

  Float32List _matToNormalizedTensor(cv.Mat mat, int width, int height) {
    final tensor = Float32List(3 * width * height);
    int rOffset = 0;
    int gOffset = width * height;
    int bOffset = 2 * width * height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = mat.at<cv.Vec3b>(y, x);
        final linearIdx = y * width + x;
        // OpenCV is BGR
        tensor[bOffset + linearIdx] = (pixel.val1 / 255.0 - 0.5) / 0.5;
        tensor[gOffset + linearIdx] = (pixel.val2 / 255.0 - 0.5) / 0.5;
        tensor[rOffset + linearIdx] = (pixel.val3 / 255.0 - 0.5) / 0.5;
      }
    }
    return tensor;
  }

  cv.Mat _tensorToMat(List<double> tensor, int width, int height) {
    final mat = cv.Mat.zeros(height, width, cv.MatType.CV_8UC3);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        final r = ((tensor[idx] * 0.5 + 0.5) * 255).clamp(0, 255).toInt();
        final g = ((tensor[height * width + idx] * 0.5 + 0.5) * 255)
            .clamp(0, 255).toInt();
        final b = ((tensor[2 * height * width + idx] * 0.5 + 0.5) * 255)
            .clamp(0, 255).toInt();
        // OpenCV BGR - use set method
        mat.set<cv.Vec3b>(y, x, cv.Vec3b(b, g, r));
      }
    }
    return mat;
  }

  cv.Mat _imgImageToMat(img.Image image) {
    final mat = cv.Mat.zeros(
        image.height, image.width, cv.MatType.CV_8UC3);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // OpenCV expects BGR
        mat.set<cv.Vec3b>(
          y, x,
          cv.Vec3b(pixel.b.toInt(), pixel.g.toInt(), pixel.r.toInt()),
        );
      }
    }
    return mat;
  }

  img.Image _matToImgImage(cv.Mat mat) {
    final image = img.Image(width: mat.cols, height: mat.rows);
    for (int y = 0; y < mat.rows; y++) {
      for (int x = 0; x < mat.cols; x++) {
        final pixel = mat.at<cv.Vec3b>(y, x);
        image.setPixelRgb(x, y, pixel.val3, pixel.val2, pixel.val1);
      }
    }
    return image;
  }

  void dispose() {
    _detectorSession.release();
    _embeddingSession.release();
    _swapperSession.release();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}