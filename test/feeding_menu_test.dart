import 'package:dneko/domain/menu_payload.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/presentation/widgets/feeding_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選單是第二個懸浮視窗，視窗高度由 [FeedingMenu.contentHeight] 算出來
/// （`menu_main.kMenuWindowSize`），所以這裡守兩件事：
/// 1. 內容不能比聲稱的高度高（會 RenderFlex overflow，選單被切一半）；
/// 2. 那些動作格**永遠按得下去**（定格時也一樣：`PetController.playFlourish` 會自己
///    解除定格再播），而且按下去要重新計自動關閉的時間。
///
/// 測試用的格子清單直接從 `kFlourishBehaviors` 生成（加減動作時這裡不會先爛在測試裡）。
/// 與選單同長度的格子（標籤用行為名，測試就靠它找格）
List<FeedingMenuTile> defaultTiles({VoidCallback? onTap}) => [
      for (final behavior in kFlourishBehaviors)
        FeedingMenuTile(icon: Icons.star, label: behavior.name, onTap: onTap ?? () {}),
    ];

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
              tiles: tiles ?? defaultTiles(),
            ),
          ),
        ),
      );

  group('FeedingMenu', () {
    test('高度夠放 5 列 + 4 行網格 + 小字那行', () {
      // contentHeight 是手算的常數，加減區塊忘記同步就會在真機上 overflow
      expect(FeedingMenu.contentHeight, greaterThan(5 * 44 + 4 * 52));
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

    testWidgets('每一格都按得動，而且按下去會重新計自動關閉的時間', (tester) async {
      var taps = 0;
      var interacts = 0;
      await tester.pumpWidget(menu(
        tiles: defaultTiles(onTap: () => taps++),
        onInteract: () => interacts++,
      ));

      // 含餓昏那兩格（討食/裝死）：不分狀態都要能按 —— 小孩不會等一個多小時看牠裝死
      for (final name in [PetBehavior.lookAround.name, PetBehavior.circle.name,
          PetBehavior.beg.name, PetBehavior.faint.name]) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      expect(taps, 4, reason: '每一格都是活的（定格中也該按得下去）');
      expect(interacts, 4, reason: '按到就該重新計時（否則使用者一直按，選單還是會自己關）');
    });
  });
}
