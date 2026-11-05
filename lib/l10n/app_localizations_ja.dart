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
}
