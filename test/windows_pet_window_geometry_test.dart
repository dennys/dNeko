import 'dart:ui';

import 'package:dneko/platform/windows/pet_window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Windows 版把選單疊進**同一顆**視窗，所以每次開選單都要重算視窗範圍。
/// 這裡鎖的是兩條會直接變成-visible-bug 的性質：寵物不能跳位、選單不能超出螢幕。
void main() {
  const petSize = 120.0;
  const menuSize = Size(184, 400);
  const screen = Rect.fromLTWH(0, 0, 1000, 800);

  WindowLayout layoutAt(double x, double y) => layoutWithMenu(
        petPos: Offset(x, y),
        petSize: petSize,
        menuSize: menuSize,
        screen: screen,
      );

  group('layoutWithMenu（Windows 同視窗疊選單）', () {
    test('寵物在視窗內的位置 = 原螢幕位置 − 視窗左上角（開菜單不跳位）', () {
      for (final p in const [Offset(300, 200), Offset(0, 0), Offset(880, 700), Offset(500, 60)]) {
        final layout = layoutAt(p.dx, p.dy);
        expect(
          Offset(layout.window.left + layout.petAt.dx, layout.window.top + layout.petAt.dy),
          offsetMoreOrLessEquals(p, epsilon: 0.01),
          reason: '寵物在螢幕上的位置必须完全不动：$p',
        );
      }
    });

    test('下方放得下時選單開在下面，且整個選單都在視窗內', () {
      final layout = layoutAt(300, 200);
      final menuRect = Rect.fromLTWH(
        layout.window.left + layout.menuAt.dx,
        layout.window.top + layout.menuAt.dy,
        menuSize.width,
        menuSize.height,
      );
      expect(menuRect.top, greaterThanOrEqualTo(200 + petSize)); // 在寵物下方
      expect(layout.window.contains(menuRect.center), isTrue);
      expect(layout.window.right, greaterThanOrEqualTo(menuRect.right));
      expect(layout.window.bottom, greaterThanOrEqualTo(menuRect.bottom));
    });

    test('下方放不下時往上長，視窗仍包住寵物與選單', () {
      final layout = layoutAt(300, 700); // 寵物貼底，下方只剩 800-820 < 0
      final menuRect = Rect.fromLTWH(
        layout.window.left + layout.menuAt.dx,
        layout.window.top + layout.menuAt.dy,
        menuSize.width,
        menuSize.height,
      );
      expect(menuRect.bottom, lessThanOrEqualTo(700)); // 整個選單在寵物上方
      expect(layout.window.top, lessThanOrEqualTo(menuRect.top));
      expect(layout.window.top, lessThanOrEqualTo(700)); // 也包住寵物
      expect(layout.window.bottom, greaterThanOrEqualTo(700 + petSize - 0.01));
    });

    test('貼右下角時選單被夾進螢幕內（不溢出到螢幕外）', () {
      final layout = layoutAt(950, 400);
      final menuRect = Rect.fromLTWH(
        layout.window.left + layout.menuAt.dx,
        layout.window.top + layout.menuAt.dy,
        menuSize.width,
        menuSize.height,
      );
      expect(menuRect.left, greaterThanOrEqualTo(screen.left));
      expect(menuRect.right, lessThanOrEqualTo(screen.right + 0.01));
      expect(menuRect.top, greaterThanOrEqualTo(screen.top));
      expect(menuRect.bottom, lessThanOrEqualTo(screen.bottom + 0.01));
    });

    test('寵物在左上角時選單與視窗都不出界（左/上邊界）', () {
      final layout = layoutAt(0, 0);
      expect(layout.window.left, greaterThanOrEqualTo(0));
      expect(layout.window.top, greaterThanOrEqualTo(0));
      expect(layout.window.width, greaterThanOrEqualTo(petSize));
      expect(layout.window.height, greaterThanOrEqualTo(petSize));
    });

    test('視窗是寵物與選單的並集：不會比任一元素小', () {
      final layout = layoutAt(300, 200);
      const petRect = Rect.fromLTWH(300, 200, petSize, petSize);
      // Rect 沒有 area（dart:ui），用兩個對角點確認寵物完整落在視窗裡
      expect(layout.window.contains(petRect.topLeft), isTrue);
      expect(layout.window.contains(petRect.bottomRight), isTrue);
    });
  });
}
