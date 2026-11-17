import 'package:dneko/presentation/widgets/hunger_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 餓昏氣泡的保證只有一條：**沒圖也要有東西、而且不能把 UI 打崩**。
///
/// 內建八隻的餓昏演出目前大半押在它身上 —— `beg`/`faint` 還沒素材的動物是借 sit/sleep
/// 的幀，畫面差別很小，所以「頭上什麼都沒有」等於這功能看不見。
void main() {
  Future<void> pump(WidgetTester tester, String asset) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 60,
              height: 60,
              child: HungerBubble(assetKeyOverride: asset),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HungerBubble', () {
    testWidgets('素材缺檔時退回現畫的氣泡，不丟例外也不留空白', (tester) async {
      await pump(tester, 'assets/images/this_asset_does_not_exist.png');

      expect(tester.takeException(), isNull);
      // 走的是 errorBuilder 那條路徑：改由 _BubblePainter 現畫一顆
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('asset key 含 assets/ 前綴（Image.asset 與 AssetSource 的基準不一樣）', () {
      // 音效那邊是 AssetSource('animals/...')（相對於 assets/），這裡抄錯就永遠缺圖
      expect(HungerBubble.assetKey, startsWith('assets/'));
      expect(HungerBubble.assetKey, endsWith('.png'));
    });
  });
}
