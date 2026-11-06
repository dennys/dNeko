// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get storeTitle => 'どうぶつストア';

  @override
  String get storeEmpty => '現在ダウンロードできるどうぶつはいません。';

  @override
  String get storeDownload => 'ダウンロード';

  @override
  String get storeRemove => '削除';

  @override
  String get menuFeed => 'ごはん';

  @override
  String get menuPet => 'なでる';

  @override
  String get menuClose => '閉じる';

  @override
  String get settingsTitle => 'ペット設定';

  @override
  String get settingsSpeed => '移動スピード';

  @override
  String get settingsSize => 'サイズ';

  @override
  String get settingsZone => '移動エリア';

  @override
  String get zoneFullScreen => '全画面';

  @override
  String get zoneBottomBand => '下部のみ';

  @override
  String get zoneTopLeft => '左上';

  @override
  String get zoneTopRight => '右上';

  @override
  String get zoneBottomLeft => '左下';

  @override
  String get zoneBottomRight => '右下';
}
