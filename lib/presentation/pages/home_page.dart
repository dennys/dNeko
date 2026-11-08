import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/animal_resource.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/services/overlay_service.dart';
import '../../domain/pet_settings.dart';
import '../../domain/screen_metrics.dart';
import '../../l10n/app_localizations.dart';
import '../controllers/settings_controller.dart';
import '../controllers/store_controller.dart';
import 'store_page.dart';

/// 商店入口先關起來（不開放給使用者）。
///
/// 兩個必要條件都還沒到位，缺任何一個按「下載」都只會失敗：
/// 1. `StaticStoreCatalog._baseUrl` 還是佔位符 `https://example.com/animals`（素材根本不存在）
/// 2. `android/app/src/main/AndroidManifest.xml` 沒有 INTERNET 權限
/// 放一顆「注定失敗」的按鈕比不放更糟 —— 使用者會以為是自己網路的問題，而且失敗訊息是一串 dio 例外。
///
/// 要開放時：上面兩件**一起**改（只補權限沒用），並把這個常數改成 true；
/// 其餘（StoreController / StorePage / 下載服務 / 測試）都已經是通的。詳見 TODO.md。
const bool kStoreEnabled = false;

/// 唯一的主頁：開/關 + 全部設定都在這一頁滾。
/// 之前拆成「主頁只有一顆開關＋設定另一頁」，但每一項設定本來就是即時推給
/// 跑著的 overlay，多一層導航純粹是把同一件事拆兩邊寫（metrics 構造都重複了一份）。
class HomePage extends StatefulWidget {
  final SettingsController settingsController;
  final AnimalRepository animalRepository;
  final StoreController storeController;

