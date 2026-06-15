import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/domain/screen_metrics.dart';

void main() {
  const metrics = ScreenMetrics(
    logicalSize: Size(400, 800),
    devicePixelRatio: 3.0,
  );

  group('ScreenMetrics', () {
    test('邏輯座標換算成物理座標', () {
      expect(metrics.toPhysical(const Offset(10, 20)), const Offset(30, 60));
    });

    test('物理尺寸 = 邏輯 * ratio', () {
      expect(metrics.physicalSize, const Size(1200, 2400));
    });

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