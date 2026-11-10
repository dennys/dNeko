import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @storeTitle.
  ///
  /// In en, this message translates to:
  /// **'Animal Store'**
  String get storeTitle;

  /// No description provided for @storeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No animals available right now.'**
  String get storeEmpty;

  /// No description provided for @storeDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get storeDownload;

  /// No description provided for @storeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get storeRemove;

  /// No description provided for @menuFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get menuFeed;

  /// No description provided for @menuPet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get menuPet;

  /// No description provided for @menuFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get menuFreeze;

  /// No description provided for @menuUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get menuUnfreeze;

  /// No description provided for @menuClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get menuClose;

  /// No description provided for @menuQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get menuQuit;

  /// No description provided for @overlayRunning.
  ///
  /// In en, this message translates to:
  /// **'Running on your screen'**
  String get overlayRunning;

  /// No description provided for @overlayIdle.
  ///
  /// In en, this message translates to:
  /// **'Currently off'**
  String get overlayIdle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @shortcutPin.
  ///
  /// In en, this message translates to:
  /// **'Add home screen shortcut'**
  String get shortcutPin;

  /// No description provided for @shortcutPinUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t support pinning shortcuts'**
  String get shortcutPinUnsupported;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get settingsSpeed;

  /// No description provided for @settingsSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get settingsSize;

  /// No description provided for @settingsHunger.
  ///
  /// In en, this message translates to:
  /// **'Hungry after'**
  String get settingsHunger;

  /// No description provided for @settingsZone.
  ///
  /// In en, this message translates to:
  /// **'Roaming area'**
  String get settingsZone;

  /// No description provided for @settingsAnimal.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get settingsAnimal;

  /// No description provided for @zoneFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get zoneFullScreen;

  /// No description provided for @zoneBottomBand.
  ///
  /// In en, this message translates to:
  /// **'Bottom strip'**
  String get zoneBottomBand;

  /// No description provided for @zoneTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get zoneTopLeft;

  /// No description provided for @zoneTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get zoneTopRight;

  /// No description provided for @zoneBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get zoneBottomLeft;

  /// No description provided for @zoneBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get zoneBottomRight;

  /// No description provided for @overlayStart.
  ///
  /// In en, this message translates to:
  /// **'Start Overlay'**
  String get overlayStart;

  /// No description provided for @overlayStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Overlay'**
  String get overlayStop;

  /// No description provided for @overlayStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get overlayStarting;

  /// No description provided for @overlayStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get overlayStopping;

  /// No description provided for @overlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change overlay: {message}'**
  String overlayFailed(Object message);

  /// No description provided for @overlayPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Overlay permission was not granted'**
  String get overlayPermissionDenied;

  /// No description provided for @animalCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get animalCat;

  /// No description provided for @animalDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get animalDog;

  /// No description provided for @animalPenguin.
  ///
  /// In en, this message translates to:
  /// **'Penguin'**
  String get animalPenguin;

  /// No description provided for @animalFox.
  ///
  /// In en, this message translates to:
  /// **'Fox'**
  String get animalFox;

  /// No description provided for @animalHeartDog.
  ///
  /// In en, this message translates to:
  /// **'Heart Dog'**
  String get animalHeartDog;

  /// No description provided for @animalRacoon.
  ///
  /// In en, this message translates to:
  /// **'Raccoon'**
  String get animalRacoon;

  /// No description provided for @animalSloth.
  ///
  /// In en, this message translates to:
  /// **'Sloth'**
  String get animalSloth;

  /// No description provided for @animalMonkey.
  ///
  /// In en, this message translates to:
  /// **'Monkey'**
  String get animalMonkey;

  /// No description provided for @hungerLabel.
  ///
  /// In en, this message translates to:
  /// **'Hunger'**
  String get hungerLabel;

  /// No description provided for @hungerNeverSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet.'**
  String get hungerNeverSaved;

  /// No description provided for @hungerSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String hungerSavedAt(Object time);

  /// No description provided for @hungerLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get hungerLive;

  /// No description provided for @animalListFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the animal list.'**
  String get animalListFailed;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings.'**
  String get settingsSaveFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
