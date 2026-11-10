import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/menu_placement.dart';
import 'package:dneko/domain/pet_settings.dart';
import 'package:dneko/domain/screen_metrics.dart';

void main() {
  // 可漫遊範圍：寬 400、高 800（頂端座標 0..400 / 0..800）；動物 120，選單 240x300
  const roam = Rect.fromLTRB(0, 0, 400, 800);
  const petSize = 120.0;
  const menuW = 240.0;
  const menuH = 300.0;

  MenuPlacement place(Offset pet, {Rect? inRoam, double menuHeight = menuH}) =>
      placeMenu(
        petPos: pet,
        roam: inRoam ?? roam,
        petSize: petSize,
        menuWidth: menuW,
        menuHeight: menuHeight,
      );

  group('placeMenu', () {
    test('動物在畫面中間：選單朝下長，動物位置不動', () {
      final p = place(const Offset(100, 100));
      expect(p.above, isFalse);
      expect(p.topLeft.dy, 100, reason: '朝下長，動物的 y 不動');
    });

    test('寬度變大時水平置中回動物原本的位置', () {
      // 動物 x=100，選單比動物寬 120，所以左移 60
      final p = place(const Offset(100, 100));
      expect(p.topLeft.dx, 40);
    });

    test('動物貼近底部放不下：選單朝上長，動物固定在視窗底部', () {
      // 下方空間不夠（maxTop = 800 + 120 - 300 = 620），上方夠
      final p = place(const Offset(100, 700));
      expect(p.above, isTrue);
      // 上長時視窗 y = 動物 y - (選單高 - 動物高)
      expect(p.topLeft.dy, 700 - (menuH - petSize));
    });

    test('水平靠右邊界：選單夾回不超出右邊', () {
      // x=350 → 置中後 290，但 maxLeft = 400 + 120 - 240 = 280
      final p = place(const Offset(350, 100));
      expect(p.topLeft.dx, 280);
    });

    test('水平靠左邊界：選單夾回不超出左邊', () {
      // x=0 → 置中後 -60，夾回 roam.left = 0
      final p = place(const Offset(0, 100));
      expect(p.topLeft.dx, 0);
    });

    test('上下都放不下時 y 夾回 roam 頂端，不出界', () {
      // 很窄的範圍：高 300，選單 500 高，上下都裝不下
      const narrow = Rect.fromLTRB(0, 0, 400, 300);
      final p = place(const Offset(100, 200), inRoam: narrow, menuHeight: 500);
      expect(p.topLeft.dy, narrow.top);
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
      final bounds = zoneBounds(roam, petSize, PetZone.topLeft);
      expect(bounds.top, roam.top, reason: 'topLeft 區頂端要等於 roam 頂端（已含狀態列偏移）');
      expect(bounds.top, greaterThan(0), reason: '不能貼物理螢幕頂（A-4b）');
    });

    test('高度扣掉狀態列，不超出螢幕', () {
      final roam = metrics.fallbackRoam(petSize);
      expect(roam.bottom, lessThanOrEqualTo(800), reason: 'fallbackRoam 不能超出螢幕底部');
    });
  });
}
