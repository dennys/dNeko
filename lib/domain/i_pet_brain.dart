import 'dart:ui';
import 'pet_decision.dart';

abstract interface class IPetBrain {
  /// [bond]（0~100）是親密度；目前唯一的用途是提高「主動撒嬌」的機率。
  ///
  /// [isStarving] 要單獨傳：餓昏是餓的**加強版**（見 PetStats.isStarving），
  /// 只傳 isHungry 的話 brain 無法區分「會到處找吃的」與「癱在原地討食裝死」。
  PetDecision decideNext(
    Rect bounds, {
    bool isHungry = false,
    bool isStarving = false,
    double bond = 0,
  });
}