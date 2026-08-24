import '../models/job.dart';
import 'job_events.dart';

class JobDispatcher {
  final JobEvents events;

  JobDispatcher(this.events);

  void dispatch(Job job) {
    events.emit(job);
  }
}
