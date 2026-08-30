import '../../core/providers/video_compiler_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:uuid/uuid.dart';

class MockVideoCompilerProvider extends VideoCompilerProvider {
  @override
  String get id => "mock_ffmpeg";

  @override
  String get name => "Mock FFmpeg";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  @override
  Future<Job> compileVideo(
    List<AudioVideoResource> resources,
    String outputPath, {
    Map<String, dynamic>? options,
  }) async {
    return Job(
      id: "mock_video_${const Uuid().v4()}",
      providerId: id,
      type: "video_compile",
      metadata: {"outputPath": outputPath},
      status: JobStatus.completed,
      progress: 1.0,
      result: outputPath,
    );
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
