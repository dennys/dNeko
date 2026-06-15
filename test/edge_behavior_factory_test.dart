import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/edge_behavior.dart';
import 'package:dneko/domain/edge_behavior_factory.dart';

void main() {
  const factory = EdgeBehaviorFactory();

  group('EdgeBehaviorFactory', () {
    test('"walk" → EdgeWalkBehavior', () {
      expect(factory.create('walk'), isA<EdgeWalkBehavior>());
    });

    test('"turnBack" → EdgeTurnBackBehavior', () {
      expect(factory.create('turnBack'), isA<EdgeTurnBackBehavior>());
    });

    test('大小寫不敏感', () {
      expect(factory.create('TURNBACK'), isA<EdgeTurnBackBehavior>());
    });

    test('未知或 null → 預設 EdgeWalkBehavior', () {
      expect(factory.create(null), isA<EdgeWalkBehavior>());
      expect(factory.create('unknown'), isA<EdgeWalkBehavior>());
    });
  });
}