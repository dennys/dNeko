import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/movement_engine.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 100, 100);

  group('MovementEngine', () {
    test('朝目標移動一步，尚未抵達', () {
      const engine = MovementEngine(speedPerTick: 2);
      final result = engine.step(
        current: const Offset(0, 0),
        target: const Offset(100, 0),
        bounds: bounds,
      );

      expect(result.arrived, isFalse);
      expect(result.position.dx, closeTo(2, 0.0001));
      expect(result.position.dy, closeTo(0, 0.0001));
    });

    test('距離小於速度時，直接抵達目標', () {
      const engine = MovementEngine(speedPerTick: 5);
      final result = engine.step(
        current: const Offset(0, 0),
        target: const Offset(3, 0),
        bounds: bounds,
      );

      expect(result.arrived, isTrue);
      expect(result.position, const Offset(3, 0));
    });

    test('座標被限制在範圍內', () {
      const engine = MovementEngine(speedPerTick: 1000);
      final result = engine.step(
        current: const Offset(50, 50),
        target: const Offset(999, 999),
        bounds: bounds,
      );

      expect(result.position.dx, lessThanOrEqualTo(100));
      expect(result.position.dy, lessThanOrEqualTo(100));
    });
  });
}
