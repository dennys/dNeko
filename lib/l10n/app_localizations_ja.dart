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
  String get menuFreeze => '静止';

  @override
  String get menuUnfreeze => '動き出す';

  @override
  String get menuClose => '閉じる';

  @override
  String get menuQuit => 'アプリを終了';

  @override
  String get overlayRunning => '画面で動かしています';

  @override
  String get overlayIdle => '停止中です';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get themeSystem => 'システムに従う';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get shortcutPin => 'ホーム画面にショートカットを追加';

  @override
  String get shortcutPinUnsupported => 'この端末はショートカットのピン留めに未対応です';

  @override
  String get settingsAbout => 'アプリについて';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsTitle => 'ペット設定';

  @override
  String get settingsSpeed => '移動スピード';

  @override
  String get settingsSize => 'サイズ';

  @override
  String get settingsZone => '移動エリア';

  @override
  String get settingsAnimal => 'ペット';

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

  @override
  String get overlayStart => 'デスクトップペットを開始';

  @override
  String get overlayStop => 'デスクトップペットを停止';

  @override
  String get overlayStarting => '開始中…';

  @override
  String get overlayStopping => '停止中…';

  @override
  String overlayFailed(Object message) {
    return 'オーバーレイの変更に失敗：$message';
  }

  @override
  String get overlayPermissionDenied => 'オーバーレイ権限が許可されませんでした';

  @override
  String get animalCat => '猫';

  @override
  String get animalDog => '犬';

  @override
  String get animalPenguin => 'ペンギン';

  @override
  String get animalFox => 'キツネ';
}
