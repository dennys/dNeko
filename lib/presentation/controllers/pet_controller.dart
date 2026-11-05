import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../data/models/animation_action.dart';
import '../../domain/pet_behavior.dart';
import '../../domain/pet_decision.dart';
import '../../domain/pet_stats.dart';
import '../../domain/edge_behavior.dart';
import '../../domain/i_pet_brain.dart';
import '../../domain/pet_brain.dart';
import '../../domain/i_movement_engine.dart';
import '../../domain/movement_engine.dart';
import '../../domain/direction_resolver.dart';

class PetController extends ChangeNotifier {
  static const _tick = Duration(milliseconds: 16);

  final IPetBrain _brain;
  final IMovementEngine _movement;
  final DirectionResolver _direction;
  final PetStats _stats;
  final IEdgeBehavior _edge; // 新增
  Rect _bounds;

  PetController({
    required Rect bounds,
    PetStats? stats,
    IPetBrain? brain,
    IMovementEngine? movement,
    IEdgeBehavior? edge, // 新增（預設沿邊走）
    this._direction = const DirectionResolver(),
  })  : _bounds = bounds,
        _stats = stats ?? PetStats(),
        _brain = brain ?? PetBrain(),
        _movement = movement ?? const MovementEngine(),
        _edge = edge ?? EdgeWalkBehavior(),
        _position = bounds.center;

  Offset _position;
  Offset get position => _position;

  PetStats get stats => _stats;

  AnimationAction _action = AnimationAction.sit;
  AnimationAction get action => _action;

  PetBehavior _behavior = PetBehavior.idle;
  Offset? _target;
  Duration _hold = Duration.zero;
  bool _isDragging = false;
  Timer? _timer;

  void start() => _timer ??= Timer.periodic(_tick, (_) => _onTick());

  void updateBounds(Rect bounds) => _bounds = bounds;

  void pet() => _enter(
        PetBehavior.affectionate,
        action: AnimationAction.affectionate,
        hold: const Duration(seconds: 2),
      );

  void feedAt(Offset foodPosition) =>
      _enter(PetBehavior.goToFood, target: foodPosition);

  void beginDrag() {
    _isDragging = true;
    _enter(PetBehavior.idle, action: AnimationAction.affectionate);
    notifyListeners();
  }

  void dragTo(Offset position) {
    if (!_isDragging) return;
    _position = _clampToBounds(position);
    notifyListeners();
  }

  void endDrag() {
    _isDragging = false;
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
    notifyListeners();
  }

  void _onTick() {
    _stats.tick(_tick);
    if (_isDragging) return;

    if (_behavior == PetBehavior.wander || _behavior == PetBehavior.goToFood) {
      _move();
      return;
    }
    _waitThenDecide();
  }

  void _move() {
    final result = _movement.step(
      current: _position,
      target: _target!,
      bounds: _bounds,
    );
    _position = result.position;

    // 漫遊途中貼到邊緣 → 交給邊緣策略決定新目標（餵食途中不打斷）
    if (_behavior == PetBehavior.wander &&
        _edge.isAtEdge(_position, _bounds)) {
      _target = _edge.nextTargetOnEdge(_position, _bounds);
    }

    if (!result.arrived) {
      _action = _direction.fromVelocity(_target! - _position);
      notifyListeners();
      return;
    }

    if (_behavior == PetBehavior.goToFood) {
      _stats.feed();
      _enter(
        PetBehavior.eating,
        action: AnimationAction.eat,
        hold: const Duration(seconds: 3),
      );
    } else if (_edge.isAtEdge(_position, _bounds)) {
      // 抵達且仍在邊緣 → 繼續沿邊/回頭，不發呆
      _enter(PetBehavior.wander,
          target: _edge.nextTargetOnEdge(_position, _bounds));
    } else {
      _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
    }
    notifyListeners();
  }

  void _waitThenDecide() {
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
    notifyListeners();
  }

  void _applyDecision(PetDecision decision) {
    switch (decision.behavior) {
      case PetBehavior.wander:
        _enter(PetBehavior.wander, target: decision.target);
      case PetBehavior.sleep:
        _enter(PetBehavior.sleep,
            action: AnimationAction.sleep, hold: decision.holdTime);
      default:
        _enter(PetBehavior.idle,
            action: AnimationAction.sit, hold: decision.holdTime);
    }
  }

  void _enter(
    PetBehavior behavior, {
    Offset? target,
    AnimationAction? action,
    Duration hold = Duration.zero,
  }) {
    _behavior = behavior;
    _target = target;
    _hold = hold;
    if (action != null) _action = action;
  }

  Offset _clampToBounds(Offset p) => Offset(
        p.dx.clamp(_bounds.left, _bounds.right),
        p.dy.clamp(_bounds.top, _bounds.bottom),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}