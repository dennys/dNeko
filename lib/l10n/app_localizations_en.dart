// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get storeTitle => 'Animal Store';

  @override
  String get storeEmpty => 'No animals available right now.';

  @override
  String get storeDownload => 'Download';

  @override
  String get storeRemove => 'Remove';

  @override
  String get menuFeed => 'Feed';

  @override
  String get menuPet => 'Pet';

  @override
  String get menuClose => 'Close';

  @override
  String get settingsTitle => 'Pet Settings';

  @override
  String get settingsSpeed => 'Speed';

  @override
  String get settingsSize => 'Size';

  @override
  String get settingsZone => 'Roaming area';

  @override
  String get zoneFullScreen => 'Full screen';

  @override
  String get zoneBottomBand => 'Bottom strip';

  @override
  String get zoneTopLeft => 'Top left';

  @override
  String get zoneTopRight => 'Top right';

  @override
  String get zoneBottomLeft => 'Bottom left';

  @override
  String get zoneBottomRight => 'Bottom right';
}
