import 'dart:async';
import 'package:flutter/foundation.dart';

class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffFactor;

  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.backoffFactor = 2.0,
  });

  Future<T> execute<T>(
    Future<T> Function() action, {
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          rethrow;
        }

        if (shouldRetry != null && e is Exception && !shouldRetry(e)) {
          rethrow;
        }

        debugPrint('RetryPolicy: Action failed with $e. Retrying in \${delay.inSeconds}s (Attempt $attempt/$maxRetries)...');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffFactor).toInt());
      }
    }
  }
}
