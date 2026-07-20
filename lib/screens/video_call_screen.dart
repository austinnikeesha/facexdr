import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/face_swap_service.dart';
import '../services/camera_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  static const _nativeChannel = MethodChannel('com.faceswap.app/native');

  late FaceSwapService _faceSwapService;
  late CameraService _cameraService;
  final ImagePicker _picker = ImagePicker();

  img.Image? _sourceFace;
  File? _sourceFaceFile;
  Uint8List? _previewFrame;
  bool _isInitialized = false;
  bool _isOverlayActive = false;
  bool _faceLoaded = false;
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _faceSwapService = FaceSwapService();
    _cameraService = CameraService(_faceSwapService);
    _init();
  }

  Future<void> _init() async {
    await _faceSwapService.initialize();
    await _cameraService.initialize();

    // Listen for processed frames and push to native overlay
    _cameraService.processedFrameStream.listen((processedImage) async {
      final bytes = Uint8List.fromList(img.encodeJpg(processedImage));

      // Update preview in Flutter UI
      if (mounted) setState(() => _previewFrame = bytes);

      // If overlay is active, push frame to native Android overlay
      if (_isOverlayActive) {
        try {
          await _nativeChannel.invokeMethod('updateOverlayFrame', {
            'frameBytes': bytes,
          });
        } catch (e) {
          debugPrint('Overlay update error: $e');
        }
      }
    });

    setState(() {
      _isInitialized = true;
      _statusText = 'Ready — select source face to begin';
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
          _statusText = 'Face loaded. Start overlay to use in video calls.';
        });
      }
    }
  }

  Future<void> _toggleOverlay() async {
    if (!_faceLoaded) {
      setState(() => _statusText = 'Load a source face first!');
      return;
    }

    // Request overlay permission
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }

    if (_isOverlayActive) {
      // Stop the service
      await _nativeChannel.invokeMethod('stopOverlayService');
      setState(() {
        _isOverlayActive = false;
        _statusText = 'Overlay stopped';
      });
    } else {
      // Start the overlay service
      final result =
          await _nativeChannel.invokeMethod('startOverlayService');
      if (result == true) {
        setState(() {
          _isOverlayActive = true;
          _statusText =
              'Overlay active! Open your video call app now.\n'
              'The swapped face will appear as a floating window.';
        });
      } else {
        setState(() => _statusText =
            'Enable overlay permission in settings and try again.');
      }
    }
  }

  @override
  void dispose() {
    if (_isOverlayActive) {
      _nativeChannel.invokeMethod('stopOverlayService');
    }
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
          'Video Call Overlay',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This mode uses a floating overlay window. '
                      'It shows your swapped face as a preview tile '
                      'that you can position over your video call app. '
                      'For full feed injection, a rooted device is required.',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Camera live preview
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOverlayActive
                      ? Colors.greenAccent
                      : Colors.white12,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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

            const SizedBox(height: 16),

            // Status text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // Source face picker
            Row(
              children: [
                // Face thumbnail
                GestureDetector(
                  onTap: _pickSourceFace,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _faceLoaded
                            ? Colors.greenAccent
                            : const Color(0xFFFF8008),
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
                              color: Colors.orange.withOpacity(0.2),
                              child: const Icon(
                                Icons.face,
                                color: Color(0xFFFF8008),
                                size: 32,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickSourceFace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8008).withOpacity(0.2),
                      side: const BorderSide(
                        color: Color(0xFFFF8008),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _faceLoaded ? 'CHANGE FACE' : 'SELECT SOURCE FACE',
                      style: const TextStyle(
                        color: Color(0xFFFF8008),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Toggle overlay button
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isInitialized ? _toggleOverlay : null,
                icon: Icon(
                  _isOverlayActive ? Icons.stop_screen_share : Icons.screen_share,
                ),
                label: Text(
                  _isOverlayActive
                      ? 'STOP OVERLAY'
                      : 'START VIDEO CALL OVERLAY',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverlayActive
                      ? Colors.redAccent
                      : const Color(0xFFFF8008),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            _buildStepCard(
              step: '1',
              text: 'Select your source face using the button above',
              color: const Color(0xFFFF8008),
            ),
            const SizedBox(height: 8),
            _buildStepCard(
              step: '2',
              text: 'Tap "START VIDEO CALL OVERLAY" — grant overlay permission if prompted',
              color: const Color(0xFFFF8008),
            ),
            const SizedBox(height: 8),
            _buildStepCard(
              step: '3',
              text: 'Open your video call app (WhatsApp, Zoom, Meet, etc.)',
              color: const Color(0xFFFF8008),
            ),
            const SizedBox(height: 8),
            _buildStepCard(
              step: '4',
              text: 'Drag the floating preview window over your camera tile in the call',
              color: const Color(0xFFFF8008),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}