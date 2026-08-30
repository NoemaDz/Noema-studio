import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/errors/noema_exception.dart';
import 'package:noema_studio/models/job.dart';

void main() {
  group('NoemaException', () {
    test('fromType correctly sets isRetryable', () {
      final oomError = NoemaException.fromType(
        NoemaErrorType.outOfMemory,
        'OOM',
      );
      expect(oomError.isRetryable, isTrue);

      final networkError = NoemaException.fromType(
        NoemaErrorType.networkError,
        'Timeout',
      );
      expect(networkError.isRetryable, isTrue);

      final authError = NoemaException.fromType(
        NoemaErrorType.authenticationError,
        'Auth',
      );
      expect(authError.isRetryable, isFalse);

      final modelError = NoemaException.fromType(
        NoemaErrorType.modelNotFound,
        'IPAdapter',
      );
      expect(modelError.isRetryable, isFalse);
    });
  });

  group('Job State Machine', () {
    test('Valid transitions', () {
      final job = Job(id: '1', providerId: 'test', type: 'image');
      expect(job.status, JobStatus.pending);

      // pending -> queued
      expect(job.transitionTo(JobStatus.queued), isTrue);
      expect(job.status, JobStatus.queued);

      // queued -> running
      expect(job.transitionTo(JobStatus.running), isTrue);
      expect(job.status, JobStatus.running);

      // running -> retrying
      expect(job.transitionTo(JobStatus.retrying), isTrue);
      expect(job.status, JobStatus.retrying);

      // retrying -> running
      expect(job.transitionTo(JobStatus.running), isTrue);
      expect(job.status, JobStatus.running);

      // running -> completed
      expect(job.transitionTo(JobStatus.completed), isTrue);
      expect(job.status, JobStatus.completed);
    });

    test('Invalid transitions block state change', () {
      final job = Job(
        id: '1',
        providerId: 'test',
        type: 'image',
        status: JobStatus.completed,
      );

      // completed -> running (should fail)
      expect(job.transitionTo(JobStatus.running), isFalse);
      expect(job.status, JobStatus.completed); // Status should remain completed

      // pending -> completed (should fail)
      final job2 = Job(id: '2', providerId: 'test', type: 'image');
      expect(job2.transitionTo(JobStatus.completed), isFalse);
      expect(job2.status, JobStatus.pending);
    });
  });
}
