import 'dart:async';
import 'dart:convert';

/// 選單的開／關／逾時／指令派工 —— 純狀態機，不碰平台、不碰 Flutter。
///
/// 選單是**第二個懸浮視窗**（原生 `MenuOverlay.kt`），寵物這側只負責兩件事：開的時候把
/// 牠凍住、關的時候**一定**要解凍。這個配對之前散在 `overlay_main` 的欄位與 try/catch 裡，
/// 於是「開到一半失敗」那條路把解凍擋在 `if (!_menuOpen) return` 後面 —— 選單沒出來、
/// 寵物卻永久凍住（engine 是 cached 的，關掉重開也不救）。抽成一支類別就是為了讓
/// 「凍結/解凍必須配對」「close() 無論開到哪一步都要還原」這種事能被測試鎖住。
///
/// 本檔刻意不吃任何平台型別：凍結與視窗動作都由呼叫端以回調注入（測試塞計數用的假函式），
/// 與 [DragWatch] / [PositionThrottle] 同一個路子。
class MenuDirector {
  /// [onPause] / [onResume] 由呼叫端實作成「暫停自主移動 + 暫停搬視窗」與它的反面。
  /// [onResume] 必須**冪等**：`close()` 可能在一場沒開成功的 `open()` 之後被呼叫。
  /// [onHideWindow] 請原生收掉選單那顆視窗（不能丟例外）。
  /// [onAction] 收到選單的動作名稱（`feed` / `pet` / `freeze` / `quit` / `close`，
  /// 或 [kFlourishBehaviors] 裡的動作名）。
  /// [scheduleClose] 只在測試時替換，用來手動觸發那 6 秒逾時。
  MenuDirector({
    required Duration timeout,
    required this.onPause,
    required this.onResume,
    required this.onHideWindow,
    this.onAction,
    Timer Function(void Function() close)? scheduleClose,
  }) : _scheduleClose = scheduleClose ?? ((close) => Timer(timeout, close));

  final void Function() onPause;
  final void Function() onResume;
  final Future<void> Function() onHideWindow;
  final void Function(String action)? onAction;
  /// 排一個逾時（回傳排程器，好讓 close 能取消它）；測試給假的就能手動觸發逾時
  final Timer Function(void Function() close) _scheduleClose;

  /// 選單那側「有在按」的訊號：重新計時，不關選單、也不執行動作
  static const String interactAction = 'interact';

  Timer? _timer;
  bool _open = false;

  /// 每一場「開→關」算一世代（見 [open] 尾聲的超車檢查）。
  int _generation = 0;

  /// 凍結是不是我們下達的（與 [_open] 分開記：`close()` 只還原真的凍住過的那次）
  bool _paused = false;

  /// 選單開著（= 寵物正被凍住）。
  bool get isOpen => _open;

  /// 開選單。[showWindow] 負責算位置並請原生把視窗開出來 —— 它丟任何例外都算開失敗。
  ///
  /// 開失敗時一樣會把凍結還原，然後把例外**原樣丟回給呼叫端**（怎麼報錯是呼叫端的事，
  /// 但「不能留著凍住的寵物」是這裡的責任，不能交給呼叫端記得寫）。
  Future<bool> open(Future<void> Function() showWindow) async {
    if (_open) return false;
    final generation = ++_generation;
    onPause();
    _paused = true;
    // 先當它開著：原生那邊 addView 失敗是 post 之後才回來的（那時 showMenu 已經回成功），
    // 遲到的 close 指令要進得來，就得讓 isOpen 已經是 true。
    _open = true;
    try {
      await showWindow();
    } catch (_) {
      await close();
      rethrow;
    }
    if (generation != _generation) {
      // 等 showWindow 回來之前被 abort()／close() 超車了：這張是舊動物的幽靈選單，
      // 自己收掉。不這樣會留一張六秒的選單在畫面上，而且 onCommand 因為 _open 已是
      // false 會把它的每一格點擊都丟掉（看起來像壞掉）。
      await close();
      return false;
    }
    _arm();
    return true;
  }

  /// 收選單：**冪等**，而且不管開到哪一步都一定把凍結還原。
  /// 所有關閉路徑都要走這裡（按選項、點螢幕外面、逾時、拖寵物、換動物）。
  Future<void> close() async {
    _generation++;
    _cancelTimer();
    _open = false;
    if (_paused) {
      _paused = false;
      onResume();
    }
    await onHideWindow();
  }

  /// 選單那顆視窗送過來的指令（原生 `menuCommand`，內容是 `{"action":"..."}`）。
  ///
  /// 認不出來的、以及選單已經被收掉之後才遲到的（逾時／點外面已經先關了）一律丟掉 ——
  /// 選單那側怎樣都不該把寵物弄壞。
  void onCommand(dynamic arguments) {
    final action = actionOf(arguments);
    if (action == null || !_open) return;
    if (action == interactAction) {
      _arm();
      return;
    }
    unawaited(_run(action));
  }

  /// 解析指令；不是字串、不是 JSON、沒有 `action` 都回 null（丟掉就好，不能讓選單弄壞寵物）
  static String? actionOf(dynamic arguments) {
    if (arguments is! String) return null;
    try {
      final map = jsonDecode(arguments);
      if (map is! Map) return null;
      final action = map['action'];
      return action is String ? action : null;
    } catch (_) {
      return null;
    }
  }

  /// 寵物這側要消失了：收掉定時器、請原生關視窗，但**不碰寵物**（它跟著一起沒了）。
  void abort() {
    _generation++;
    _cancelTimer();
    _open = false;
    _paused = false;
    unawaited(onHideWindow());
  }

  void _arm() {
    _cancelTimer();
    _timer = _scheduleClose(() {
      unawaited(close());
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _run(String action) async {
    await close(); // 順序不能反：先解凍，動作才動得了
    onAction?.call(action);
  }
}
