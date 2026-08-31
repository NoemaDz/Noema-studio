import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/infrastructure/ingestion/txt_reader.dart';
import 'package:noema_studio/models/job.dart';

void main() {
  group('DocumentIngestion ExecutionContract', () {
    test('TxtReader executes and returns result', () async {
      final reader = TxtReader();
      final tempFile = File('test_ingest.txt');
      await tempFile.writeAsString('Hello Noema');

      final request = ExecutionRequest(
        capability: CapabilityType.llm,
        input: '',
        parameters: {'file_path': tempFile.path},
      );

      final job = await reader.execute(request);
      expect(job.status, JobStatus.running);

      // wait for microtask to finish
      await Future.delayed(const Duration(milliseconds: 100));

      expect(job.status, JobStatus.completed);

      final result = await reader.getResult(job.id);
      expect(result.isSuccess, true);
      expect(result.textOutput, 'Hello Noema');

      await tempFile.delete();
    });

    test('TxtReader returns failure for non-existent file', () async {
      final reader = TxtReader();
      final request = ExecutionRequest(
        capability: CapabilityType.llm,
        input: '',
        parameters: {'file_path': 'does_not_exist.txt'},
      );

      final job = await reader.execute(request);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(job.status, JobStatus.failed);

      final result = await reader.getResult(job.id);
      expect(result.isSuccess, false);
      expect(result.error?.code, 'ingestion_failed');
    });
  });
}
