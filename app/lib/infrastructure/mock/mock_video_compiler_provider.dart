import '../../core/providers/video_compiler_provider.dart';
import '../../models/job.dart';

class MockVideoCompilerProvider extends VideoCompilerProvider {
  @override
  String get id => "mock_ffmpeg";

  @override
  String get name => "Mock FFmpeg";

  @override
  bool get available => true;

  @override
  Future<Job> compileVideo(List<AudioVideoResource> resources, String outputPath, {Map<String, dynamic>? options}) async {
    return Job(
      id: "mock_video_${DateTime.now().millisecondsSinceEpoch}",
      type: "video_compile",
      metadata: {"outputPath": outputPath},
      status: JobStatus.completed,
      progress: 1.0,
      result: outputPath,
    );
  }
}
