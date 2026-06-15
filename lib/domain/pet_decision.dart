import 'dart:ui';
import 'pet_behavior.dart';

class PetDecision {
  final PetBehavior behavior;
  final Offset? target; // wander / goToFood 才有
  final Duration holdTime; // idle / sleep / eating 停留時間

  const PetDecision(
    this.behavior, {
    this.target,
    this.holdTime = Duration.zero,
  });
}