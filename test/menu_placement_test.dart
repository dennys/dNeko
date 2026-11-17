import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/menu_placement.dart';
import 'package:dneko/domain/pet_settings.dart';
import 'package:dneko/domain/screen_metrics.dart';

void main() {
  // 可漫遊範圍：寬 400、高 800（頂端 0..400 / 0..800）；動物 120
  const roam = Rect.fromLTRB(0, 0, 400, 800);
  const petSize = 120.0;

  group('placeMenuWindow（選單是另一個視窗）', () {
    const menuSize = Size(184, 430);
    const gap = 8.0;

    MenuPlacement placeWindow(Offset pet) => placeMenuWindow(
          petPos: pet,
          petSize: petSize,
          roam: roam,
          menuSize: menuSize,
          gap: gap,
        );

    test('動物在畫面中間：選單開在下方，中間留 gap，水平對齊動物', () {
      final p = placeWindow(const Offset(100, 100));
      expect(p.above, isFalse);
      expect(p.topLeft.dy, 100 + petSize + gap);
      expect(p.topLeft.dx, 100 + petSize / 2 - menuSize.width / 2);
    });

    test('選單不能蓋到動物：下方的選單頂端至少要在動物底部 + gap', () {
      final p = placeWindow(const Offset(100, 100));
      expect(p.topLeft.dy, greaterThanOrEqualTo(100 + petSize + gap));
    });

    test('動物貼著底部：選單改開在上方，底邊貼著動物頂端 - gap', () {
      final p = placeWindow(const Offset(100, 700));
      expect(p.above, isTrue);
      expect(p.topLeft.dy, 700 - gap - menuSize.height);
    });

    test('水平靠右：選單夾進 roam，不超出右邊', () {
      final p = placeWindow(const Offset(380, 100));
      expect(p.topLeft.dx + menuSize.width, lessThanOrEqualTo(roam.right));
    });

    test('上下都放不下：選單整塊夾進 roam（不能溢出螢幕）', () {
      final p = placeWindow(const Offset(100, 300));
      expect(p.topLeft.dy, greaterThanOrEqualTo(roam.top));
      expect(p.topLeft.dy + menuSize.height, lessThanOrEqualTo(roam.bottom));
    });

    test('選單比 roam 還高時退化為貼頂，不會得到負座標', () {
      final p = placeMenuWindow(
        petPos: const Offset(10, 10),
        petSize: petSize,
        roam: const Rect.fromLTRB(0, 0, 400, 200),
        menuSize: menuSize,
      );
      expect(p.topLeft.dy, 0);
      expect(p.topLeft.dx, greaterThanOrEqualTo(0));
    });
  });

  group('ScreenMetrics.clampPetPosition', () {
    const metrics = ScreenMetrics(logicalSize: Size(400, 800), devicePixelRatio: 2);

    test('範圍內的座標原樣保留', () {
      expect(metrics.clampPetPosition(const Offset(50, 60), petSize), const Offset(50, 60));
    });

    test('負座標夾回 0', () {
      expect(metrics.clampPetPosition(const Offset(-10, -5), petSize), Offset.zero);
    });

    test('超出右下角夾回「螢幕 - 動物」的最大值', () {
      // maxX = 400 - 120 = 280，maxY = 800 - 120 = 680
      expect(metrics.clampPetPosition(const Offset(900, 900), petSize), const Offset(280, 680));
    });

    test('螢幕比動物還小時夾成 0，不會得到負值', () {
      const tiny = ScreenMetrics(logicalSize: Size(100, 100), devicePixelRatio: 2);
      expect(tiny.clampPetPosition(const Offset(50, 50), petSize), Offset.zero);
    });
  });

  group('ScreenMetrics.fallbackRoam（A-4b topInset）', () {
    const metrics = ScreenMetrics(logicalSize: Size(400, 800), devicePixelRatio: 2);

    test('頂端偏移狀態列高度（不是 0）', () {
      final roam = metrics.fallbackRoam(petSize);
      expect(roam.top, 25, reason: 'fallbackRoam 頂端要偏移狀態列高度（A-4b）');
    });

    test('zoneBounds(topLeft) 在 fallbackRoam 頂端以下', () {
      final roam = metrics.fallbackRoam(petSize);
      final bounds = metrics.zoneBounds(roam, petSize, PetZone.topLeft);
      expect(bounds.top, roam.top, reason: 'topLeft 區頂端要等於 roam 頂端（已含狀態列偏移）');
      expect(bounds.top, greaterThan(0), reason: '不能貼物理螢幕頂（A-4b）');
    });

    test('高度扣掉狀態列，不超出螢幕', () {
      final roam = metrics.fallbackRoam(petSize);
      expect(roam.bottom, lessThanOrEqualTo(800), reason: 'fallbackRoam 不能超出螢幕底部');
    });
  });
}
