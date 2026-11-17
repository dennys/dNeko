import 'dart:math' show pi;

import 'package:flutter/material.dart';

/// 餓昏時飄在頭頂的求助氣泡（空碗 + 抖動線）。八隻共用同一張圖，不是每隻各畫一份。
///
/// **圖還沒畫出來也要看得到**：素材缺檔時改用 [_BubblePainter] 現畫一顆（同一套配色），
/// 所以「新素材還沒到位」只會少了美术風格，不會讓寵物頭上空空、也不會變一塊白。
/// 之後把 `assets/images/hunger_bubble.png` 放進去，自動改畫那张圖，代碼不用動。
class HungerBubble extends StatelessWidget {
  /// 相對於專案根的路徑（`Image.asset` 用的是 asset key，要含 `assets/` 前綴；
  /// 跟 `AssetSource` 那種「相對於 assets/」的寫法不一樣，兩邊別抄錯）。
  static const String assetKey = 'assets/images/hunger_bubble.png';

  final String assetKeyOverride;

  const HungerBubble({super.key, this.assetKeyOverride = assetKey});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetKeyOverride,
      fit: BoxFit.contain,
      // 缺圖時 Flutter 只在 errorBuilder == null 的時候才丟例外，給了它就不會炸 UI。
      errorBuilder: (context, error, stackTrace) =>
          CustomPaint(size: Size.infinite, painter: _BubblePainter()),
    );
  }
}

/// 備援的求助氣泡：一只空碗 + 碗口上方三條抖動弧線 + 一滴卡通汗珠。
/// 配色沿用素材規格（奶油白碗、黑色粗描邊、暖橘陰影），不會跟動物畫風打架。
class _BubblePainter extends CustomPainter {
  static final Paint _outline = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  static final Paint _bowl = Paint()
    ..color = const Color(0xFFF0D8C0)
    ..style = PaintingStyle.fill;
  static final Paint _shade = Paint()
    ..color = const Color(0xFFD89048)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  /// 三條抖動弧線的寬度比例（越外面越短）
  static const List<double> _wobbleWidths = [0.46, 0.30, 0.14];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = size.shortestSide;
    final cx = size.width / 2;
    final bowlTop = size.height * 0.62;
    final half = s * 0.30;

    // 碗：下半圓 + close 回來的碗口直線（扁平面朝上 = 空碗的輪廓）
    final bowl = Path()
      ..addArc(Rect.fromLTWH(cx - half, bowlTop, half * 2, s * 0.42), 0, pi)
      ..close();
    canvas.drawPath(bowl, _bowl);
    canvas.drawPath(bowl, _outline);

    // 碗空空的：碗中一條淡橘底線表示「見底」
    canvas.drawLine(
      Offset(cx - half * 0.5, bowlTop + s * 0.16),
      Offset(cx + half * 0.5, bowlTop + s * 0.16),
      _shade,
    );

    // 抖動弧線：三條，越外面越短（「餓到在抖」）
    for (var i = 0; i < 3; i++) {
      final halfW = s * _wobbleWidths[i] / 2;
      final y = bowlTop - s * (0.10 + 0.11 * i);
      canvas.drawArc(
        Rect.fromLTWH(cx - halfW, y - s * 0.07, halfW * 2, s * 0.14),
        pi * 1.15,
        pi * 0.7,
        false,
        _outline,
      );
    }

    // 一滴卡通汗珠（右上）
    canvas.drawCircle(Offset(cx + half * 1.15, bowlTop - s * 0.30), s * 0.045, _bowl);
    canvas.drawCircle(Offset(cx + half * 1.15, bowlTop - s * 0.30), s * 0.045, _outline);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
