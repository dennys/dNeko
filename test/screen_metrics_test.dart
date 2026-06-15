import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/screen_metrics.dart';

void main() {
  const metrics = ScreenMetrics(
    logicalSize: Size(400, 800),
    devicePixelRatio: 3.0,
  );

  group('ScreenMetrics', () {
    test('漫遊範圍扣掉寵物大小', () {
      final bounds = metrics.roamingBounds(80);
      expect(bounds.right, 320); // 400 - 80
      expect(bounds.bottom, 720); // 800 - 80
    });

    test('JSON 往返保持一致', () {
      final restored = ScreenMetrics.fromJson(metrics.toJson());
      expect(restored.logicalSize, metrics.logicalSize);
      expect(restored.devicePixelRatio, metrics.devicePixelRatio);
    });
  });
}
