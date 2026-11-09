import 'dart:ui';

import 'pet_settings.dart';

/// 只負責：保存主 app 送來的螢幕資訊（僅供校準失敗時回退用）。
///
/// 漫遊範圍**不再**由這裡算：懸浮視窗座標由原生 WindowManager 決定，它會把視窗
/// 夾進自己的安全區（狀態列下方～導航列上方），跟主 app 自己窗口的 MediaQuery
/// 不一定是同一個座標空間（之前就是這樣，限定下方時實際底部多出一大條空閒）。
/// 真正可用的頂端座標範圍由 overlay 端「移動到極端再讀回來」實測（見 overlay_main
/// 的 `_measureRoam`），本檔只剩 `zoneBounds` 從實測結果推各區域。
class ScreenMetrics {
  /// 邏輯像素的螢幕尺寸
  final Size logicalSize;

  /// 裝置像素密度；目前保留給 overlay isolate 了解來源螢幕資訊
  final double devicePixelRatio;

  const ScreenMetrics({
    required this.logicalSize,
    required this.devicePixelRatio,
  });

  /// 實測失敗時的回退範圍：螢幕尺寸扣掉自身邊長
  Rect fallbackRoam(double petSize) => Rect.fromLTWH(
        0,
        0,
        (logicalSize.width - petSize).clamp(0.0, double.infinity).toDouble(),
        (logicalSize.height - petSize).clamp(0.0, double.infinity).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'width': logicalSize.width,
        'height': logicalSize.height,
        'devicePixelRatio': devicePixelRatio,
      };

  factory ScreenMetrics.fromJson(Map<String, dynamic> json) => ScreenMetrics(
        logicalSize: Size(
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        devicePixelRatio: (json['devicePixelRatio'] as num).toDouble(),
      );
}

/// 依區域設定算出可漫遊範圍。[roam] 是**實測**出的視窗頂端座標可達範圍
/// （已含狀態列/導航列的影響），[petSize] 為寵物視窗邊長。
/// 全案只有這一處決定牠能去哪，邊緣行為/隨機目標/clamp 全部吃這個 Rect。
Rect zoneBounds(Rect roam, double petSize, PetZone zone) {
  if (zone == PetZone.fullScreen) return roam;

  final side = petSize * PetSettings.zoneSizeFactor;

  if (zone == PetZone.bottomBand) {
    return Rect.fromLTRB(
      roam.left,
      (roam.bottom - side).clamp(roam.top, roam.bottom).toDouble(),
      roam.right,
      roam.bottom,
    );
  }

  final w = side.clamp(0.0, roam.width).toDouble();
  final h = side.clamp(0.0, roam.height).toDouble();
  return switch (zone) {
    PetZone.topLeft => Rect.fromLTWH(roam.left, roam.top, w, h),
    PetZone.topRight => Rect.fromLTWH(roam.right - w, roam.top, w, h),
    PetZone.bottomLeft => Rect.fromLTWH(roam.left, roam.bottom - h, w, h),
    PetZone.bottomRight => Rect.fromLTWH(roam.right - w, roam.bottom - h, w, h),
    _ => roam,
  };
}

/// 主頁預覽塊的可漫遊範圍（**精靈左上角**可達的位置，與 `PetController` 的 `bounds` 同義）。
///
/// 不共用 [zoneBounds]：預覽塊就在 app 畫面裡，沒有狀態列/導航列那套實測校正的問題，
/// 也沒有「全螢幕／僅下方／四角」的語意。[petSize] 比區塊大時夾成零大小（精靈卡在左上角、
/// 不會跑出去），而不是讓它跳到負座標。
Rect previewBounds(Size block, double petSize) {
  final w = (block.width - petSize).clamp(0.0, block.width).toDouble();
  final h = (block.height - petSize).clamp(0.0, block.height).toDouble();
  return Rect.fromLTWH(0, 0, w, h);
}
