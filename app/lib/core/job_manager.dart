import '../models/job.dart';

class JobManager {
  final List<Job> _jobs = [];

  List<Job> get jobs => List.unmodifiable(_jobs);

  Job add(Job job) {
    _jobs.add(job);
    return job;
  }

  Job? find(String id) {
    try {
      return _jobs.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateStatus(String id, JobStatus status) {
    final job = find(id);

    if (job != null) {
      job.status = status;
    }
  }

  void updateProgress(String id, double progress) {
    final job = find(id);

    if (job != null) {
      job.progress = progress;
    }
  }

  void complete(String id, String result) {
    final job = find(id);

    if (job != null) {
      job.status = JobStatus.completed;
      job.progress = 1.0;
      job.result = result;
    }
  }

  void remove(String id) {
    _jobs.removeWhere((job) => job.id == id);
  }

  void clear() {
    _jobs.clear();
  }

  List<Job> byStatus(JobStatus status) {
    return _jobs.where((job) => job.status == status).toList();
  }

  bool contains(String id) {
    return find(id) != null;
  }
}
