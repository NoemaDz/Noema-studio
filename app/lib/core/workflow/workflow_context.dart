class WorkflowContext {
  final Map<String, dynamic> _data = {};

  void set(String key, dynamic value) {
    _data[key] = value;
  }

  T? get<T>(String key) {
    return _data[key] as T?;
  }

  bool contains(String key) {
    return _data.containsKey(key);
  }
}
