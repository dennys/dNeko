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
import '../../domain/pet_settings.dart';

class PetController extends ChangeNotifier {
  static const _tick = petTick; // 與 PetSettings.speedPerTick 的換算共用同一個來源

  final IPetBrain _brain;
  IMovementEngine _movement;
  final DirectionResolver _direction;
  final PetStats _stats;
  final IEdgeBehavior _edge; // 新增
  Rect _bounds;

  PetController({
    required Rect bounds,
    PetStats? stats,
    IPetBrain? brain,
    IMovementEngine? movement,
    double? speedPerTick,
    IEdgeBehavior? edge, // 新增（預設沿邊走）
    this._direction = const DirectionResolver(),
  })  : _bounds = bounds,
        _ownsStats = stats == null,
        _stats = stats ?? PetStats(),
        _brain = brain ?? PetBrain(),
        // 速度預設只有 MovementEngine 一處定義（這裡不再抄一份 1.5）
        _movement = movement ?? (speedPerTick == null ? const MovementEngine() : MovementEngine(speedPerTick: speedPerTick)),
        _edge = edge ?? EdgeWalkBehavior(),
        _position = bounds.center;

  Offset _position;
  Offset get position => _position;

  /// 上次「對外發過通知」時的位置與動作。
  ///
  /// 主迴圈 16ms 一跳、每跳都 notifyListeners() 的話，overlay 那側固定 60 次/秒重建
  /// widget，即使畫面根本沒變。這裡把通知收在「看得見的變化」：整數像素動了、
  /// 或動作換了。[OverlayPetDriver] 本來也是以 1px 為單位過濾，兩邊基準一致。
  Offset? _lastNotifiedAt;
  AnimationAction? _lastNotifiedAction;

  /// 只有 [stats] 是外部注入時才由注入方負責dispose；自己 new 的就自己關。
  final bool _ownsStats;

  Rect get bounds => _bounds;

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

  /// 設定頁改速度時即時生效（不必重開 overlay）
  void setSpeedPerTick(double speedPerTick) =>
      _movement = MovementEngine(speedPerTick: speedPerTick);

  void pet() => _enter(
        PetBehavior.affectionate,
        action: AnimationAction.affectionate,
        hold: const Duration(seconds: 2),
      );

  /// 食物落點一律夾進可漫遊範圍，否則牠會永遠抵著邊走不到。
  void feedAt(Offset foodPosition) {
    _frozen = false; // 餵食是明確動作，會解除定格，否則走不過去
    _enter(PetBehavior.goToFood, target: _clampToBounds(foodPosition));
  }

  void beginDrag() {
    _isDragging = true;
    _enter(PetBehavior.idle, action: AnimationAction.affectionate);
    _notifyIfChanged();
  }

  void dragTo(Offset position) {
    if (!_isDragging) return;
    _position = _clampToBounds(position);
    _notifyIfChanged();
  }

  /// 原生拖曳期間由 overlay 輪詢視窗座標後呼叫（不 clamp，不影響 driver）
  void syncFromWindow(Offset p) {
    _position = p;
    _notifyIfChanged();
  }

  void endDrag() {
    _isDragging = false;
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
    _notifyIfChanged();
  }

  /// 定格：停止自主移动與行為切換（饑餓仍照常累積）。只能手動解除。
  bool _frozen = false;
  bool get frozen => _frozen;

  void setFrozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    if (!_frozen) {
      _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
      _notifyIfChanged();
    }
  }

  void _onTick() {
    _stats.tick(_tick);
    if (_isDragging || _frozen) return;

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
      _notifyIfChanged();
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
    _notifyIfChanged();
  }

  void _waitThenDecide() {
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry));
    _notifyIfChanged();
  }

  void _notifyIfChanged() {
    final at = _position;
    final last = _lastNotifiedAt;
    final moved = last == null || (at.dx - last.dx).abs() >= 1 || (at.dy - last.dy).abs() >= 1;
    final actionChanged = _lastNotifiedAction != _action;
    if (!moved && !actionChanged) return;
    _lastNotifiedAt = at;
    _lastNotifiedAction = _action;
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
    // 狀態換了就在這裡通知：`pet()` 這種「只換動作、位置不動」的入口如果交給呼叫端
    // 通知，按「撫摸」後會被 hold 擋住（2 秒內沒有任何 notify），撒嬌動畫根本不會出現。
    _notifyIfChanged();
  }

  Offset _clampToBounds(Offset p) => Offset(
        p.dx.clamp(_bounds.left, _bounds.right),
        p.dy.clamp(_bounds.top, _bounds.bottom),
      );

  @override
  void dispose() {
    _timer?.cancel();
    // 自己建的 stats 要跟著關；外部注入的（overlay 會注入持久化的餓度）由注入方負責。
    if (_ownsStats) _stats.dispose();
    super.dispose();
  }
}