import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/data/models/animation_action.dart';
import 'package:desktop_pet/domain/direction_resolver.dart';

void main() {
  const resolver = DirectionResolver();

  group('DirectionResolver', () {
    test('純右向 → walkRight', () {
      expect(resolver.fromVelocity(const Offset(10, 0)),
          AnimationAction.walkRight);
    });

    test('純上向 → walkUp（螢幕座標 y 為負）', () {
      expect(
          resolver.fromVelocity(const Offset(0, -10)), AnimationAction.walkUp);
    });

    test('右下對角 → walkDownRight', () {
      expect(resolver.fromVelocity(const Offset(10, 10)),
          AnimationAction.walkDownRight);
    });

    test('零向量 → 預設 walkDown', () {
      expect(
          resolver.fromVelocity(Offset.zero), AnimationAction.walkDown);
    });
  });
}