import 'dart:async';
import 'dart:io';
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

  bool _defaultShouldRetry(Exception e) {
    if (e is TimeoutException || e is SocketException) return true;
    final msg = e.toString();
    if (msg.contains("500") ||
        msg.contains("502") ||
        msg.contains("503") ||
        msg.contains("504"))
      return true;
    return false; // Don't retry on 400s or logic errors
  }

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

        final retryChecker = shouldRetry ?? _defaultShouldRetry;
        if (e is Exception && !retryChecker(e)) {
          rethrow;
        }

        debugPrint(
          'RetryPolicy: Action failed with $e. Retrying in ${delay.inSeconds}s (Attempt $attempt/$maxRetries)...',
        );
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffFactor).toInt(),
        );
      }
    }
  }
}
