import 'dart:async';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'overlay_main.dart' as overlay_entry;
import 'menu_main.dart' as menu_entry;
import 'data/repositories/animal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/animal_download_service.dart';
import 'data/services/static_store_catalog.dart';
import 'domain/locale_code.dart';
import 'platform/pet_platform.dart';
import 'platform/windows/windows_pet_app.dart';
import 'domain/pet_settings.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/controllers/store_controller.dart';
import 'presentation/pages/home_page.dart';
import 'utils/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows：整個 app 就是那顆懸浮視窗（沒有主 app 設定頁，也不該去碰 overlay 插件 ——
  // flutter_overlay_window 是 Android only，它在 Windows 連 plugin 註冊都沒有）。
  // 分岔只認 PetPlatform 這一處，要再加桌面平台就在.pet_platform.dart 加。
  if (PetPlatform.current.isWindowsPet) {
    FlutterError.onError = (details) => appError('framework 例外', details.exception, details.stack);
    await runWindowsPetApp();
    return;
  }
  final repository = AnimalRepository();
  final settingsRepository = SettingsRepository();

  // 兩者都在 runApp() 之前、都要碰 DB：以前一個 try 都沒有，DB 損毀或是首次開檔失敗
  // 就是白屏崩潰（app 連開都開不起來，連重裝的按钮都看不到）。overlay 那側早就有
  // `_readOr` 防呆，主 app 卻沒有 —— 防護不對稱。記 log 後用內建素材 + 預設設定開起來。
  PetSettings? initial;
  try {
    initial = await settingsRepository.load();
  } catch (e, st) {
    appError('讀設定失敗，改用預設值', e, st);
  }

  final downloadService = AnimalDownloadService(repository, settingsRepository);
  final settingsController = SettingsController(
    repository: settingsRepository,
    initial: initial,
  );
  final storeController = StoreController(
    catalog: StaticStoreCatalog(),
    downloadService: downloadService,
    repository: repository,
    // 商店要問得到「現在選的是哪隻」才不會把使用者正在養的那隻刪掉
    currentAnimalId: () => settingsController.settings.animalId,
  );
  // 本案没有後端、也没有 crash 回報，logcat 是唯一的支持管道：
  // 未捕获的 async 例外在 release 會静悄悄消失，至少要把它们留在 logcat 裡。
  // runZonedGuarded 抓 async 例外；FlutterError.onError 抓 framework/render 例外
  // （它們走 reportError，不會 rethrow 進 zone，只靠 zone 抓不到）。
  FlutterError.onError = (details) => appError('framework 例外', details.exception, details.stack);
  runZonedGuarded(
    () => runApp(MyApp(
      storeController: storeController,
      settingsController: settingsController,
      animalRepository: repository,
    )),
    (e, st) => appError('未捕获例外', e, st),
  );
}

@pragma('vm:entry-point')
void overlayMain() {
  overlay_entry.runOverlayApp();
}

/// 選單的第二個懸浮視窗（原生 `MenuOverlay.kt` 用這個名字起第二顆 engine）
@pragma('vm:entry-point')
void menuMain() {
  menu_entry.runMenuApp();
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
        final languageCode = settings.languageCode;
        return MaterialApp(
          title: 'dNeko',
          locale: languageCode == null ? null : localeOfCode(languageCode), // null = 跟隨系統
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
}
