abstract class LlmClient {
  Future<String> generateText(String prompt);
}

// A simple mock for testing
class MockLlmClient implements LlmClient {
  final String _responseJson;

  MockLlmClient(this._responseJson);

  @override
  Future<String> generateText(String prompt) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));
    return _responseJson;
  }
}
