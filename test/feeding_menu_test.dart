import 'package:dneko/presentation/widgets/feeding_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選單是第二個懸浮視窗，視窗高度由 [FeedingMenu.contentHeight] 算出來
/// （`menu_main.kMenuWindowSize`），所以這裡守兩件事：
/// 1. 內容不能比聲稱的高度高（會 RenderFlex overflow，選單被切一半）；
/// 2. 定格時那 6 個動作格要「變灰 + 按了沒反應」（`PetController.playFlourish` 本來就會
///    靜默丟掉，与其讓使用者以為壞掉，不如按不下去）。
void main() {
  Widget menu({
    List<FeedingMenuTile>? tiles,
    String? footnote,
    VoidCallback? onInteract,
  }) =>
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: FeedingMenu.contentWidth,
            height: FeedingMenu.contentHeight,
            child: FeedingMenu(
              feedLabel: '餵食',
              petLabel: '摸',
              closeLabel: '收起來',
              freezeLabel: '定格',
              quitLabel: '結束',
              onFeed: () {},
              onPet: () {},
              onFreeze: () {},
              onClose: () {},
              onQuit: () {},
              onInteract: onInteract,
              footnote: footnote,
              tiles: tiles ??
                  [
                    for (final name in ['張望', '打盹', '搖擺', '跳跳', '伸懶腰', '轉圈'])
                      FeedingMenuTile(icon: Icons.star, label: name, onTap: () {}),
                  ],
            ),
          ),
        ),
      );

  group('FeedingMenu', () {
    test('高度夠放 5 列 + 3 行網格 + 小字那行', () {
      // contentHeight 是手算的常數，加減區塊忘記同步就會在真機上 overflow
      expect(FeedingMenu.contentHeight, greaterThan(5 * 44 + 3 * 52));
    });

    testWidgets('照 contentHeight 擺不會 overflow（有無小字都要）', (tester) async {
      for (final note in [null, '餵食會解除定格']) {
        await tester.pumpWidget(menu(footnote: note));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'footnote=$note');
      }
    });

    testWidgets('小字那行畫得出來', (tester) async {
      await tester.pumpWidget(menu(footnote: '餵食會解除定格'));
      expect(find.text('餵食會解除定格'), findsOneWidget);
    });

    testWidgets('定格時動作格變灰、按了沒反應，也不該重置自動關閉計時器', (tester) async {
      var taps = 0;
      var interacts = 0;
      final tiles = [
        for (final name in ['張望', '打盹', '搖擺', '跳跳', '伸懶腰'])
          FeedingMenuTile(icon: Icons.star, label: name, onTap: () => taps++),
        FeedingMenuTile(icon: Icons.star, label: '轉圈', enabled: false, onTap: () => taps++),
      ];
      await tester.pumpWidget(menu(
        tiles: tiles,
        onInteract: () => interacts++,
      ));

      await tester.tap(find.text('張望'));
      await tester.pump();
      expect(taps, 1, reason: '正常的格子按得動');
      expect(interacts, 1);

      await tester.tap(find.text('轉圈'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1, reason: '定格中的動作格不該有反應');
      expect(interacts, 1, reason: '按不下去就不該重新計時（否則選單永遠不會自己關）');
    });
  });
}
