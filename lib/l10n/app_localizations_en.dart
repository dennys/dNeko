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
  String get menuFreeze => 'Freeze';

  @override
  String get menuUnfreeze => 'Unfreeze';

  @override
  String get menuClose => 'Close';

  @override
  String get menuQuit => 'Quit';

  @override
  String get overlayRunning => 'Running on your screen';

  @override
  String get overlayIdle => 'Currently off';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get languageSystem => 'System default';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get shortcutPin => 'Add home screen shortcut';

  @override
  String get shortcutPinUnsupported =>
      'This device doesn\'t support pinning shortcuts';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsTitle => 'Pet Settings';

  @override
  String get settingsSpeed => 'Speed';

  @override
  String get settingsSize => 'Size';

  @override
  String get settingsZone => 'Roaming area';

  @override
  String get settingsAnimal => 'Pet';

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

  @override
  String get overlayStart => 'Start Overlay';

  @override
  String get overlayStop => 'Stop Overlay';

  @override
  String get overlayStarting => 'Starting...';

  @override
  String get overlayStopping => 'Stopping...';

  @override
  String overlayFailed(Object message) {
    return 'Failed to change overlay: $message';
  }

  @override
  String get overlayPermissionDenied => 'Overlay permission was not granted';
}
