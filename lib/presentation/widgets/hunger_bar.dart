import 'package:flutter/material.dart';
import '../../domain/pet_stats.dart';

/// 只負責：顯示飢餓值的進度列
///
/// 收 `double` 而不是 `PetStats`：主頁要顯示的是**存盤的那個值**（從 DB 讀出來的純數字，
/// 那邊並沒有一隻活的寵物），為了顯示一個數字去 new 一個 PetStats 不划算。
///
/// [threshold] 是「餓的門檻」（點數）：變紅的顏色跟 isHungry 用同一個來源，
/// 門檻改成設定後（PetSettings.hungerMinutesUntilHungry）兩邊不會對不起來。
///
/// 餓昏線（變橘色 + 軌道上那條直線）由 [PetStats.starvingThresholdAt] 從同一個門檻推出來，
/// 不是第二個門檻：**不餵到那條線牠就開始討食裝死**，先讓小孩看得見它在逼近，
/// 否則這功能等於要人乾等一個多小時。
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
    // 判準一律走 PetStats.isHungryAt（與 PetStats.isHungry 同一個來源）
    final starving = PetStats.isHungryAt(hunger, PetStats.starvingThresholdAt(threshold));
    final hungry = PetStats.isHungryAt(hunger, threshold);
    final color = starving
        ? const Color(0xFFE65100) // 餓昏：比紅更「重」一档，但不做成血紅（調性是滑稽不是可憐）
        : hungry
            ? Colors.redAccent
            : Colors.green;
    // -track- 色在深色模式下 black12 幾乎看不見（DEVICE_TEST A-6b）
    final track = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black12;

    return Row(
      children: [
        Icon(starving ? Icons.local_fire_department : Icons.restaurant, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: track,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                // 餓昏線：軌道上的一道刻痕（不用看數字也知道還剩多少）
                Align(
                  alignment: Alignment(_starvingAlignment(threshold), 0),
                  child: Container(
                    width: 2,
                    height: 8,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${hunger.toInt()}'),
      ],
    );
  }
}

/// 餓昏線在軌道上的位置（Alignment 的 -1..1 正好對應 0..1 的比例）。
double _starvingAlignment(double threshold) =>
    (PetStats.starvingThresholdAt(threshold) / PetStats.maxHunger).clamp(0.0, 1.0) * 2 - 1;
