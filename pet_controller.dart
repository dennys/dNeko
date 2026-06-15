import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/animation_action.dart';
import '../domain/pet_behavior.dart';
import '../domain/pet_brain.dart';
import '../domain/movement_engine.dart';
import '../domain/direction_resolver.dart';

class PetController extends ChangeNotifier {
  final PetBrain _brain;
  final MovementEngine _movement;
  final DirectionResolver _direction;
  Rect _bounds;

  PetController({
    required Rect bounds,
    PetBrain? brain,
    MovementEngine? movement,
    DirectionResolver direction = const DirectionResolver(),
  })  : _bounds = bounds,
        _brain = brain ?? PetBrain(),
        _movement = movement ?? const MovementEngine(),
        _direction = direction,
        _position = bounds.center;

  Offset _position;
  Offset get position => _position;

  AnimationAction _action = AnimationAction.sit;
  AnimationAction get action => _action;

  PetBehavior _behavior = PetBehavior.idle;
  Offset? _target;
  Duration _hold = Duration.zero;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void updateBounds(Rect bounds) => _bounds = bounds;

  void _tick() {
    switch (_behavior) {
      case PetBehavior.wander:
      case PetBehavior.goToFood:
        _move();
      default:
        _waitThenDecide();
    }
  }

  void _move() {
    final r = _movement.step(
        current: _position, target: _target!, bounds: _bounds);
    _position = r.position;

    if (r.arrived) {
      // 走向食物 → 抵達後進食；一般遊走 → 重新決策
      if (_behavior == PetBehavior.goToFood) {
        _enter(PetBehavior.eating, action: AnimationAction.affectionate,
            hold: const Duration(seconds: 3));
      } else {
        _applyDecision(_brain.decideNext(_bounds));
      }
    } else {
      _action = _direction.fromVelocity(_target! - _position);
    }
    notifyListeners();
  }

  void _waitThenDecide() {
    _hold -= const Duration(milliseconds: 16);
    if (_hold <= Duration.zero) {
      _applyDecision(_brain.decideNext(_bounds));
      notifyListeners();
    }
  }

  void _applyDecision(PetDecision d) {
    switch (d.behavior) {
      case PetBehavior.wander:
        _enter(PetBehavior.wander, target: d.target);
      case PetBehavior.sleep:
        _enter(PetBehavior.sleep,
            action: AnimationAction.sleep, hold: d.holdTime);
      default:
        _enter(PetBehavior.idle,
            action: AnimationAction.sit, hold: d.holdTime);
    }
  }

  void _enter(PetBehavior b,
      {Offset? target, AnimationAction? action, Duration hold = Duration.zero}) {
    _behavior = b;
    _target = target;
    _hold = hold;
    if (action != null) _action = action;
  }

  // ── 互動入口（見下一節）─────────────────
  void pet() => _enter(PetBehavior.affectionate,
      action: AnimationAction.affectionate, hold: const Duration(seconds: 2));

  void feedAt(Offset foodPosition) =>
      _enter(PetBehavior.goToFood, target: foodPosition);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}