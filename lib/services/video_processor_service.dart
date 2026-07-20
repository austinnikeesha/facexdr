import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'face_swap_service.dart';

class VideoProcessorService {
  final FaceSwapService _faceSwapService;

  VideoProcessorService(this._faceSwapService);

  // ─────────────────────────────────────────────────────────────
  // IMAGE → VIDEO PROCESSING
  // ─────────────────────────────────────────────────────────────

  Future<String?> processVideo({
    required String inputVideoPath,
    required img.Image sourceFaceImage,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final framesDir = Directory('${dir.path}/frames');
    final outputFramesDir = Directory('${dir.path}/output_frames');

    // Clean and create frame directories
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    if (outputFramesDir.existsSync()) {
      outputFramesDir.deleteSync(recursive: true);
    }
    framesDir.createSync();
    outputFramesDir.createSync();

    // 1. Get video metadata
    onStatusUpdate('Analyzing video...');
    final videoInfo = await _getVideoInfo(inputVideoPath);
    final totalFrames = videoInfo['frames'] as int;
    final fps = videoInfo['fps'] as double;

    // 2. Extract audio
    onStatusUpdate('Extracting audio...');
    final audioPath = '${dir.path}/temp_audio.aac';
    await FFmpegKit.execute(
      '-i "$inputVideoPath" -vn -acodec copy "$audioPath" -y',
    );

    // 3. Extract all frames as PNG
    onStatusUpdate('Extracting frames...');
    final extractResult = await FFmpegKit.execute(
      '-i "$inputVideoPath" -q:v 2 "${framesDir.path}/frame_%05d.png"',
    );

    if (!ReturnCode.isSuccess(await extractResult.getReturnCode())) {
      return null;
    }

    // 4. Get all frame files
    final frameFiles = framesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // 5. Process each frame
    onStatusUpdate('Swapping faces...');
    final sourceEmbedding =
        await _faceSwapService.extractEmbedding(sourceFaceImage);

    for (int i = 0; i < frameFiles.length; i++) {
      final frameFile = frameFiles[i];
      final bytes = await frameFile.readAsBytes();
      final frameImage = img.decodeImage(bytes);

      if (frameImage != null) {
        // Run face swap pipeline on this frame
        final detections = await _faceSwapService.detectFaces(frameImage);

        img.Image processedFrame;
        if (detections.isNotEmpty) {
          final swapped = await _faceSwapService.processImage(
            frameImage,
            sourceFaceImage,
          );
          processedFrame = swapped ?? frameImage;
        } else {
          processedFrame = frameImage;
        }

        // Save processed frame
        final outputFramePath =
            '${outputFramesDir.path}/frame_${i.toString().padLeft(5, '0')}.png';
        await File(outputFramePath).writeAsBytes(
          img.encodePng(processedFrame),
        );
      }

      onProgress((i + 1) / frameFiles.length);
    }

    // 6. Reassemble video from processed frames + original audio
    onStatusUpdate('Assembling output video...');
    final outputPath = '${dir.path}/swapped_output_'
        '${DateTime.now().millisecondsSinceEpoch}.mp4';

    final audioExists = File(audioPath).existsSync();
    String assembleCmd;

    if (audioExists) {
      assembleCmd = '-framerate $fps '
          '-i "${outputFramesDir.path}/frame_%05d.png" '
          '-i "$audioPath" '
          '-c:v libx264 -preset fast -crf 23 '
          '-c:a aac -shortest '
          '"$outputPath" -y';
    } else {
      assembleCmd = '-framerate $fps '
          '-i "${outputFramesDir.path}/frame_%05d.png" '
          '-c:v libx264 -preset fast -crf 23 '
          '"$outputPath" -y';
    }

    final assembleResult = await FFmpegKit.execute(assembleCmd);

    // Cleanup temp files
    framesDir.deleteSync(recursive: true);
    outputFramesDir.deleteSync(recursive: true);
    if (audioExists) File(audioPath).deleteSync();

    if (ReturnCode.isSuccess(await assembleResult.getReturnCode())) {
      return outputPath;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getVideoInfo(String videoPath) async {
    double fps = 30.0;
    int frames = 0;

    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();

    if (info != null) {
      final streams = info.getStreams();
      for (final stream in streams) {
        final type = stream.getType();
        if (type == 'video') {
          final fpsStr = stream.getRealFrameRate();
          if (fpsStr != null && fpsStr.contains('/')) {
            final parts = fpsStr.split('/');
            fps = double.parse(parts[0]) / double.parse(parts[1]);
          }
          frames = int.tryParse(
                stream.getProperty('nb_frames') ?? '0',
              ) ??
              0;
        }
      }
    }

    return {'fps': fps, 'frames': frames};
  }
}