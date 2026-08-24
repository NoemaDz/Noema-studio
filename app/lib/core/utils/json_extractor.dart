class JsonExtractor {
  /// Extracts JSON from a messy string by finding the outermost braces or brackets.
  /// Also strips markdown code block syntax if present.
  static String extract(String response) {
    // 1. First, strip markdown code blocks if they exist.
    // Sometimes LLMs use ```json ... ``` or just ``` ... ```
    String cleanStr = response.trim();
    if (cleanStr.contains('```json')) {
      final startIndex = cleanStr.indexOf('```json') + 7;
      final endIndex = cleanStr.lastIndexOf('```');
      if (endIndex > startIndex) {
        cleanStr = cleanStr.substring(startIndex, endIndex).trim();
      }
    } else if (cleanStr.contains('```')) {
      final startIndex = cleanStr.indexOf('```') + 3;
      final endIndex = cleanStr.lastIndexOf('```');
      if (endIndex > startIndex) {
        cleanStr = cleanStr.substring(startIndex, endIndex).trim();
      }
    }

    // 2. Find outermost curly braces {} or square brackets []
    final firstBrace = cleanStr.indexOf('{');
    final lastBrace = cleanStr.lastIndexOf('}');

    final firstBracket = cleanStr.indexOf('[');
    final lastBracket = cleanStr.lastIndexOf(']');

    int start = -1;
    int end = -1;

    // Determine if it's an object {} or an array []
    if (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket)) {
      start = firstBrace;
      end = lastBrace;
    } else if (firstBracket != -1) {
      start = firstBracket;
      end = lastBracket;
    }

    if (start != -1 && end != -1 && end >= start) {
      String jsonStr = cleanStr.substring(start, end + 1);

      // Auto-close missing brackets for robust parsing
      int openBraces = '{'.allMatches(jsonStr).length;
      int closeBraces = '}'.allMatches(jsonStr).length;
      int openBrackets = '['.allMatches(jsonStr).length;
      int closeBrackets = ']'.allMatches(jsonStr).length;

      while (closeBrackets < openBrackets) {
        jsonStr += ']';
        closeBrackets++;
      }
      while (closeBraces < openBraces) {
        jsonStr += '}';
        closeBraces++;
      }
      return jsonStr;
    }

    return cleanStr;
  }
}
