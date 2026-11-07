import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'overlay_main.dart' as overlay_entry;
import 'data/repositories/animal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/animal_download_service.dart';
import 'data/services/static_store_catalog.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/controllers/store_controller.dart';
import 'presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = AnimalRepository();
  await repository.seedBuiltIns();
  final settingsRepository = SettingsRepository();
  final downloadService = AnimalDownloadService(repository);
  final storeController = StoreController(
    catalog: StaticStoreCatalog(),
    downloadService: downloadService,
    repository: repository,
  );
  final settingsController = SettingsController(
    repository: settingsRepository,
    initial: await settingsRepository.load(),
  );
  runApp(MyApp(
    storeController: storeController,
    settingsController: settingsController,
    animalRepository: repository,
  ));
}

@pragma('vm:entry-point')
void overlayMain() {
  overlay_entry.runOverlayApp();
}

class MyApp extends StatelessWidget {
  final StoreController storeController;
  final SettingsController settingsController;
  final AnimalRepository animalRepository;

  const MyApp({
    super.key,
    required this.storeController,
    required this.settingsController,
    required this.animalRepository,
  });

  @override
  Widget build(BuildContext context) {
    // 語言與外觀模式是使用者設定：跟著 controller 重建，改完立刻換，不用重開 app
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;
        return MaterialApp(
          title: 'dNeko',
          locale: _localeOf(settings.languageCode), // null = 跟隨系統
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 與 dHealth 同一顆 seed（兩案用同一個 ColorScheme.fromSeed 做法），看起來才是一家人
          theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
          ),
          themeMode: switch (settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          home: HomePage(
            settingsController: settingsController,
            animalRepository: animalRepository,
            storeController: storeController,
          ),
        );
      },
    );
  }

  /// 'zh-TW' 這種帶地区碼的要拆成 Locale('zh','TW')；當單一語言碼塞進去會比對不到 arb
  static Locale? _localeOf(String? code) {
    if (code == null) return null;
    final parts = code.split(RegExp('[-_]'));
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }
}
