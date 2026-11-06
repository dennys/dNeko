import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'overlay_main.dart' as overlay_entry;
import 'data/repositories/animal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/animal_download_service.dart';
import 'data/services/overlay_service.dart';
import 'data/services/static_store_catalog.dart';
import 'domain/pet_settings.dart';
import 'domain/screen_metrics.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/controllers/store_controller.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/store_page.dart';

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
  ));
}

@pragma('vm:entry-point')
void overlayMain() {
  overlay_entry.runOverlayApp();
}

class MyApp extends StatelessWidget {
  final StoreController storeController;
  final SettingsController settingsController;

  const MyApp({
    super.key,
    required this.storeController,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dNeko',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        // 與 dHealth 同一顆 seed（兩案用同一個 ColorScheme.fromSeed 做法），看起來才是一家人
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomePage(
        storeController: storeController,
        settingsController: settingsController,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final StoreController storeController;
  final SettingsController settingsController;

  const HomePage({
    super.key,
    required this.storeController,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('dNeko'),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  controller: settingsController,
                  overlayService: OverlayService(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.storeTitle,
            icon: const Icon(Icons.store),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StorePage(controller: storeController),
              ),
            ),
          ),
        ],
      ),
      body: _OverlayControl(settingsController: settingsController),
    );
  }
}

class _OverlayControl extends StatefulWidget {
  final SettingsController settingsController;

  const _OverlayControl({required this.settingsController});

  @override
  State<_OverlayControl> createState() => _OverlayControlState();
}

class _OverlayControlState extends State<_OverlayControl> {
  final _overlayService = OverlayService();
  bool _isActive = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final active = await _overlayService.isActive();
    if (mounted) setState(() => _isActive = active);
  }

  Future<void> _toggle(BuildContext context) async {
    if (_isToggling) return;

    setState(() => _isToggling = true);
    try {
      final active = await _overlayService.isActive();
      if (active) {
        await _overlayService.close();
        if (mounted) setState(() => _isActive = false);
      } else {
        final hasPermission = await _overlayService.hasPermission();
        if (!hasPermission) {
          final granted = await _overlayService.requestPermission();
          if (!granted || !context.mounted) return;
        }
        if (!context.mounted) return;
        final mq = MediaQuery.of(context);
        final metrics = ScreenMetrics(
          logicalSize: mq.size,
          devicePixelRatio: mq.devicePixelRatio,
          bottomInset: mq.padding.bottom,
        );
        final locale = Localizations.localeOf(context);
        await _overlayService.show(
          animalId: defaultAnimalId,
          settings: widget.settingsController.settings,
          metrics: metrics,
          languageCode: locale.languageCode,
        );
        if (mounted) setState(() => _isActive = true);
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await _checkStatus();
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(_isActive ? Icons.stop : Icons.play_arrow),
        label: Text(_buttonLabel),
        onPressed: _isToggling ? null : () => _toggle(context),
      ),
    );
  }

  String get _buttonLabel {
    if (_isToggling) return _isActive ? 'Stopping...' : 'Starting...';
    return _isActive ? 'Stop Overlay' : 'Start Overlay';
  }
}
