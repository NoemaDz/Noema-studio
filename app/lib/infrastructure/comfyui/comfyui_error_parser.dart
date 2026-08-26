class ComfyUIErrorParser {
  /// Parses the raw error array from ComfyUI history['status']['messages']
  /// and returns a clean, human-readable error string.
  static String parseError(List<dynamic> messages) {
    if (messages.isEmpty) return "Unknown ComfyUI Error";

    try {
      for (final msg in messages) {
        if (msg is List && msg.length >= 2) {
          final msgType = msg[0];
          final msgData = msg[1];
          
          if (msgType == 'execution_error' && msgData is Map) {
            final exceptionType = msgData['exception_type'] ?? 'Exception';
            final exceptionMessage = msgData['exception_message'] ?? 'Unknown error occurred.';
            final nodeType = msgData['node_type'] ?? 'Unknown Node';
            final nodeId = msgData['node_id'] ?? '?';
            
            return "Node '$nodeType' ($nodeId) failed: $exceptionType - $exceptionMessage";
          }
        }
      }
      
      // Fallback: If no 'execution_error' is found, try to stringify the first message.
      final firstMsg = messages.first;
      if (firstMsg is List && firstMsg.length >= 2) {
        return firstMsg[1]?.toString() ?? firstMsg.toString();
      }
      return firstMsg.toString();
    } catch (e) {
      return "Failed to parse ComfyUI error: $e";
    }
  }
}
