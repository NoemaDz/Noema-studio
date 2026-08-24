import '../models/job.dart';

typedef JobCallback = void Function(Job job);

class JobEvents {
  final List<JobCallback> _listeners = [];

  void subscribe(JobCallback listener) {
    _listeners.add(listener);
  }

  void unsubscribe(JobCallback listener) {
    _listeners.remove(listener);
  }

  void emit(Job job) {
    for (final listener in _listeners) {
      listener(job);
    }
  }

  bool get hasListeners => _listeners.isNotEmpty;

  void clear() {
    _listeners.clear();
  }
}
