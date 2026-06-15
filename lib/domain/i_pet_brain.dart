import 'dart:ui';
import 'pet_decision.dart';

abstract interface class IPetBrain {
  PetDecision decideNext(Rect bounds, {bool isHungry = false});
}