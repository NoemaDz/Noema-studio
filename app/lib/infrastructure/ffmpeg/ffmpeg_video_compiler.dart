import 'dart:io';
import 'dart:convert';
import '../../core/providers/video_compiler_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'ffmpeg_effect_builder.dart';
import 'ffmpeg_path_escaper.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../../core/settings/app_settings.dart';

import 'package:uuid/uuid.dart';

import '../../application/dependency_manager.dart';
import '../../core/cancellation_token.dart';

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
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  final Map<String, Process> _runningProcesses = {};
  final Set<String> _cancelledJobs = {};

  @visibleForTesting
  List<String> get activeJobIds => _runningProcesses.keys.toList();

  @override
  Future<void> cancelJob(String jobId) async {
    _cancelledJobs.add(jobId);
    if (_runningProcesses.containsKey(jobId)) {
      _runningProcesses[jobId]?.kill(ProcessSignal.sigkill);
      _runningProcesses.remove(jobId);
    }
  }

  Future<int> _runFfmpeg(
    String jobId,
    String executable,
    List<String> args,
  ) async {
    // PRE-FLIGHT CHECK: Check if cancelled before starting the process
    if (_cancelledJobs.contains(jobId)) {
      throw CancelledException();
    }

    final process = await Process.start(executable, args);

    // Check again in case it was cancelled exactly during Process.start await
    if (_cancelledJobs.contains(jobId)) {
      process.kill(ProcessSignal.sigkill);
      throw CancelledException();
    }

    _runningProcesses[jobId] = process;

    final List<int> stdoutBytes = [];
    final List<int> stderrBytes = [];

    final stdoutSub = process.stdout.listen(stdoutBytes.addAll);
    final stderrSub = process.stderr.listen(stderrBytes.addAll);

    final exitCode = await process.exitCode;
    _runningProcesses.remove(jobId);

    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      final stderrText = utf8.decode(stderrBytes, allowMalformed: true);
      final stdoutText = utf8.decode(stdoutBytes, allowMalformed: true);
      print("FFmpeg failed. Args: $args");
      print("FFmpeg Stderr:\n$stderrText");
      print("FFmpeg Stdout:\n$stdoutText");
      throw Exception(
        "FFmpeg failed with exit code $exitCode. Stderr: ${stderrText.trim()}",
      );
    }
    return exitCode;
  }

  @override
  Future<Job> compileVideo(
    List<AudioVideoResource> resources,
    String outputPath, {
    Map<String, dynamic>? options,
  }) async {
    final jobId = options?['jobId'] as String? ?? "ffmpeg_${const Uuid().v4()}";
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

    Directory? tempDir;
    try {
      tempDir = Directory(
        p.join(Directory.systemTemp.path, "noema_compile_$jobId"),
      );
      if (!tempDir.existsSync()) tempDir.createSync();

      // Options
      final effectType =
          options?['video_effect'] ?? appSettings.defaultVideoEffect;
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
          await _runFfmpeg(jobId, ffmpegPath, [
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
          // NOTE: Output must be .wav, NOT .m4a, because flutter_tts generates pcm_s16le WAV files.
          // Copying pcm_s16le into an M4A/MP4 container is unsupported and causes exit code 234 (EINVAL).
          finalSceneAudio = p.join(tempDir.path, "concat_audio_$i.wav");
          final audioListFile = File(p.join(tempDir.path, 'audio_list_$i.txt'));
          final audioListContent = StringBuffer();
          for (final audPath in resource.audioPaths) {
            audioListContent.writeln(
              "file '${FFmpegPathEscaper.escapeConcatPath(audPath)}'",
            );
          }
          audioListFile.writeAsStringSync(audioListContent.toString());

          await _runFfmpeg(jobId, ffmpegPath, [
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
        String? subtitlesFilter;

        if (resource.subtitleText != null &&
            resource.subtitleText!.isNotEmpty) {
          final srtPath = p.join(tempDir.path, "scene_$i.srt");
          final srtContent =
              "1\n00:00:00,000 --> 99:59:59,000\n${resource.subtitleText}\n";
          File(srtPath).writeAsStringSync(srtContent);
          // FFmpeg subtitles filter requires escaping backslashes and colons for Windows paths
          final safeSrtPath = FFmpegPathEscaper.escapeFilterPath(srtPath);

          // Using standard subtitles filter with a readable font styling
          subtitlesFilter =
              "subtitles='$safeSrtPath':force_style='FontSize=20,PrimaryColour=&H00FFFFFF,BackColour=&H80000000,BorderStyle=4,Outline=1,Shadow=1,MarginV=20'";
        }

        if (isVideo) {
          // It's already a video, loop it until the audio finishes
          args = [
            '-stream_loop', '-1', // Loop the video infinitely
            '-i', resource.imagePath,
            '-i', finalSceneAudio,
            if (subtitlesFilter != null) ...['-vf', subtitlesFilter],
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

          if (subtitlesFilter != null) {
            filter += ",$subtitlesFilter";
          }
          filter += "[v]";

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

        await _runFfmpeg(jobId, ffmpegPath, args);

        sceneFiles.add(sceneOutputPath);
      }

      // Phase 2: Concat all scenes
      final listFile = File(p.join(tempDir.path, 'concat_list.txt'));
      final listContent = StringBuffer();
      for (final file in sceneFiles) {
        // FFmpeg requires forward slashes and escaped paths in the concat demuxer file
        final safePath = FFmpegPathEscaper.escapeConcatPath(file);
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

      await _runFfmpeg(jobId, ffmpegPath, concatArgs);

      // Cleanup temp dir inside try is removed
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
      if (_cancelledJobs.contains(jobId)) {
        return Job(
          id: jobId,
          providerId: id,
          type: "video_compile",
          status: JobStatus.cancelled,
          result: "Job cancelled by user",
        );
      }
      return Job(
        id: jobId,
        providerId: id,
        type: "video_compile",
        status: JobStatus.failed,
        result: "Exception: $e",
      );
    } finally {
      _cancelledJobs.remove(jobId);
      try {
        if (tempDir != null && tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }
}
