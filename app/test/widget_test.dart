import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/noema.dart';

void main() {
  test('Noema instantiation smoke test', () {
    final noema = Noema();
    expect(noema, isNotNull);
  });
}
