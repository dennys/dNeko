import 'dart:async';
import 'dart:ui';

import '../../domain/i_overlay_window.dart';
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

  OverlayPetDriver(this._controller, this._window) {
    _controller.addListener(_onChanged);
  }

  /// 開啟選單時暫停移動，避免視窗亂跑
  void setEnabled(bool value) => _enabled = value;

  void _onChanged() {
    if (!_enabled) return;

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
        await _window.moveTo(target);
        _consecutiveFailures = 0;
        if (!_queued) return;
        _queued = false;
      }
    } catch (e) {
      // 清掉已送記錄，讓下一次位置變動重試（否則視窗永久卡在舊位置）。
      _lastMoved = const Offset(-1, -1);
      // 每 16ms 重試一次，失敗只在第一次寫 log，不然 logcat 會被洗爆。
      // 但一定要留痕：以前 moveTo 是 unawaited，平台端拒絕時畫面只是不動，
      // 沒有任何地方看得見。
      if (_consecutiveFailures++ == 0) {
        // ignore: avoid_print
        print('移動懸浮視窗失敗: $e');
      }
    } finally {
      _sending = false;
      _queued = false;
    }
  }

  void dispose() => _controller.removeListener(_onChanged);
}
