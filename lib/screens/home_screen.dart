import 'package:flutter/material.dart';
import 'image_to_image_screen.dart';
import 'image_to_video_screen.dart';
import 'live_swap_screen.dart';
import 'video_call_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'FaceSwap',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 64,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'AI Face Swapping',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Real-time face swapping powered by ONNX Runtime',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feature grid
            _FeatureCard(
              icon: Icons.swap_horiz,
              title: 'Image → Image',
              subtitle: 'Swap faces between two photos',
              color: const Color(0xFF667EEA),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImageToImageScreen(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _FeatureCard(
              icon: Icons.videocam,
              title: 'Image → Video',
              subtitle: 'Apply face swap to entire video',
              color: const Color(0xFF764BA2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImageToVideoScreen(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _FeatureCard(
              icon: Icons.camera_alt,
              title: 'Live Camera Swap',
              subtitle: 'Real-time face swap with camera',
              color: const Color(0xFF11998E),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LiveSwapScreen(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _FeatureCard(
              icon: Icons.video_call,
              title: 'Video Call Overlay',
              subtitle: 'Floating face swap for video calls',
              color: const Color(0xFFFF6B6B),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VideoCallScreen(),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Model status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Models Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  _ModelStatus(name: 'BlazeFace (Detection)', file: 'blazeface.onnx'),
                  _ModelStatus(name: 'ArcFace (Embedding)', file: 'arcface.onnx'),
                  _ModelStatus(name: 'Inswapper (Swap)', file: 'inswapper_mobile.onnx'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

class _ModelStatus extends StatelessWidget {
  final String name;
  final String file;

  const _ModelStatus({required this.name, required this.file});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            file,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}