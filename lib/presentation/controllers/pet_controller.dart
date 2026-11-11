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
    Offset? position,
  })  : _bounds = bounds,
        _ownsStats = stats == null,
        _stats = stats ?? PetStats(),
        _brain = brain ?? PetBrain(),
        // 速度預設只有 MovementEngine 一處定義（這裡不再抄一份 1.5）
        _movement = movement ?? (speedPerTick == null ? const MovementEngine() : MovementEngine(speedPerTick: speedPerTick)),
        _edge = edge ?? EdgeWalkBehavior(),
        _position = bounds.center {
    // 換動物時帶入舊位置（A-9a）：舊 controller 的位置可能在新 bounds 外，夾回邊界。
    if (position != null) _position = _clampToBounds(position);
  }

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

  /// 換 zone／螢幕後換 bounds：位置與目標都要夾回新範圍，
  /// 否則寵物會留在舊區外，直到下一次 wander 決定才「瞬移」回來。
  void updateBounds(Rect bounds) {
    _bounds = bounds;
    _position = _clampToBounds(_position);
    final target = _target;
    if (target != null) _target = _clampToBounds(target);
    _notifyIfChanged();
  }

  /// 設定頁改速度時即時生效（不必重開 overlay）
  void setSpeedPerTick(double speedPerTick) =>
      _movement = MovementEngine(speedPerTick: speedPerTick);

  /// 一次性動畫（assets 裡 loop:false）播完就停在最後一幀，hold 多出來的部分就是「乾等」，
  /// 看起來像卡畫面。所以兩個 hold 都貼著動畫長度 + 一幀緩衝：
  /// Affectionate 3 幀×300ms=0.9s（原本 hold 2s → 乾等 1.1s）、Eat 2 幀×300ms=0.6s（原本 3s → 2.4s）。
  /// 改 animation.json 的幀數/速度要連這裡一起改。
  static const Duration _affectionateHold = Duration(milliseconds: 1200);
  static const Duration _eatingHold = Duration(milliseconds: 900);

  /// 真的吃下一口時的回調。**只有懸浮會掛**：計分與存盤是 overlay 那側的事，
  /// 預覽塊是沙箱（不該因為在 app 裡餵兩口就悄悄養高某隻動物的親密度）。
  void Function()? onFed;

  /// 撫摸：播撒嬌、站住 [_affectionateHold]。**定格時直接無視** —— `_onTick` 在定格時不倒
  /// hold，改了 action 會讓牠卡在撒嬌最後一幀直到解凍，「定格＝動作固定不動」就破了。
  ///
  /// 回傳「這一下有沒有真的觸發」：無效的互動不該計親密度（呼叫端據此決定加不加分）。
  bool pet() {
    if (_frozen) return false;
    _enter(
      PetBehavior.affectionate,
      action: AnimationAction.affectionate,
      hold: _affectionateHold,
    );
    return true;
  }

  /// 食物落點一律夾進可漫遊範圍，否則牠會永遠抵著邊走不到。
  void feedAt(Offset foodPosition) {
    _frozen = false; // 餵食是明確動作，會解除定格，否則走不過去
    _enter(PetBehavior.goToFood, target: _clampToBounds(foodPosition));
  }

  bool get isDragging => _isDragging;

  void beginDrag() {
    _isDragging = true;
    // 用 sit 不用 affectionate：以前拖曳也播撒嬌，外觀上分不出「被摸」與「被拖」
    _enter(PetBehavior.idle, action: AnimationAction.sit);
    _notifyIfChanged();
  }

  /// 原生拖曳期間由 overlay 輪詢視窗座標後呼叫（不 clamp，不影響 driver）
  void syncFromWindow(Offset p) {
    _position = p;
    _notifyIfChanged();
  }

  void endDrag() {
    _isDragging = false;
    // 拖曳中 syncFromWindow 不 clamp（視窗跟手），放開時才夾回 zone 邊界（A-2/A-7）。
    // 不夾的話拖出選區就留在外面，brain 的下一個決定雖在 bounds 內、位置卻在區外。
    _position = _clampToBounds(_position);
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry, bond: _stats.bondValue));
    _notifyIfChanged();
  }

  /// 定格：停止自主移动與行為切換（饑餓仍照常累積）。只能手動解除。
  bool _frozen = false;
  bool get frozen => _frozen;

  /// 選單開著時暫停自主移動（與使用者的定格分開，不互相覆蓋）。
  /// 飢餓照常累積；位置凍結，關選單時視窗才不會被搬到漫遊後的座標。
  bool _paused = false;
  void setPaused(bool value) => _paused = value;

  void setFrozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    if (!_frozen) {
      _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry, bond: _stats.bondValue));
      _notifyIfChanged();
    }
  }

  void _onTick() {
    _stats.tick(_tick);
    if (_isDragging || _frozen || _paused) return;

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
    // 目標已在邊上時不重抽：沿邊走時每幀重抽會讓左右方向來回跳
    if (_behavior == PetBehavior.wander &&
        _edge.isAtEdge(_position, _bounds) &&
        !_edge.isAtEdge(_target!, _bounds)) {
      _target = _edge.nextTargetOnEdge(_position, _bounds);
    }

    if (!result.arrived) {
      _action = _direction.fromVelocity(_target! - _position);
      _notifyIfChanged();
      return;
    }

    if (_behavior == PetBehavior.goToFood) {
      _stats.feed();
      onFed?.call();
      _enter(
        PetBehavior.eating,
        action: AnimationAction.eat,
        hold: _eatingHold,
      );
    } else if (_edge.isAtEdge(_position, _bounds)) {
      // 抵達且仍在邊緣 → 繼續沿邊/回頭，不發呆
      _enter(PetBehavior.wander,
          target: _edge.nextTargetOnEdge(_position, _bounds));
    } else {
      _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry, bond: _stats.bondValue));
    }
    _notifyIfChanged();
  }

  void _waitThenDecide() {
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    _applyDecision(_brain.decideNext(_bounds, isHungry: _stats.isHungry, bond: _stats.bondValue));
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
      case PetBehavior.affectionate:
        // 親密度高了會自己撒嬌（PetBrain 唯一的 bond 後果）。hold 用 _affectionateHold 而不是
        // decision.holdTime：撒嬌該播多久取決於素材有幾幀，是這裡的事、不是 brain 的事。
        _enter(
          PetBehavior.affectionate,
          action: AnimationAction.affectionate,
          hold: _affectionateHold,
        );
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