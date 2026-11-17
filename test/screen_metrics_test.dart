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

    test('fallbackRoam 扣掉寵物大小＋頂端偏移狀態列（A-4b）', () {
      // top=25（狀態列），height=800-80-25=695
      expect(metrics.fallbackRoam(80), const Rect.fromLTWH(0, 25, 320, 695));
    });
  });

  group('zoneBounds（吃實測的 roam 範圍）', () {
    const pet = 80.0;
    // 模擬實測結果：頂端被狀態列壓到 y=24，底部到 y=696（導航列已扣掉）
    const roam = Rect.fromLTRB(0, 24, 320, 696);

    test('fullScreen 就是實測範圍本身', () {
      expect(metrics.zoneBounds(roam, pet, PetZone.fullScreen), roam);
    });

    // 定義（2026-11-17 改）：設定值 = **可見帶高 ÷ 螢幕高**。`roam` 給的是視窗左上角的
    // 可行域，所以可見帶高 = 厚度 + 視窗邊長；舊實作厚度寫死 `petSize × 2`，等於
    // 「可見 3 × petSize」（預設 120 在 800 高螢幕上是 45%），還隨寵物大小膨縮。
    test('下方帶：可見帶高 = fraction × 螢幕高（厚度要減一個寵物高）', () {
      // 螢幕 800 × 0.5 = 可見 400；左上角厚度 = 400 - 80 = 320
      final band = metrics.zoneBounds(roam, pet, PetZone.bottomBand, bottomBandFraction: 0.5);
      expect(band.bottom, 696);
      expect(band.top, 376);
      expect(band.left, 0);
      expect(band.right, 320);
      expect(band.height + pet, closeTo(400, 0.001));
    });

    test('預設 0.22 就是螢幕的 22%', () {
      final band = metrics.zoneBounds(roam, pet, PetZone.bottomBand);
      expect(band.height + pet, closeTo(800 * PetSettings.defaultBottomBandFraction, 0.001));
    });

    test('調大寵物不會讓那條帶變寬（舊實作會跟著膨）', () {
      for (final size in [80.0, 120.0]) {
        final band = metrics.zoneBounds(roam, size, PetZone.bottomBand, bottomBandFraction: 0.5);
        expect(band.height + size, closeTo(400, 0.001), reason: 'petSize=$size');
      }
    });

    test('帶比寵物還矮 → 厚度收 0，牠貼底坐著（不會算出負 Rect）', () {
      // 800 × 0.22 = 176 < 寵物 180
      final band = metrics.zoneBounds(roam, 180, PetZone.bottomBand);
      expect(band.height, 0);
      expect(band.top, band.bottom);
      expect(band.bottom, 696);
    });

    test('fraction 1.0 等於全螢幕；下限 0.1 也不會算出負 Rect', () {
      expect(
        metrics.zoneBounds(roam, pet, PetZone.bottomBand, bottomBandFraction: 1.0).top,
        roam.top,
      );
      final thin = metrics.zoneBounds(roam, pet, PetZone.bottomBand, bottomBandFraction: 0.1);
      expect(thin.height, 0);
      expect(thin.bottom, 696);
    });

    test('角落區以該角為錨，邊長 2×petSize', () {
      final br = metrics.zoneBounds(roam, pet, PetZone.bottomRight);
      expect(br.right, 320);
      expect(br.bottom, 696);
      expect(br.width, 160);
      expect(br.height, 160);

      final tl = metrics.zoneBounds(roam, pet, PetZone.topLeft);
      expect(tl.left, 0);
      expect(tl.top, 24);

      final tr = metrics.zoneBounds(roam, pet, PetZone.topRight);
      expect(tr.right, 320);
      expect(tr.top, 24);

      final bl = metrics.zoneBounds(roam, pet, PetZone.bottomLeft);
      expect(bl.left, 0);
      expect(bl.bottom, 696);
    });

    test('寵物比區域還大時不會跑出 roam 之外', () {
      for (final zone in PetZone.values) {
        final r = metrics.zoneBounds(roam, 900, zone);
        expect(r.left >= roam.left, isTrue, reason: '$zone left');
        expect(r.top >= roam.top, isTrue, reason: '$zone top');
        expect(r.right <= roam.right, isTrue, reason: '$zone right');
        expect(r.bottom <= roam.bottom, isTrue, reason: '$zone bottom');
        expect(r.right >= r.left, isTrue, reason: '$zone right');
        expect(r.bottom >= r.top, isTrue, reason: '$zone bottom');
      }
    });
  });

  group('previewBounds（主頁預覽塊）', () {
    test('回的是「精靈左上角可達範圍」，所以要扣掉寵物大小', () {
      expect(previewBounds(const Size(400, 196), 120), const Rect.fromLTWH(0, 0, 280, 76));
    });

    test('寵物比區塊還大時夾成零大小，不要給負寬高（會把精靈丟到負座標）', () {
      expect(previewBounds(const Size(100, 100), 180), const Rect.fromLTWH(0, 0, 0, 0));
    });

    test('高度 0 的區塊不會炸', () {
      expect(previewBounds(const Size(400, 0), 80), const Rect.fromLTWH(0, 0, 320, 0));
    });
  });
}
