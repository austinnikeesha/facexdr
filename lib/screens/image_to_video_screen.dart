import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;
import '../services/face_swap_service.dart';
import '../services/video_processor_service.dart';
import '../widgets/face_preview_widget.dart';
import '../widgets/progress_overlay.dart';

class ImageToVideoScreen extends StatefulWidget {
  const ImageToVideoScreen({super.key});

  @override
  State<ImageToVideoScreen> createState() => _ImageToVideoScreenState();
}

class _ImageToVideoScreenState extends State<ImageToVideoScreen> {
  final FaceSwapService _faceSwapService = FaceSwapService();
  late VideoProcessorService _videoProcessorService;
  final ImagePicker _picker = ImagePicker();

  img.Image? _sourceFace;
  File? _sourceFaceFile;
  File? _inputVideoFile;
  String? _outputVideoPath;

  bool _isInitialized = false;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = 'Initializing models...';

  @override
  void initState() {
    super.initState();
    _initModels();
    WakelockPlus.enable();
  }

  Future<void> _initModels() async {
    await _faceSwapService.initialize();
    _videoProcessorService = VideoProcessorService(_faceSwapService);
    setState(() {
      _isInitialized = true;
      _status = 'Ready — select source face and input video';
    });
  }

  Future<void> _pickSourceFace() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      final sourceImg = img.decodeImage(bytes);
      if (sourceImg != null) {
        setState(() {
          _sourceFace = sourceImg;
          _sourceFaceFile = File(picked.path);
          _status = 'Source face loaded';
        });
      }
    }
  }

  Future<void> _pickInputVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _inputVideoFile = File(picked.path);
        _status = 'Input video loaded';
      });
    }
  }

  Future<void> _processVideo() async {
    if (_sourceFace == null || _inputVideoFile == null) {
      setState(() => _status = 'Please select both source face and input video!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = 'Starting video processing...';
    });

    try {
      final outputPath = await _videoProcessorService.processVideo(
        inputVideoPath: _inputVideoFile!.path,
        sourceFaceImage: _sourceFace!,
        onProgress: (progress) {
          setState(() => _progress = progress);
        },
        onStatusUpdate: (status) {
          setState(() => _status = status);
        },
      );

      if (outputPath != null && mounted) {
        setState(() {
          _outputVideoPath = outputPath;
          _isProcessing = false;
          _progress = 1.0;
          _status = 'Video complete!';
        });
      } else {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
          _status = 'Processing failed. Check video format.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _faceSwapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Image → Video Swap'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Source face picker
                _PickerCard(
                  label: 'SOURCE FACE',
                  subtitle: 'The face to swap into video',
                  file: _sourceFaceFile,
                  onTap: _pickSourceFace,
                  color: const Color(0xFF667EEA),
                ),

                const SizedBox(height: 16),

                // Input video picker
                _PickerCard(
                  label: 'INPUT VIDEO',
                  subtitle: 'Video to swap faces in',
                  file: _inputVideoFile,
                  onTap: _pickInputVideo,
                  color: const Color(0xFF764BA2),
                ),

                const SizedBox(height: 24),

                // Output preview
                if (_outputVideoPath != null) ...[
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF11998E).withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: VideoPlayerWidget(videoPath: _outputVideoPath!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'OUTPUT VIDEO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF11998E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Process button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized &&
                            !_isProcessing &&
                            _sourceFace != null &&
                            _inputVideoFile != null
                        ? _processVideo
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.video_call),
                    label: Text(
                      _isProcessing ? 'PROCESSING...' : 'SWAP FACES IN VIDEO',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF11998E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                if (_isProcessing) ...[
                  LinearPercentIndicator(
                    lineHeight: 8,
                    percent: _progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    progressColor: const Color(0xFF11998E),
                    barRadius: Radius.circular(4),
                    center: Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            ProgressOverlay(
              progress: _progress,
              status: _status,
            ),
        ],
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;
  final Color color;

  const _PickerCard({
    required this.label,
    required this.subtitle,
    required this.file,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? color : color.withOpacity(0.3),
            width: file != null ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: file!.path.endsWith('.mp4') ||
                        file!.path.endsWith('.mov') ||
                        file!.path.endsWith('.avi')
                    ? const Center(
                        child: Icon(
                          Icons.videocam,
                          color: Colors.white54,
                          size: 48,
                        ),
                      )
                    : Image.file(
                        file!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  if (file == null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            file != null ? Icons.check : Icons.add_a_photo,
                            color: color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tap to select',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (file != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Simple video player widget placeholder
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const VideoPlayerWidget({super.key, required this.videoPath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() {}))
      ..setLooping(true)
      ..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? VideoPlayer(_controller)
        : const Center(
            child: CircularProgressIndicator(color: Colors.white30),
          );
  }
}