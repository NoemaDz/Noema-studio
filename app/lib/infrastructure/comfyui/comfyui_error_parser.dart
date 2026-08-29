import '../../core/errors/noema_exception.dart';

class ComfyUIErrorParser {
  /// Parses the raw error array from ComfyUI history['status']['messages']
  /// and returns a NoemaException with the appropriate NoemaErrorType.
  static NoemaException parseError(List<dynamic> messages) {
    if (messages.isEmpty) {
      return NoemaException.fromType(NoemaErrorType.unknown, "Unknown ComfyUI Error");
    }

    try {
      for (final msg in messages) {
        if (msg is List && msg.length >= 2) {
          final msgType = msg[0];
          final msgData = msg[1];
          
          if (msgType == 'execution_error' && msgData is Map) {
            final exceptionType = msgData['exception_type']?.toString() ?? 'Exception';
            final exceptionMessage = msgData['exception_message']?.toString() ?? 'Unknown error occurred.';
            final nodeType = msgData['node_type']?.toString() ?? 'Unknown Node';
            final nodeId = msgData['node_id']?.toString() ?? '?';
            
            final fullMessage = "Node '$nodeType' ($nodeId) failed: $exceptionType - $exceptionMessage";
            
            NoemaErrorType type = NoemaErrorType.unknown;
            if (fullMessage.contains('CUDA out of memory') || fullMessage.contains('OOM')) {
              type = NoemaErrorType.outOfMemory;
            } else if (fullMessage.contains('IPAdapter') || fullMessage.contains('ip_adapter') || fullMessage.contains('model not found')) {
              type = NoemaErrorType.modelNotFound;
            } else {
              type = NoemaErrorType.invalidWorkflow; // Mostly node execution errors are invalid workflows
            }
            
            return NoemaException.fromType(type, fullMessage);
          }
        }
      }
      
      // Fallback: If no 'execution_error' is found, try to stringify the first message.
      final firstMsg = messages.first;
      String fallbackMsg = "";
      if (firstMsg is List && firstMsg.length >= 2) {
        fallbackMsg = firstMsg[1]?.toString() ?? firstMsg.toString();
      } else {
        fallbackMsg = firstMsg.toString();
      }
      return NoemaException.fromType(NoemaErrorType.unknown, fallbackMsg);
    } catch (e) {
      return NoemaException.fromType(NoemaErrorType.unknown, "Failed to parse ComfyUI error: $e");
    }
  }
}
