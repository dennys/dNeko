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
    test('JSON 往返保持一致', () {
      final restored = ScreenMetrics.fromJson(metrics.toJson());
      expect(restored.logicalSize, metrics.logicalSize);
      expect(restored.devicePixelRatio, metrics.devicePixelRatio);
    });

    test('fallbackRoam 扣掉寵物大小', () {
      expect(metrics.fallbackRoam(80), const Rect.fromLTWH(0, 0, 320, 720));
    });
  });

  group('zoneBounds（吃實測的 roam 範圍）', () {
    const pet = 80.0;
    // 模擬實測結果：頂端被狀態列壓到 y=24，底部到 y=696（導航列已扣掉）
    const roam = Rect.fromLTRB(0, 24, 320, 696);

    test('fullScreen 就是實測範圍本身', () {
      expect(zoneBounds(roam, pet, PetZone.fullScreen), roam);
    });

    test('下方帶貼著實測底部，厚度 2×petSize', () {
      final band = zoneBounds(roam, pet, PetZone.bottomBand);
      expect(band.bottom, 696);
      expect(band.top, 536);
      expect(band.left, 0);
      expect(band.right, 320);
    });

    test('角落區以該角為錨，邊長 2×petSize', () {
      final br = zoneBounds(roam, pet, PetZone.bottomRight);
      expect(br.right, 320);
      expect(br.bottom, 696);
      expect(br.width, 160);
      expect(br.height, 160);

      final tl = zoneBounds(roam, pet, PetZone.topLeft);
      expect(tl.left, 0);
      expect(tl.top, 24);

      final tr = zoneBounds(roam, pet, PetZone.topRight);
      expect(tr.right, 320);
      expect(tr.top, 24);

      final bl = zoneBounds(roam, pet, PetZone.bottomLeft);
      expect(bl.left, 0);
      expect(bl.bottom, 696);
    });

    test('寵物比區域還大時不會跑出 roam 之外', () {
      for (final zone in PetZone.values) {
        final r = zoneBounds(roam, 900, zone);
        expect(r.left >= roam.left, isTrue, reason: '$zone left');
        expect(r.top >= roam.top, isTrue, reason: '$zone top');
        expect(r.right <= roam.right, isTrue, reason: '$zone right');
        expect(r.bottom <= roam.bottom, isTrue, reason: '$zone bottom');
        expect(r.right >= r.left, isTrue, reason: '$zone right');
        expect(r.bottom >= r.top, isTrue, reason: '$zone bottom');
      }
    });
  });
}
