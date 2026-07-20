import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:image/image.dart' as img;
import '../services/face_swap_service.dart';
import '../services/camera_service.dart';

class LiveSwapScreen extends StatefulWidget {
  const LiveSwapScreen({super.key});

  @override
  State<LiveSwapScreen> createState() => _LiveSwapScreenState();
}

class _LiveSwapScreenState extends State<LiveSwapScreen> {
  final FaceSwapService _faceSwapService = FaceSwapService();
  late CameraService _cameraService;
  final ImagePicker _picker = ImagePicker();

  img.Image? _sourceFace;
  File? _sourceFaceFile;
  Uint8List? _previewFrame;
  bool _isInitialized = false;
  bool _isSwapping = false;
  bool _faceLoaded = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initModels();
  }

  Future<void> _initModels() async {
    await _faceSwapService.initialize();
    _cameraService = CameraService(_faceSwapService);
    await _cameraService.initialize();

    _cameraService.processedFrameStream.listen((processedImage) {
      if (mounted) {
        setState(() {
          _previewFrame = Uint8List.fromList(img.encodeJpg(processedImage));
        });
      }
    });

    setState(() {
      _isInitialized = true;
      _status = 'Ready — select source face to start live swap';
    });
  }

  Future<void> _pickSourceFace() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      final sourceImg = img.decodeImage(bytes);

      if (sourceImg != null) {
        await _cameraService.setSourceFace(sourceImg);
        setState(() {
          _sourceFace = sourceImg;
          _sourceFaceFile = File(picked.path);
          _faceLoaded = true;
          _isSwapping = true;
          _status = 'Live swapping active!';
        });
      }
    }
  }

  void _toggleSwap() {
    setState(() {
      _isSwapping = !_isSwapping;
      _status = _isSwapping ? 'Live swapping active!' : 'Paused — tap to resume';
    });
  }

  Future<void> _flipCamera() async {
    await _cameraService.flipCamera();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _cameraService.dispose();
    _faceSwapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Live Camera Swap',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isInitialized)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _flipCamera,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 1.33,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: _isSwapping
                      ? Colors.greenAccent
                      : Colors.white12,
                  width: 2,
                ),
              ),
              child: ClipRect(
                child: _previewFrame != null
                    ? Image.memory(
                        _previewFrame!,
                        gaplessPlayback: true,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white30,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Camera initializing...',
                              style: TextStyle(color: Colors.white30),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Source face picker overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _pickSourceFace,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _faceLoaded
                        ? Colors.greenAccent
                        : const Color(0xFF667EEA).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _faceLoaded
                              ? Colors.greenAccent
                              : const Color(0xFF667EEA),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _sourceFaceFile != null
                            ? Image.file(
                                _sourceFaceFile!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: const Color(0xFF667EEA).withOpacity(0.2),
                                child: const Icon(
                                  Icons.add_a_photo,
                                  color: Color(0xFF667EEA),
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOURCE FACE',
                            style: TextStyle(
                              color: _faceLoaded
                                  ? Colors.greenAccent
                                  : const Color(0xFF667EEA),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _faceLoaded
                                ? 'Tap to change face'
                                : 'Tap to select source face',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_faceLoaded)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Toggle swap button
                GestureDetector(
                  onTap: _faceLoaded ? _toggleSwap : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSwapping
                          ? const Color(0xFF11998E)
                          : Colors.white24,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isSwapping ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Status indicator
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _faceLoaded
                            ? Icons.check_circle
                            : Icons.face_retouching_off,
                        color: _faceLoaded ? Colors.greenAccent : Colors.white54,
                        size: 24,
                      ),
                      Text(
                        _faceLoaded ? 'Ready' : 'No Face',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Status text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}