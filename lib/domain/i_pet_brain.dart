import 'dart:ui';
import 'pet_decision.dart';

abstract interface class IPetBrain {
  /// [bond]（0~100）是親密度；目前唯一的用途是提高「主動撒嬌」的機率。
  PetDecision decideNext(Rect bounds, {bool isHungry = false, double bond = 0});
}