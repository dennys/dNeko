import 'package:dneko/presentation/widgets/hunger_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 餓度列同時是「餓昏快到了」的報信器：小孩不會為了看牠裝死乾等一個多小時，
/// 所以要能在條上看出那條線在哪、過線之後顏色也要不一樣。
void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required double hunger,
    double threshold = 60,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: HungerBar(hunger: hunger, threshold: threshold),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HungerBar 餓昏態', () {
    testWidgets('未過餓昏線：餐廳圖示（餓了但還在正常範圍內是紅色）', (tester) async {
      await pumpBar(tester, hunger: 70);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsNothing);
    });

    testWidgets('過餓昏線：換成火苗，不看數字也看得出牠餓昏了', (tester) async {
      await pumpBar(tester, hunger: 90);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('餓昏線刻痕不會把進度列搞 overflow（深浅色都要）', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            // ignore: prefer_const_constructors -- ColorScheme.fromSeed 不是 const 建構子
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: brightness),
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 220,
                child: HungerBar(hunger: 42, threshold: 60),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'brightness=$brightness');
      }
    });

    testWidgets('門檻拉到 slider 上限也不會把刻痕畫到軌道外', (tester) async {
      await pumpBar(tester, hunger: 100, threshold: 100);
      expect(tester.takeException(), isNull);
    });
  });
}
