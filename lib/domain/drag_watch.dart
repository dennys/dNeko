import 'dart:ui';

/// 原生拖曳輪詢的判定結果。
enum DragStep {
  /// 視窗還沒離開錨點，繼續等（可能是單純點擊）
  keepWaiting,

  /// 視窗離開了錨點 → 判定為真的在拖（呼叫端要暫停 driver 並 `beginDrag()`）
  startDrag,

  /// 拖曳中，這個座標要同步給 PetController
  dragging,

  /// 停止輪詢：還沒拖起來＝只是點擊，或拖完靜止夠久＝已放手
  stop,
}

/// 「視窗有沒有在被拖」的狀態機（純邏輯，不碰平台，方便測）。
///
/// 判定基準是**視窗自己第一次的讀值**，不是寵物的位置。這一點是 #2 的根因所在：
/// 寵物每 16ms 就在走，拿 `PetController.position` 當基準的話，走動的寵物被摸一下
/// 就會差超過門檻（90 px/s 時一跳 1.44 px、200 px/s 時 3.2 px，還疊著方法通道的
/// 往返延遲）→ 撫摸被誤判成拖曳。視窗在沒有人拖的時候是不動的，拿它跟自己比才乾淨。
///
/// 已知代價（與改動前相同，DEVICE_TEST A-8）：拖曳中停頓超過 [maxIdlePolls] ×
/// 輪詢間隔會被當成放手。根治要靠本地 fork 把 `ACTION_UP` 回傳給 overlay 的 Dart 側。
class DragWatch {
  DragWatch({
    this._moveThresholdPx = 2,
    this._maxPreDragPolls = 8,
    this._maxIdlePolls = 8,
  });

  final double _moveThresholdPx;
  final int _maxPreDragPolls;
  final int _maxIdlePolls;

  bool _dragging = false;
  int _polls = 0;
  int _idlePolls = 0;

  /// 開始輪詢時視窗所在之處 —— 唯一的拖曳基準
  Offset? _anchor;

  /// 上一次「真的變動過」的視窗座標，用來數靜止了幾次
  Offset? _lastMoved;

  bool get dragging => _dragging;

  /// 餵進一次輪詢讀到的視窗左上角（邏輯像素），回報這一步該做什麼。
  DragStep step(Offset window) {
    if (!_dragging) {
      _anchor ??= window;
      if ((window - _anchor!).distance < _moveThresholdPx) {
        _polls++;
        return _polls >= _maxPreDragPolls ? DragStep.stop : DragStep.keepWaiting;
      }
      _dragging = true;
      _lastMoved = window;
      _idlePolls = 0;
      return DragStep.startDrag;
    }

    if (window == _lastMoved) {
      _idlePolls++;
      if (_idlePolls < _maxIdlePolls) return DragStep.dragging;
      _dragging = false;
      return DragStep.stop;
    }

    _idlePolls = 0;
    _lastMoved = window;
    return DragStep.dragging;
  }
}
