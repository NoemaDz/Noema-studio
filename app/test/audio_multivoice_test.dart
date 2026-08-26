import 'package:flutter_test/flutter_test.dart';
import '../lib/models/character.dart';

void main() {
  test('Character model supports voiceProfile', () {
    final json = {
      'id': 'c1',
      'name': 'Bob',
      'description': 'A man',
      'imageState': 'draft',
      'voiceProfile': 'en-US-GuyNeural'
    };
    
    final character = Character.fromJson(json);
    expect(character.voiceProfile, 'en-US-GuyNeural');
    
    final out = character.toJson();
    expect(out['voiceProfile'], 'en-US-GuyNeural');
  });
}
