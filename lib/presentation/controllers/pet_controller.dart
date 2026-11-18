import 'dart:async';
import 'dart:math' show cos, pi, sin;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../data/models/animation_action.dart';
import '../../domain/flourish_scheduler.dart';
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
    FlourishScheduler? flourish,
  })  : _bounds = bounds,
        _ownsStats = stats == null,
        _stats = stats ?? PetStats(),
        _brain = brain ?? PetBrain(),
        _flourishScheduler = flourish ?? FlourishScheduler(),
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

  final FlourishScheduler _flourishScheduler;

  /// 計時動作結束後接著要播的動作（撫摸後跳跳、進食後跳跳）。[_enter] 會清掉它。
  PetBehavior? _queued;

  static const Duration _hopHold = Duration(milliseconds: 900);
  static const Duration _stretchHold = Duration(milliseconds: 900); // 素材同撒嬌，播一次
  static const double _circleRadius = 40;
  static const int _circleWaypoints = 4;
  Offset _circleCenter = Offset.zero;
  int _circleIndex = 0;

  void start() => _timer ??= Timer.periodic(_tick, (_) => _onTick());

  /// 暫停主迴圈，與 [start] 成對（`start()` 冪等，重開懸浮時直接再呼叫一次就行）。
  ///
  /// 存在的原因：插件的 `closeOverlay` 只有 `stopService`，`onDestroy` 不銷毀 cached
  /// engine，所以**關掉懸浮之後這個 isolate 還活著**（真機實測：關掉後寵物繼續走，位置
  /// 每 5 秒被寫進 DB，下次開懸浮牠就出現在別的地方）。不停下來就是每 16ms 空轉一次、
  /// 每 tick 送一次已經沒有人收的 `moveTo`、外加每 5 秒寫一筆 DB。
  /// 由 [OverlayPetDriver] 在平台連續拒絕搬視窗時呼叫。
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

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

  /// 餓昏那兩格：**不是**「播完就停」的一次性動作，是鬧給主人看的，所以給到 5 秒。
  /// 不會乾等 5 秒：討食靠 [AnimalAnimator] 的程式化作動一直一伏一伏地拜（借來的 sit 幀是
  /// loop:true），裝死則是倒下後就攤著不動 —— 靜止在那一格正是笑點，不是壞掉。
  /// 素材齊了（animation.json 直接宣告 Beg／Faint）就由素材的 loop 決定循環與否。
  ///
  /// 不做成「持續到餵食為止」：餓昏的持續訊號已經是頭頂那顆求助氣泡（[HungerBubble] 只要在
  /// 餓昏區就一直顯示），動作再釘死就會讓牠整個不動，讀起來像壞掉也可憐 —— 這玩意兒的調性
  /// 是滑稽不是可憐（AGENTS.md）。要更誇張就把這兩個數字調大，鬧的頻率由 PetBrain 的餓昏機率決定。
  static const Duration _begHold = Duration(seconds: 5);
  static const Duration _faintHold = Duration(seconds: 5);

  /// 真的吃下一口時的回調。**只有懸浮會掛**：計分與存盤是 overlay 那側的事，
  /// 預覽塊是沙箱（不該因為在 app 裡餵兩口就悄悄養高某隻動物的親密度）。
  void Function()? onFed;

  /// 開始討食／裝死時的回調（叫聲要不要播、用哪隻動物的聲音，是呼叫端的事）。
  /// 與 [onFed] 同一套：**只有懸浮會掛**，預覽塊不掛。
  /// 從 `_enter` 發，所以摸牠（[pet] 餓昏時進 beg）、選單那兩格、PetBrain 自己鬧全部都會響。
  void Function(PetBehavior behavior)? onHungerCry;

  /// 撫摸：播撒嬌、站住 [_affectionateHold]。
  /// 定格時也能摸：撒嬌播完回到摸之前的姿勢，**不解除定格**，也不接跳跳。
  ///
  /// 回傳「這一下有沒有真的觸發」：無效的互動不該計親密度（呼叫端據此決定加不加分）。
  bool pet() {
    // 餓昏時摸牠不撒嬌：撒嬌會被讀成「牠不餓」，此刻該看到的是討食（也才接得上餵食）。
    final starving = _stats.isStarving;
    final behavior = starving ? PetBehavior.beg : PetBehavior.affectionate;
    final action = starving ? AnimationAction.beg : AnimationAction.affectionate;
    final hold = starving ? _begHold : _affectionateHold;
    if (_frozen) {
      if (_behavior != behavior) _actionBeforePet = _action;
      _enter(behavior, action: action, hold: hold);
      return true;
    }
    _enter(behavior, action: action, hold: hold);
    // 撒嬌播完接跳跳；討食後面不接 —— 跳跳會把「牠餓到在拜」的氣氛破掉
    if (!starving) _queued = PetBehavior.hop;
    return true;
  }

  /// 定格中被摸時，撒嬌播完前的動作（撒嬌期間不覆寫，避免連摸時記到撒嬌本身）。
  AnimationAction _actionBeforePet = AnimationAction.sit;

  /// 選單點選的小動作。拖曳中無效；不計親密度。
  ///
  /// **定格中被按也要播**（2026-11-17 人類的決定：選單那些動作格不該因為定格而變灰）。
  /// 按選單是明確的互動，所以跟 [feedAt] 一樣先解除定格再播。這裡刻意直接改 `_frozen`
  /// 而不走 [setFrozen]：setFrozen 解凍時會請 brain 重新決定下一個行為，那會把使用者
  /// 剛點的這個動作蓋掉。
  void playFlourish(PetBehavior behavior) {
    if (_isDragging || !_isFlourish(behavior)) return;
    if (_paused && behavior == PetBehavior.circle) return; // 轉圈需要移動，選單開著時不動
    _frozen = false;
    _enterFlourish(behavior);
    _notifyIfChanged();
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
    _applyDecision(_brain.decideNext(_bounds,
              isHungry: _stats.isHungry,
              isStarving: _stats.isStarving,
              bond: _stats.bondValue));
    _notifyIfChanged();
  }

  /// 定格：停止自主移动與行為切換（饑餓仍照常累積）。
  /// 解除的時機：選單再按一次「定格」、[feedAt]（餵食）、或 [playFlourish]（按動作格）——
  /// 都是明確的互動；只有時間與摸牠不會把定格解開。
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
      _applyDecision(_brain.decideNext(_bounds,
              isHungry: _stats.isHungry,
              isStarving: _stats.isStarving,
              bond: _stats.bondValue));
      _notifyIfChanged();
    }
  }

  void _onTick() {
    _stats.tick(_tick);
    if (_isDragging) return;
    if (_frozen) {
      _tickFrozenPet();
      return;
    }
    if (_paused) {
      _tickHoldWhilePaused();
      return;
    }

    final flourish = _flourishScheduler.tryPick(_tick, _flourishCandidates());
    if (flourish != null) {
      _enterFlourish(flourish);
      _notifyIfChanged();
      return;
    }

    if (_behavior == PetBehavior.wander ||
        _behavior == PetBehavior.goToFood ||
        _behavior == PetBehavior.circle) {
      _move();
      return;
    }
    _waitThenDecide();
  }

  /// 隨機小動作的候選：發呆時張望／打盹（飢餓再加搖擺），漫遊時轉圈。
  List<PetBehavior> _flourishCandidates() => switch (_behavior) {
        PetBehavior.idle => <PetBehavior>[
            // 餓昏時發呆就該鬧（不是張望/打盹那種悠閒小動作）
            if (_stats.isStarving) ...[
              PetBehavior.beg,
              PetBehavior.faint,
              PetBehavior.wobble,
            ] else ...[
              PetBehavior.lookAround,
              PetBehavior.doze,
              if (_stats.isHungry) PetBehavior.wobble,
            ],
          ],
        PetBehavior.wander => const <PetBehavior>[PetBehavior.circle],
        _ => const <PetBehavior>[],
      };

  void _move() {
    final result = _movement.step(
      current: _position,
      target: _target!,
      bounds: _bounds,
    );
    _position = result.position;

    if (_behavior == PetBehavior.circle) {
      _moveAlongCircle(result.arrived);
      return;
    }

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
      _queued = PetBehavior.hop; // 吃完跳一下
    } else if (_edge.isAtEdge(_position, _bounds)) {
      // 抵達且仍在邊緣 → 繼續沿邊/回頭，不發呆
      _enter(PetBehavior.wander,
          target: _edge.nextTargetOnEdge(_position, _bounds));
    } else {
      _applyDecision(_brain.decideNext(_bounds,
              isHungry: _stats.isHungry,
              isStarving: _stats.isStarving,
              bond: _stats.bondValue));
    }
    _notifyIfChanged();
  }

  /// 轉圈：以開始時的位置為圓心，依序走四個點（每 90 度）。走完回到發呆，下一 tick 重新決定。
  void _moveAlongCircle(bool arrived) {
    if (arrived) {
      _circleIndex++;
      if (_circleIndex >= _circleWaypoints) {
        _enter(PetBehavior.idle, action: AnimationAction.sit);
        _notifyIfChanged();
        return;
      }
      _target = _circleWaypoint(_circleIndex);
    }
    _action = _direction.fromVelocity(_target! - _position);
    _notifyIfChanged();
  }

  Offset _circleWaypoint(int index) {
    final angle = index * pi / 2;
    return _clampToBounds(_circleCenter + Offset(cos(angle), sin(angle)) * _circleRadius);
  }

  void _waitThenDecide() {
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    _onHoldExpired();
    _notifyIfChanged();
  }

  /// 定格中也要倒數「會自己結束的動作」，否則動作停在最後一幀看起來像壞掉：
  /// 撒嬌播完回到摸之前的姿勢（仍定格），其他計時動作（吃／跳跳／搖擺／打盹…）回到坐著。
  /// 之前只倒數撒嬌，「正在吃東西时被定格」就永遠卡在吃的那一幀。
  void _tickFrozenPet() {
    if (!_isTimed(_behavior)) return;
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    final resting = _behavior == PetBehavior.affectionate ? _actionBeforePet : AnimationAction.sit;
    _enter(PetBehavior.idle, action: resting);
  }

  /// 選單開著時不做移動與隨機抽籤，但正在播的計時動作（撒嬌、跳跳…）仍要倒數，
  /// 否則牠會卡在最後一幀，直到關選單才動。
  void _tickHoldWhilePaused() {
    if (!_isTimed(_behavior)) return;
    _hold -= _tick;
    if (_hold > Duration.zero) return;
    _onHoldExpired();
    _notifyIfChanged();
  }

  /// 計時結束的銜接：排隊的動作先播；睡醒伸懶腰；選單開著就回發呆，不抽新的決定。
  void _onHoldExpired() {
    final next = _queued ?? (_behavior == PetBehavior.sleep ? PetBehavior.stretch : null);
    _queued = null;
    if (next != null) {
      _enterFlourish(next);
      return;
    }
    if (_paused) {
      _enter(PetBehavior.idle, action: AnimationAction.sit);
      return;
    }
    _applyDecision(_brain.decideNext(_bounds,
              isHungry: _stats.isHungry,
              isStarving: _stats.isStarving,
              bond: _stats.bondValue));
  }

  void _enterFlourish(PetBehavior behavior) {
    if (behavior == PetBehavior.circle) {
      _circleCenter = _position;
      _circleIndex = 0;
      _enter(behavior, target: _circleWaypoint(0));
      return;
    }
    _enter(behavior, action: _actionFor(behavior), hold: _flourishHoldFor(behavior));
  }

  static bool _isFlourish(PetBehavior behavior) => switch (behavior) {
        PetBehavior.lookAround ||
        PetBehavior.doze ||
        PetBehavior.wobble ||
        PetBehavior.hop ||
        PetBehavior.stretch ||
        PetBehavior.circle ||
        PetBehavior.beg ||
        PetBehavior.faint =>
          true,
        _ => false,
      };

  /// 有計時、會自己結束的行為（轉圈與睡眠不計時）。
  static bool _isTimed(PetBehavior behavior) => switch (behavior) {
        PetBehavior.affectionate ||
        PetBehavior.beg ||
        PetBehavior.faint ||
        PetBehavior.eating ||
        PetBehavior.lookAround ||
        PetBehavior.doze ||
        PetBehavior.wobble ||
        PetBehavior.hop ||
        PetBehavior.stretch =>
          true,
        _ => false,
      };

  static AnimationAction _actionFor(PetBehavior behavior) => switch (behavior) {
        PetBehavior.lookAround => AnimationAction.lookAround,
        PetBehavior.doze => AnimationAction.doze,
        PetBehavior.wobble => AnimationAction.wobble,
        PetBehavior.hop => AnimationAction.hop,
        PetBehavior.stretch => AnimationAction.stretch,
        PetBehavior.beg => AnimationAction.beg,
        PetBehavior.faint => AnimationAction.faint,
        _ => AnimationAction.sit,
      };

  /// 各小動作的停留時間：素材幀數與幀長換算，多出來的一幀緩衝與撒嬌相同。
  static Duration _flourishHoldFor(PetBehavior behavior) => switch (behavior) {
        PetBehavior.lookAround => const Duration(milliseconds: 2000),
        PetBehavior.doze => const Duration(milliseconds: 2500),
        PetBehavior.wobble => const Duration(milliseconds: 1800),
        PetBehavior.hop => _hopHold,
        PetBehavior.stretch => _stretchHold,
        PetBehavior.beg => _begHold,
        PetBehavior.faint => _faintHold,
        _ => Duration.zero,
      };

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
      case PetBehavior.beg || PetBehavior.faint || PetBehavior.wobble:
        // 餓昏鬧騰（含 brain 偶爾挑的 wobble）：動作與 hold 由這裡決定，不信 brain 的 holdTime
        _enterFlourish(decision.behavior);
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
    _queued = null;
    _behavior = behavior;
    _target = target;
    _hold = hold;
    if (action != null) _action = action;
    if (behavior == PetBehavior.beg || behavior == PetBehavior.faint) onHungerCry?.call(behavior);
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