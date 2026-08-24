import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/retry_policy.dart';

void main() {
  group('RetryPolicy Tests', () {
    test('retries on TimeoutException', () async {
      int attempts = 0;
      final policy = const RetryPolicy(maxRetries: 2, initialDelay: Duration(milliseconds: 10));

      try {
        await policy.execute(() async {
          attempts++;
          throw TimeoutException('Timed out');
        });
      } catch (_) {}

      // 1 initial + 2 retries = 3 attempts
      expect(attempts, equals(3));
    });

    test('does not retry on unhandled Exceptions by default', () async {
      int attempts = 0;
      final policy = const RetryPolicy(maxRetries: 2, initialDelay: Duration(milliseconds: 10));

      try {
        await policy.execute(() async {
          attempts++;
          throw Exception('Logic Error');
        });
      } catch (_) {}

      // Fails immediately
      expect(attempts, equals(1));
    });

    test('retries on 502 Bad Gateway', () async {
      int attempts = 0;
      final policy = const RetryPolicy(maxRetries: 1, initialDelay: Duration(milliseconds: 10));

      try {
        await policy.execute(() async {
          attempts++;
          throw Exception('Server error: 502');
        });
      } catch (_) {}

      expect(attempts, equals(2));
    });
  });
}
