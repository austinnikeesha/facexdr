import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:path_provider/path_provider.dart';
import '../services/face_swap_service.dart';
import '../widgets/face_preview_widget.dart';
import '../widgets/progress_overlay.dart';

class ImageToImageScreen extends StatefulWidget {
  const ImageToImageScreen({super.key});

  @override
  State<ImageToImageScreen> createState() => _ImageToImageScreenState();
}

class _ImageToImageScreenState extends State<ImageToImageScreen> {
  final FaceSwapService _faceSwapService = FaceSwapService();
  final ImagePicker _picker = ImagePicker();

  img.Image? _sourceFace;
  img.Image? _targetImage;
  File? _sourceFaceFile;
  File? _targetFile;

  img.Image? _resultImage;
  bool _isInitialized = false;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = 'Initializing models...';

  @override
  void initState() {
    super.initState();
    _initModels();
  }

  Future<void> _initModels() async {
    await _faceSwapService.initialize();
    setState(() {
      _isInitialized = true;
      _status = 'Ready — select source and target images';
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

  Future<void> _pickTargetImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      final targetImg = img.decodeImage(bytes);
      if (targetImg != null) {
        setState(() {
          _targetImage = targetImg;
          _targetFile = File(picked.path);
          _status = 'Target image loaded';
        });
      }
    }
  }

  Future<void> _performFaceSwap() async {
    if (_sourceFace == null || _targetImage == null) {
      setState(() => _status = 'Please select both images first!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = 'Extracting source embedding...';
    });

    try {
      // Process the image
      setState(() => _status = 'Detecting faces...');
      setState(() => _progress = 0.3);

      final result = await _faceSwapService.processImage(
        _targetImage!,
        _sourceFace!,
      );

      setState(() => _progress = 0.9);

      if (result != null) {
        // Save to app documents
        final dir = await getApplicationDocumentsDirectory();
        final outputPath =
            '${dir.path}/faceswap_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(outputPath).writeAsBytes(img.encodeJpg(result));

        setState(() {
          _resultImage = result;
          _isProcessing = false;
          _progress = 1.0;
          _status = 'Face swap complete! Saved to $outputPath';
        });
      } else {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
          _status = 'No faces detected in target image';
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
    _faceSwapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Image → Image Swap'),
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
                _ImagePickerCard(
                  label: 'SOURCE FACE',
                  subtitle: 'The face to swap in',
                  imageFile: _sourceFaceFile,
                  onTap: _pickSourceFace,
                  color: const Color(0xFF667EEA),
                ),

                const SizedBox(height: 16),

                // Target image picker
                _ImagePickerCard(
                  label: 'TARGET IMAGE',
                  subtitle: 'The photo to swap face onto',
                  imageFile: _targetFile,
                  onTap: _pickTargetImage,
                  color: const Color(0xFF764BA2),
                ),

                const SizedBox(height: 24),

                // Result preview
                if (_resultImage != null) ...[
                  Container(
                    height: 300,
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
                      child: Image.memory(
                        Uint8List.fromList(img.encodeJpg(_resultImage!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RESULT',
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

                // Swap button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isInitialized && !_isProcessing && _sourceFace != null && _targetImage != null
                            ? _performFaceSwap
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
                        : const Icon(Icons.face_retouching_natural),
                    label: Text(
                      _isProcessing ? 'PROCESSING...' : 'SWAP FACES',
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

class _ImagePickerCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final File? imageFile;
  final VoidCallback onTap;
  final Color color;

  const _ImagePickerCard({
    required this.label,
    required this.subtitle,
    required this.imageFile,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imageFile != null ? color : color.withOpacity(0.3),
            width: imageFile != null ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Image preview
            if (imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  imageFile!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            // Overlay content
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
                  if (imageFile == null) ...[
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
                            Icons.add_a_photo,
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

            // Checkmark when selected
            if (imageFile != null)
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