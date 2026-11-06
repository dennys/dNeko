import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_settings.dart';
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

    test('bottomInset 一起進出 JSON（舊 payload 缺欄位時為 0）', () {
      const withInset = ScreenMetrics(
        logicalSize: Size(400, 800),
        devicePixelRatio: 3,
        bottomInset: 24,
      );
      expect(ScreenMetrics.fromJson(withInset.toJson()).bottomInset, 24);

      final legacy = ScreenMetrics.fromJson({
        'width': 400.0,
        'height': 800.0,
        'devicePixelRatio': 3.0,
      });
      expect(legacy.bottomInset, 0);
    });
  });

  group('zoneBounds', () {
    const pet = 80.0;
    const withInset = ScreenMetrics(
      logicalSize: Size(400, 800),
      devicePixelRatio: 3,
      bottomInset: 24,
    );

    test('fullScreen 等於原本的 roamingBounds', () {
      expect(
        metrics.zoneBounds(pet, PetZone.fullScreen),
        metrics.roamingBounds(pet),
      );
    });

    test('無系統列時下方帶貼著可用底部', () {
      final band = metrics.zoneBounds(pet, PetZone.bottomBand);
      expect(band.bottom, 720); // 800 - 80
      expect(band.top, 560); // 再往上 2×petSize
      expect(band.left, 0);
      expect(band.right, 320);
    });

    test('有系統列時下方帶要把它留出來', () {
      final band = withInset.zoneBounds(pet, PetZone.bottomBand);
      expect(band.bottom, 696); // 800 - 24 - 80
      expect(band.top, 536);
    });

    test('角落區以該角為锚，邊長 2×petSize', () {
      final br = withInset.zoneBounds(pet, PetZone.bottomRight);
      expect(br.right, 320);
      expect(br.bottom, 696);
      expect(br.width, 160);
      expect(br.height, 160);

      final tl = metrics.zoneBounds(pet, PetZone.topLeft);
      expect(tl.left, 0);
      expect(tl.top, 0);
      expect(tl.right, 160);
      expect(tl.bottom, 160);

      final tr = metrics.zoneBounds(pet, PetZone.topRight);
      expect(tr.right, 320);
      expect(tr.top, 0);
    });

    test('寵物比區域還大時不會跑出負座標', () {
      for (final zone in PetZone.values) {
        final r = metrics.zoneBounds(900, zone);
        expect(r.left >= 0, isTrue, reason: '$zone left');
        expect(r.top >= 0, isTrue, reason: '$zone top');
        expect(r.right >= r.left, isTrue, reason: '$zone right');
        expect(r.bottom >= r.top, isTrue, reason: '$zone bottom');
      }
    });
  });
}
