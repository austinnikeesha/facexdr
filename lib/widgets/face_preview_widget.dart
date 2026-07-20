import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Widget for displaying a face preview with loading state
class FacePreviewWidget extends StatelessWidget {
  final img.Image? image;
  final File? file;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool showCheckmark;

  const FacePreviewWidget({
    super.key,
    this.image,
    this.file,
    required this.label,
    required this.color,
    this.onTap,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null || file != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: hasImage ? color : color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Image preview
            if (hasImage)
              ClipOval(
                child: file != null
                    ? Image.file(
                        file!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Image.memory(
                        Uint8List.fromList(img.encodeJpg(image!)),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
              ),

            // Placeholder
            if (!hasImage)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      color: color.withOpacity(0.5),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap',
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Checkmark
            if (hasImage && showCheckmark)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}