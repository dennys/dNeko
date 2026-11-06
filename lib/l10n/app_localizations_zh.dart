// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get storeTitle => '動物商店';

  @override
  String get storeEmpty => '目前沒有可下載的動物。';

  @override
  String get storeDownload => '下載';

  @override
  String get storeRemove => '移除';

  @override
  String get menuFeed => '餵食';

  @override
  String get menuPet => '撫摸';

  @override
  String get menuClose => '關閉';

  @override
  String get settingsTitle => '寵物設定';

  @override
  String get settingsSpeed => '移動速度';

  @override
  String get settingsSize => '大小';

  @override
  String get settingsZone => '活動範圍';

  @override
  String get zoneFullScreen => '全螢幕';

  @override
  String get zoneBottomBand => '僅下方';

  @override
  String get zoneTopLeft => '左上角';

  @override
  String get zoneTopRight => '右上角';

  @override
  String get zoneBottomLeft => '左下角';

  @override
  String get zoneBottomRight => '右下角';

  @override
  String get overlayStart => '啟動桌寵';

  @override
  String get overlayStop => '關閉桌寵';

  @override
  String get overlayStarting => '啟動中…';

  @override
  String get overlayStopping => '關閉中…';

  @override
  String overlayFailed(Object message) {
    return '改變懸浮視窗失敗：$message';
  }

  @override
  String get overlayPermissionDenied => '沒有取得懸浮視窗權限';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get storeTitle => '動物商店';

  @override
  String get storeEmpty => '目前沒有可下載的動物。';

  @override
  String get storeDownload => '下載';

  @override
  String get storeRemove => '移除';

  @override
  String get menuFeed => '餵食';

  @override
  String get menuPet => '撫摸';

  @override
  String get menuClose => '關閉';

  @override
  String get settingsTitle => '寵物設定';

  @override
  String get settingsSpeed => '移動速度';

  @override
  String get settingsSize => '大小';

  @override
  String get settingsZone => '活動範圍';

  @override
  String get zoneFullScreen => '全螢幕';

  @override
  String get zoneBottomBand => '僅下方';

  @override
  String get zoneTopLeft => '左上角';

  @override
  String get zoneTopRight => '右上角';

  @override
  String get zoneBottomLeft => '左下角';

  @override
  String get zoneBottomRight => '右下角';

  @override
  String get overlayStart => '啟動桌寵';

  @override
  String get overlayStop => '關閉桌寵';

  @override
  String get overlayStarting => '啟動中…';

  @override
  String get overlayStopping => '關閉中…';

  @override
  String overlayFailed(Object message) {
    return '改變懸浮視窗失敗：$message';
  }

  @override
  String get overlayPermissionDenied => '沒有取得懸浮視窗權限';
}
