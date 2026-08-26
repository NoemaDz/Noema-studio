import 'dart:io';
import '../../core/providers/video_compiler_provider.dart';
import '../../models/job.dart';
import 'ffmpeg_effect_builder.dart';
import 'package:path/path.dart' as p;
import '../../core/settings/app_settings.dart';

import '../../application/dependency_manager.dart';

class FFmpegVideoCompilerProvider extends VideoCompilerProvider {
  final AppSettings appSettings;

  FFmpegVideoCompilerProvider(this.appSettings);

  @override
  String get id => "ffmpeg_cli";

  @override
  String get name => "FFmpeg Local CLI";

  @override
  bool get available => true; // DependencyManager ensures it's available

  @override
  Future<Job> compileVideo(
    List<AudioVideoResource> resources,
    String outputPath, {
    Map<String, dynamic>? options,
  }) async {
    final jobId = "ffmpeg_${DateTime.now().millisecondsSinceEpoch}";
    final ffmpegPath = DependencyManager.instance.ffmpegPath;

    if (!available) {
      return Job(
        id: jobId,
        providerId: id,
        type: "video_compile",
        status: JobStatus.failed,
        result: "ffmpeg not available",
      );
    }

    try {
      final tempDir = Directory(
        p.join(Directory.systemTemp.path, "noema_compile_$jobId"),
      );
      if (!tempDir.existsSync()) tempDir.createSync();

      // Options
      final effectType =
          options?['video_effect'] ??
          appSettings.defaultVideoEffect;
      final width = options?['width'] ?? 1920;
      final height = options?['height'] ?? 1080;

      final sceneFiles = <String>[];

      // Phase 1: Generate individual scene mp4s
      for (int i = 0; i < resources.length; i++) {
        final resource = resources[i];
        final sceneOutputPath = p.join(tempDir.path, "scene_$i.mp4");

        final requestedEffect = resource.effect ?? effectType;
        final actualEffect = requestedEffect == 'random'
            ? FFmpegEffectBuilder.getRandomEffect()
            : requestedEffect;

        String finalSceneAudio = "";

        // Handle multiple audios
        if (resource.audioPaths.isEmpty) {
          // Generate 3 seconds of silent audio as fallback
          finalSceneAudio = p.join(tempDir.path, "silence_$i.m4a");
          await Process.run(ffmpegPath, [
            '-f',
            'lavfi',
            '-i',
            'anullsrc=r=44100:cl=stereo',
            '-t',
            '3',
            '-q:a',
            '9',
            '-acodec',
            'aac',
            finalSceneAudio,
          ]);
        } else if (resource.audioPaths.length == 1) {
          finalSceneAudio = resource.audioPaths.first;
        } else {
          // Concatenate multiple audios with a short delay/silence between them (optional, for now just concat)
          finalSceneAudio = p.join(tempDir.path, "concat_audio_$i.m4a");
          final audioListFile = File(p.join(tempDir.path, 'audio_list_$i.txt'));
          final audioListContent = StringBuffer();
          for (final audPath in resource.audioPaths) {
            audioListContent.writeln("file '${audPath.replaceAll('\\', '/')}'");
          }
          audioListFile.writeAsStringSync(audioListContent.toString());

          await Process.run(ffmpegPath, [
            '-f',
            'concat',
            '-safe',
            '0',
            '-i',
            audioListFile.path,
            '-c',
            'copy',
            finalSceneAudio,
          ]);
        }

        final bool isVideo =
            resource.imagePath.toLowerCase().endsWith('.mp4') ||
            resource.imagePath.toLowerCase().endsWith('.gif') ||
            resource.imagePath.toLowerCase().endsWith('.webm');

        List<String> args = [];

        if (isVideo) {
          // It's already a video, loop it until the audio finishes
          args = [
            '-stream_loop', '-1', // Loop the video infinitely
            '-i', resource.imagePath,
            '-i', finalSceneAudio,
            '-map', '0:v',
            '-map', '1:a',
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            '-b:a', '192k',
            '-shortest', // Stop when the shortest stream (now guaranteed to be audio since video is infinite) ends
            '-y',
            sceneOutputPath,
          ];
        } else {
          // It's an image, apply zoompan filter
          var filter = FFmpegEffectBuilder.buildFilter(
            actualEffect,
            width: width,
            height: height,
          );

          args = [
            '-i',
            resource.imagePath,
            '-i',
            finalSceneAudio,
            '-filter_complex',
            filter,
            '-map',
            '[v]',
            '-map',
            '1:a',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-c:a',
            'aac',
            '-b:a',
            '192k',
            '-shortest',
            '-y',
            sceneOutputPath,
          ];
        }

        final result = await Process.run(ffmpegPath, args);
        if (result.exitCode != 0) {
          print("FFMPEG FAILED on scene $i");
          print("STDOUT: ${result.stdout}");
          print("STDERR: ${result.stderr}");
          return Job(
            id: jobId,
            providerId: id,
            type: "video_compile",
            status: JobStatus.failed,
            result: "FFmpeg failed on scene $i: ${result.stderr}",
          );
        }

        sceneFiles.add(sceneOutputPath);
      }

      // Phase 2: Concat all scenes
      final listFile = File(p.join(tempDir.path, 'concat_list.txt'));
      final listContent = StringBuffer();
      for (final file in sceneFiles) {
        // FFmpeg requires forward slashes and escaped paths in the concat demuxer file
        final safePath = file.replaceAll('\\', '/');
        listContent.writeln("file '$safePath'");
      }
      listFile.writeAsStringSync(listContent.toString());

      final concatArgs = [
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy', // Super fast, no re-encoding
        '-y',
        outputPath,
      ];

      final concatResult = await Process.run(ffmpegPath, concatArgs);
      if (concatResult.exitCode != 0) {
        print("FFMPEG CONCAT FAILED");
        print("STDOUT: ${concatResult.stdout}");
        print("STDERR: ${concatResult.stderr}");
        return Job(
          id: jobId,
          providerId: id,
          type: "video_compile",
          status: JobStatus.failed,
          result: "FFmpeg concat failed: ${concatResult.stderr}",
        );
      }

      // Cleanup temp dir
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}

      return Job(
        id: jobId,
        providerId: id,
        type: "video_compile",
        metadata: {"outputPath": outputPath},
        status: JobStatus.completed,
        progress: 1.0,
        result: outputPath,
      );
    } catch (e) {
      return Job(
        id: jobId,
        providerId: id,
        type: "video_compile",
        status: JobStatus.failed,
        result: "Exception: $e",
      );
    }
  }
}
