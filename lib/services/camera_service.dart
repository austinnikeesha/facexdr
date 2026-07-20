import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'face_swap_service.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isProcessingFrame = false;
  int _currentCameraIndex = 0;

  // Live swap state
  img.Image? _sourceFaceImage;
  List<double>? _sourceEmbedding;
  final FaceSwapService _faceSwapService;

  final StreamController<img.Image> _processedFrameStream =
      StreamController<img.Image>.broadcast();

  Stream<img.Image> get processedFrameStream =>
      _processedFrameStream.stream;

  CameraService(this._faceSwapService);

  // ─────────────────────────────────────────────────────────────
  // INITIALIZE
  // ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _cameras = await availableCameras();
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _startCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    _controller!.startImageStream(_onCameraFrame);
  }

  // ─────────────────────────────────────────────────────────────
  // SET SOURCE FACE
  // ─────────────────────────────────────────────────────────────

  Future<void> setSourceFace(img.Image sourceFace) async {
    _sourceFaceImage = sourceFace;
    _sourceEmbedding =
        await _faceSwapService.extractEmbedding(sourceFace);
  }

  // ─────────────────────────────────────────────────────────────
  // CAMERA FRAME CALLBACK
  // ─────────────────────────────────────────────────────────────

  void _onCameraFrame(CameraImage cameraImage) async {
    if (_isProcessingFrame) return;
    if (_sourceEmbedding == null) return;

    _isProcessingFrame = true;

    try {
      // Convert YUV420 to RGB img.Image
      final rgbImage = _convertYUV420ToImage(cameraImage);

      if (rgbImage != null) {
        // Run face swap pipeline on the live frame
        final swapped = await _faceSwapService.processImage(
          rgbImage,
          _sourceFaceImage!,
        );

        if (swapped != null && !_processedFrameStream.isClosed) {
          _processedFrameStream.add(swapped);
        }
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // YUV420 TO RGB CONVERSION
  // ─────────────────────────────────────────────────────────────

  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    try {
      final width = cameraImage.width;
      final height = cameraImage.height;

      final yPlane = cameraImage.planes[0].bytes;
      final uPlane = cameraImage.planes[1].bytes;
      final vPlane = cameraImage.planes[2].bytes;

      final uRowStride = cameraImage.planes[1].bytesPerRow;
      final uPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final uvIndex =
              (uRowStride * (y ~/ 2)) + (x ~/ 2) * uPixelStride;

          final yVal = yPlane[y * width + x];
          final uVal = uPlane[uvIndex];
          final vVal = vPlane[uvIndex];

          // YUV to RGB conversion
          final r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toInt();
          final g = (yVal - 0.344136 * (uVal - 128) -
                  0.714136 * (vVal - 128))
              .clamp(0, 255)
              .toInt();
          final b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toInt();

          image.setPixelRgb(x, y, r, g, b);
        }
      }

      return image;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FLIP CAMERA
  // ─────────────────────────────────────────────────────────────

  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  CameraController? get controller => _controller;

  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _processedFrameStream.close();
  }
}