import 'dart:ui';
import '../../domain/i_overlay_window.dart';
import 'pet_controller.dart';

/// 只負責：監聽 PetController 位置變化，移動 OS 視窗到對應座標
class OverlayPetDriver {
  final PetController _controller;
  final IOverlayWindow _window;

  Offset _lastMoved = const Offset(-1, -1);
  bool _enabled = true;

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
    _lastMoved = p;
    _window.moveTo(p);
  }

  void dispose() => _controller.removeListener(_onChanged);
}