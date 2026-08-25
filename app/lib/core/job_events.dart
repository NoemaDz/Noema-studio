import 'dart:async';
import '../models/job.dart';

class JobEvents {
  final StreamController<Job> _controller = StreamController<Job>.broadcast();

  Stream<Job> get stream => _controller.stream;

  void emit(Job job) {
    if (!_controller.isClosed) {
      _controller.add(job);
    }
  }

  void dispose() {
    _controller.close();
  }
}
