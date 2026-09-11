import 'package:flutter_test/flutter_test.dart';
import 'package:handgesture/logic/gesture_logic.dart';

void main() {
  group('GestureLogic Score Calculation', () {
    test('calculateRuleScore returns correct ratio', () {
      expect(GestureLogic.calculateRuleScore([true, true, false, false]), 0.5);
      expect(GestureLogic.calculateRuleScore([true, true, true]), 1.0);
      expect(GestureLogic.calculateRuleScore([false, false]), 0.0);
    });

    test('calculateRuleScore handles empty list', () {
      expect(GestureLogic.calculateRuleScore([]), 0.0);
    });

    test('minimumMatchScore is 0.70', () {
      expect(GestureLogic.minimumMatchScore, 0.70);
    });
  });

  group('GestureResult', () {
    test('matchScore assignment', () {
      final result = GestureResult("TEST", 0.85);
      expect(result.matchScore, 0.85);
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
