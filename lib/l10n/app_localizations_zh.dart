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
}