  const HomePage({
    super.key,
    required this.settingsController,
    required this.animalRepository,
    required this.storeController,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _appChannel = MethodChannel('com.dneko/app');

  final _overlayService = OverlayService();
  bool _isActive = false;
  bool _isToggling = false;
  StreamSubscription<dynamic>? _quitSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
    // 懸浮選單按「結束」→ overlay 送 quit 過來：把主 app 自己也關掉
    _quitSub = _overlayService.events.listen(_onOverlayEvent);
    // 桌面捷徑在懸浮沒開時會把 MainActivity 拉起來並帶 pending action
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPendingShortcut());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quitSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用捷徑開關過後回來，按鈕狀態要跟上（不然會停在舊值）
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  void _onOverlayEvent(dynamic data) {
    if (data is! String) return;
    try {
      final map = jsonDecode(data);
      if (map is Map && map['cmd'] == 'quit') {
        _overlayService.close();
        SystemNavigator.pop();
      }
    } catch (_) {}
  }

  Future<void> _runPendingShortcut() async {
    try {
      final action = await _appChannel.invokeMethod<String>('takePendingAction');
      if (action != 'toggle' || !mounted) return;
      await _toggle();
      // 從捷徑進來的只是來開寵物，開完就閃人，不要滯留在主頁
      if (mounted) SystemNavigator.pop();
    } catch (_) {}
  }

  Future<void> _pinShortcut() async {
    try {
      final ok = await _appChannel.invokeMethod<bool>('pinToggleShortcut');
      if (ok != true && mounted) {
        _fail(context, AppLocalizations.of(context)!.shortcutPinUnsupported);
      }
    } catch (_) {}
  }

  Future<void> _checkStatus() async {
    final active = await _overlayService.isActive();
    if (mounted) setState(() => _isActive = active);
  }

  void _fail(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle() async {
    if (_isToggling || !mounted) return;

    final context = this.context;
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
          if (!granted) {
            if (context.mounted) _fail(context, AppLocalizations.of(context)!.overlayPermissionDenied);
            return;
          }
        }
        if (!context.mounted) return;
        await _overlayService.show(
          animalId: widget.settingsController.settings.animalId,
          settings: widget.settingsController.settings,
          metrics: _metricsOf(context),
          languageCode: _effectiveLanguageCode(context),
        );
        if (mounted) setState(() => _isActive = true);
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await _checkStatus();
    } catch (e) {
      // showOverlay 被平台擋掉時不能只讓按鈕轉一輪就回復原狀，總得讓使用者看到原因
      if (context.mounted) _fail(context, AppLocalizations.of(context)!.overlayFailed('$e'));
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  /// 設定改動：存檔，懸浮在跑就即時推過去
  Future<void> _apply(PetSettings next) async {
    await widget.settingsController.update(next);
    if (!mounted || !_isActive || !context.mounted) return;
    await _overlayService.pushSettings(
      animalId: next.animalId,
      settings: next,
      metrics: _metricsOf(context),
      languageCode: next.languageCode ?? _systemLanguageCode(context),
    );
  }

  ScreenMetrics _metricsOf(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ScreenMetrics(logicalSize: mq.size, devicePixelRatio: mq.devicePixelRatio);
  }

  String _systemLanguageCode(BuildContext context) {
    final l = Localizations.localeOf(context);
    return (l.countryCode == null || l.countryCode!.isEmpty)
        ? l.languageCode
        : '${l.languageCode}-${l.countryCode}';
  }

  String _effectiveLanguageCode(BuildContext context) =>
      widget.settingsController.settings.languageCode ?? _systemLanguageCode(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.settingsController;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.settingsTitle),
            actions: [
              if (kStoreEnabled)
                IconButton(
                  tooltip: l10n.storeTitle,
                  icon: const Icon(Icons.store),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StorePage(controller: widget.storeController)),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _toggleCard(l10n),
              const SizedBox(height: 24),
              Text(l10n.settingsAnimal),
              const SizedBox(height: 4),
              _AnimalPicker(
                key: ValueKey('animal-${settings.animalId}'),
                repository: widget.animalRepository,
                selected: settings.animalId,
                onSelected: (id) => _apply(settings.copyWith(animalId: id)),
              ),
              const SizedBox(height: 16),
              Text(l10n.settingsSpeed),
              Slider(
                value: settings.speedPxPerSecond,
                min: PetSettings.minSpeedPerSecond,
                max: PetSettings.maxSpeedPerSecond,
                divisions: (PetSettings.maxSpeedPerSecond - PetSettings.minSpeedPerSecond) ~/ 10,
                label: '${settings.speedPxPerSecond.round()} px/s',
                onChanged: (v) => controller.preview(settings.copyWith(speedPxPerSecond: v)),
                onChangeEnd: (v) => _apply(settings.copyWith(speedPxPerSecond: v)),
              ),
              const SizedBox(height: 8),
              Text(l10n.settingsSize),
              Slider(
                value: settings.petSize,
                min: PetSettings.minPetSize,
                max: PetSettings.maxPetSize,
                divisions: ((PetSettings.maxPetSize - PetSettings.minPetSize) / 10).round(),
                label: '${settings.petSize.round()} dp',
                onChanged: (v) => controller.preview(settings.copyWith(petSize: v)),
                onChangeEnd: (v) => _apply(settings.copyWith(petSize: v)),
              ),
              const SizedBox(height: 8),
              Text(l10n.settingsZone),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final zone in PetZone.values)
                    ChoiceChip(
                      label: Text(_zoneLabel(l10n, zone)),
                      selected: settings.zone == zone,
                      onSelected: (_) => _apply(settings.copyWith(zone: zone)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.settingsLanguage),
              const SizedBox(height: 4),
              // 語言用自己的文字顯示自己的名字（業界慣例），所以不需要 l10n
              DropdownMenu<String?>(
                expandedInsets: EdgeInsets.zero,
                initialSelection: settings.languageCode,
                dropdownMenuEntries: [
                  DropdownMenuEntry(value: null, label: l10n.languageSystem),
                  const DropdownMenuEntry(value: 'en', label: 'English'),
                  const DropdownMenuEntry(value: 'zh-TW', label: '繁體中文'),
                  const DropdownMenuEntry(value: 'zh', label: '简体中文'),
                  const DropdownMenuEntry(value: 'ja', label: '日本語'),
                ],
                onSelected: (code) => _apply(settings.copyWith(languageCode: code)),
              ),
              const SizedBox(height: 16),
              Text(l10n.settingsTheme),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in {
                    'system': l10n.themeSystem,
                    'light': l10n.themeLight,
                    'dark': l10n.themeDark,
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: settings.themeMode == option.key,
                      onSelected: (_) => _apply(settings.copyWith(themeMode: option.key)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_to_home_screen),
                label: Text(l10n.shortcutPin),
                onPressed: () => _pinShortcut(),
              ),
              const SizedBox(height: 24),
              Text(l10n.settingsAbout, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _VersionTile(label: l10n.settingsVersion),
            ],
          ),
        );
      },
    );
  }

  Widget _toggleCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isActive ? Icons.pets : Icons.pets_outlined,
              color: _isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(_buttonLabel(l10n))),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: Icon(_isActive ? Icons.stop : Icons.play_arrow),
              label: Text(_isActive ? l10n.overlayStop : l10n.overlayStart),
              onPressed: _isToggling ? null : () => _toggle(),
            ),
          ],
        ),
      ),
    );
  }

  String _buttonLabel(AppLocalizations l) {
    if (_isToggling) return _isActive ? l.overlayStopping : l.overlayStarting;
    return _isActive ? l.overlayRunning : l.overlayIdle;
  }

  String _zoneLabel(AppLocalizations l10n, PetZone zone) => switch (zone) {
        PetZone.fullScreen => l10n.zoneFullScreen,
        PetZone.bottomBand => l10n.zoneBottomBand,
        PetZone.topLeft => l10n.zoneTopLeft,
        PetZone.topRight => l10n.zoneTopRight,
        PetZone.bottomLeft => l10n.zoneBottomLeft,
        PetZone.bottomRight => l10n.zoneBottomRight,
      };
}

/// 動物清單（內建＋已下載都在 DB 裡）做成 chip。
/// Future 只建一次存成欄位：頁面會隨 slider 拖动不停重建，放 build 裡會每帧重查 DB。
class _AnimalPicker extends StatefulWidget {
  final AnimalRepository repository;
  final String selected;
  final ValueChanged<String> onSelected;

  const _AnimalPicker({
    super.key,
    required this.repository,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_AnimalPicker> createState() => _AnimalPickerState();
}

class _AnimalPickerState extends State<_AnimalPicker> {
  late final Future<List<AnimalResource>> _animals = widget.repository.getAll();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnimalResource>>(
      future: _animals,
      builder: (context, snap) {
        final animals = snap.data;
        if (animals == null) return const SizedBox(height: 38);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final animal in animals)
              ChoiceChip(
                label: Text(animal.displayName),
                selected: animal.animalId == widget.selected,
                onSelected: (_) => widget.onSelected(animal.animalId),
              ),
          ],
        );
      },
    );
  }
}

class _VersionTile extends StatefulWidget {
  final String label;

  const _VersionTile({required this.label});

  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) {
        final v = snap.data == null ? '…' : '${snap.data!.version} (${snap.data!.buildNumber})';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.label),
          trailing: Text(v),
        );
      },
    );
  }
}
