import 'dart:ui';
import '../../data/models/animation_definition.dart';
import '../../domain/edge_behavior_factory.dart';
import '../../domain/pet_stats.dart';
import 'pet_controller.dart';

/// 只負責：依動畫定義（含個性設定）組裝 PetController
class PetControllerFactory {
  final EdgeBehaviorFactory _edgeFactory;

  const PetControllerFactory({
    this._edgeFactory = const EdgeBehaviorFactory(),
  });

  PetController create({
    required Rect bounds,
    required AnimalAnimationDefinition definition,
    double? speedPerTick,
    PetStats? stats,
    Offset? position,
    bool frozen = false,
  }) {
    final edge = _edgeFactory.create(definition.edgeBehavior);
    final controller = PetController(
      bounds: bounds,
      edge: edge,
      speedPerTick: speedPerTick,
      stats: stats,
      position: position,
    );
    // 換動物時保留定格狀態（A-9a）：setFrozen 在 _frozen 相同時 early-return，
    // 所以只在需要時呼叫。
    if (frozen) controller.setFrozen(true);
    return controller;
  }
}