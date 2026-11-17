import 'dart:async';
import 'dart:ui';

import '../../domain/i_overlay_window.dart';
import '../../utils/log.dart';
import 'pet_controller.dart';

/// 只負責：監聽 PetController 位置變化，移動 OS 視窗到對應座標
class OverlayPetDriver {
  final PetController _controller;
  final IOverlayWindow _window;

  Offset _lastMoved = const Offset(-1, -1);
  bool _enabled = true;

  /// 平台呼叫是 async 的，而 controller 每 16ms 就 notify 一次。以前發出後就不管，
  /// 於是多個 moveTo 在通道上排隊、視窗永遠落後於實際狀態（拖曳時尤其明顯）。
  /// 現在一次只讓一個 moveTo 在飛，期間來的新位置記成待發，發完立刻補。
  bool _sending = false;
  bool _queued = false;
  int _consecutiveFailures = 0;

  /// 平台連續拒絕（moveTo 回 false）幾次就認定「視窗已經不在」，把寵物主迴圈停掉。
  /// 1 次就停太衝動（resize 之類的過渡時刻可能短暫回 false），3 次 ≈ 幾個 tick 的容忍。
  static const _refusalsBeforeStop = 3;
  int _consecutiveRefusals = 0;

  /// 已經因拒絕而停下來（由 [restart] 清）。停著的時候不再送、也不再洗 log。
  bool _stopped = false;

  /// [log] 是可注入的 log 出口。**「失敗一定要留痕」這件事本身要有測試鎖住**：以前它從
  /// `appError`（logcat tag `dneko.error`）漂到 `print`（tag `flutter`）而測試全綠，
  /// 而除錯時用的是 `adb logcat -s dneko.error` —— 那條等於不存在。
  /// [onStopped] 在「平台說視窗已不在 → 主迴圈被停掉」那一刻回呼 —— 那就是懸浮被關掉的時刻
  /// （插件的 `closeOverlay` 只 stopService，這個 isolate 還活著），呼叫端要趁這時把餓度標成
  /// 「收起來」。callback 丟例外不會影響停機流程。
  OverlayPetDriver(
    this._controller,
    this._window, {
    void Function(String, Object, StackTrace?)? log,
    this.onStopped,
  }) : _log = log ?? appError {
    _controller.addListener(_onChanged);
  }

  final void Function(String message, Object error, StackTrace? stack) _log;

  /// 停機回呼（見建構子的說明）
  final void Function()? onStopped;

  /// 開啟選單時暫停移動，避免視窗亂跑
  void setEnabled(bool value) => _enabled = value;

  /// 重開懸浮時喚醒寵物（視窗又在了）。
  ///
  /// 必須跟 `PetController.stop()` 成對：定時器一停就不會再 notify，driver 永遠等不到
  /// 「下次位置變動」來重試，所以只能由外部叫。忘了呼叫的後果比 bug 更難查 ——
  /// 關一次懸浮之後寵物就永遠站在原地。
  void restart() {
    _stopped = false;
    _consecutiveRefusals = 0;
    // 視窗剛被重建，尺寸/位置都可能不是我們記的那個 → 強制的下一次必送
    _lastMoved = const Offset(-1, -1);
    _controller.start();
    _onChanged();
  }

  void _onChanged() {
    if (!_enabled || _stopped) return;

    final p = _controller.position;
    // 整數像素未變則略過，降低呼叫頻率
    if ((p.dx - _lastMoved.dx).abs() < 1 && (p.dy - _lastMoved.dy).abs() < 1) {
      return;
    }
    if (_sending) {
      _queued = true;
      return;
    }
    unawaited(_send());
  }

  Future<void> _send() async {
    _sending = true;
    try {
      while (true) {
        final p = _controller.position;
        final target = Offset(p.dx.roundToDouble(), p.dy.roundToDouble());
        if (target == _lastMoved) return;
        _lastMoved = target;
        final accepted = await _window.moveTo(target);
        if (!accepted) {
          // 平台不擲例外、只回 false（service 已被 stopService，我們的 isolate 卻還活著）。
          // 继续送就是 60Hz 沒人收的通道呼叫 + 每 5 秒寫一筆位置，而且全程無聲。
          if (++_consecutiveRefusals < _refusalsBeforeStop) return;
          _stopPet();
          return;
        }
        _consecutiveFailures = 0;
        _consecutiveRefusals = 0;
        if (!_queued) return;
        _queued = false;
      }
    } catch (e, st) {
      // 清掉已送記錄，讓下一次位置變動重試（否則視窗永久卡在舊位置）。
      _lastMoved = const Offset(-1, -1);
      // 每 16ms 重試一次，失敗只在第一次寫 log，不然 logcat 會被洗爆。
      // 但一定要留痕：以前 moveTo 是 unawaited，平台端拒絕時畫面只是不動，
      // 沒有任何地方看得見。
      if (_consecutiveFailures++ == 0) {
        _log('移動懸浮視窗失敗（寵物會卡在舊位置直到下次變動重試）', e, st);
      }
    } finally {
      _sending = false;
      _queued = false;
    }
  }

  /// 視窗已經不在：把寵物主迴圈停下來（不然 isolate 會帶著 60Hz 定時器一直活到程序死）。
  void _stopPet() {
    _stopped = true;
    _lastMoved = const Offset(-1, -1);
    _controller.stop();
    _log(
      '懸浮視窗已不存在，停止寵物主迴圈（重開懸浮時由 restart() 喚醒）',
      StateError('moveOverlay 被平台拒絕'),
      null,
    );
    try {
      onStopped?.call();
    } catch (_) {
      // 停機已經做完；呼叫端（收起來存盤）壞了不該回頭影響 driver
    }
  }

  void dispose() => _controller.removeListener(_onChanged);
}
