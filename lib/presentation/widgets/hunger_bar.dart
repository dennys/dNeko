import 'package:flutter/material.dart';
import '../../domain/pet_stats.dart';

/// 只負責：顯示飢餓值的進度列
///
/// 收 `double` 而不是 `PetStats`：主頁要顯示的是**存盤的那個值**（從 DB 讀出來的純數字，
/// 那邊並沒有一隻活的寵物），為了顯示一個數字去 new 一個 PetStats 不划算。
///
/// [threshold] 是「餓的門檻」（點數）：變紅的顏色跟 isHungry 用同一個來源，
/// 門檻改成設定後（PetSettings.hungerMinutesUntilHungry）兩邊不會對不起來。
class HungerBar extends StatelessWidget {
  final double hunger;
  final double threshold;

  const HungerBar({
    super.key,
    required this.hunger,
    this.threshold = PetStats.defaultHungryThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (hunger / PetStats.maxHunger).clamp(0.0, 1.0);
    final hungry = hunger >= threshold;
    final color = hungry ? Colors.redAccent : Colors.green;
    // -track- 色在深色模式下 black12 幾乎看不見（DEVICE_TEST A-6b）
    final track = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black12;

    return Row(
      children: [
        Icon(Icons.restaurant, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${hunger.toInt()}'),
      ],
    );
  }
}
