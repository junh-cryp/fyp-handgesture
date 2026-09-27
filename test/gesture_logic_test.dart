import 'package:flutter_test/flutter_test.dart';
import 'package:handgesture/logic/gesture_logic.dart';

void main() {
  group('GestureResult', () {
    test('matchScore assignment', () {
      final result = GestureResult("TEST", 0.85);
      expect(result.matchScore, 0.85);
    });

    test('empty gesture result', () {
      final result = GestureResult.empty();
      expect(result.word, "");
      expect(result.matchScore, 0.0);
    });
  });

  group('GestureLogic Sorting Logic', () {
    test('candidates are sorted by matchScore descending', () {
      final r1 = GestureResult("A", 0.75);
      final r2 = GestureResult("B", 0.95);
      final r3 = GestureResult("C", 0.85);

      final list = [r1, r2, r3];
      list.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      expect(list[0].word, "B");
      expect(list[1].word, "C");
      expect(list[2].word, "A");
    });
  });
}
