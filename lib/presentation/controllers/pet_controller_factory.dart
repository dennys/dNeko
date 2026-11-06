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
  }) {
    final edge = _edgeFactory.create(definition.edgeBehavior);
    return PetController(
      bounds: bounds,
      edge: edge,
      speedPerTick: speedPerTick,
      stats: stats,
    );
  }
}