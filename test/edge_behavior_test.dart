import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/domain/edge_behavior.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 200, 200);

  group('EdgeWalkBehavior', () {
    test('偵測左邊緣', () {
      final edge = EdgeWalkBehavior(Random(1));
      expect(edge.isAtEdge(const Offset(0, 100), bounds), isTrue);
      expect(edge.isAtEdge(const Offset(100, 100), bounds), isFalse);
    });

    test('在左邊緣 → 沿垂直方向走（x 不變）', () {
      final edge = EdgeWalkBehavior(Random(1));
      final target = edge.nextTargetOnEdge(const Offset(0, 50), bounds);
      expect(target.dx, 0);
      expect(target.dy, inInclusiveRange(0, 200));
    });
  });

  group('EdgeTurnBackBehavior', () {
    test('碰邊後目標為螢幕中央', () {
      final edge = EdgeTurnBackBehavior();
      expect(edge.nextTargetOnEdge(const Offset(0, 0), bounds),
          bounds.center);
    });
  });
}