enum NoemaErrorType {
  providerUnavailable,
  networkError,
  authenticationError,
  rateLimited,
  timeout,
  outOfMemory,
  invalidWorkflow,
  modelNotFound,
  cancelled,
  unknown,
}

class NoemaException implements Exception {
  final NoemaErrorType type;
  final String message;
  final bool isRetryable;
  final dynamic originalError;

  const NoemaException({
    required this.type,
    required this.message,
    this.isRetryable = false,
    this.originalError,
  });

  @override
  String toString() {
    if (originalError != null) {
      return "NoemaException($type): $message (Original: $originalError)";
    }
    return "NoemaException($type): $message";
  }

  /// Helper factory to automatically set isRetryable based on error type
  factory NoemaException.fromType(NoemaErrorType type, String message, {dynamic originalError}) {
    bool retryable = false;
    switch (type) {
      case NoemaErrorType.providerUnavailable:
      case NoemaErrorType.networkError:
      case NoemaErrorType.rateLimited:
      case NoemaErrorType.timeout:
      case NoemaErrorType.outOfMemory: // retry with lower profile
        retryable = true;
        break;
      case NoemaErrorType.authenticationError:
      case NoemaErrorType.invalidWorkflow:
      case NoemaErrorType.modelNotFound:
      case NoemaErrorType.cancelled:
      case NoemaErrorType.unknown:
        retryable = false;
        break;
    }

    return NoemaException(
      type: type,
      message: message,
      isRetryable: retryable,
      originalError: originalError,
    );
  }
}
