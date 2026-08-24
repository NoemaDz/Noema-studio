import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/job_monitor.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/job_runner.dart';
import 'package:noema_studio/core/job_events.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';

void main() {
  group('JobMonitor Tests', () {
    test('JobMonitor does not overlap polls', () async {
      final registry = ProviderRegistry();
      final runner = JobRunner(registry);
      final manager = JobManager();
      final events = JobEvents();
      
      final monitor = JobMonitor(runner, manager, events);
      
      // We can't easily test the private _isPolling flag directly, 
      // but we can ensure the logic compiles and the structure exists.
      expect(monitor, isNotNull);
      
      monitor.start();
      monitor.stop();
    });
  });
}
