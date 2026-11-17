import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/models/animation_definition.dart';
import '../../data/models/animal_resource.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/animal_sound.dart';
import '../../data/services/animation_loader.dart';
import '../../domain/i_overlay_window.dart';
import '../../domain/locale_code.dart';
import '../../domain/menu_payload.dart';
import '../../domain/pet_behavior.dart';
import '../../domain/pet_settings.dart';
import '../../domain/pet_stats.dart';
import '../../domain/screen_metrics.dart';
import '../../l10n/app_localizations.dart';
import '../../menu_main.dart' show menuIconFor;
import '../../presentation/controllers/menu_director.dart';
import '../../presentation/controllers/overlay_pet_driver.dart';
import '../../presentation/controllers/pet_controller.dart';
import '../../presentation/controllers/pet_controller_factory.dart';
import '../../presentation/widgets/animal_animator.dart';
import '../../presentation/widgets/feeding_menu.dart';
import '../../utils/log.dart';
import 'pet_window_geometry.dart';
import 'windows_overlay_window.dart';

/// Windows 桌寵版的入口：**整個 app 就是那顆懸浮視窗**。
///
/// 與 Android 的對應關係（為什麼可以這麼省）：
/// * Android 的寵物跑在插件的懸浮視窗 + 獨立 isolate，選單是**第二顆**視窗；
///   Windows 沒有 `FlutterTextureView` 那個 resize 拉伸 bug，所以寵物與選單共用一顆視窗，
///   也不需要 `flutter_overlay_window`、第二顆 engine 與 isolate 那一整套。
/// * 代價：這支 shell 與 `overlay_main.dart` 的接線有部分重覆（載入動物、選單派工、存狀態）。
///   刻意**不抽公共父層** —— 兩邊的視窗模型差很多（一個要問插件肯不肯搬、一個是自己家的視窗），
///   硬抽會抽出一堆 `if (isWindows)`，比重覆更難讀。真正共用的是承重的那幾件：
///   [PetController]、[MenuDirector]、[ScreenMetrics]、`SettingsRepository`（含各養各的）、
///   [AnimalAnimator]、[FeedingMenu]。
///
/// ⚠️ 本檔是**盲寫**（開發機是 Linux/aarch64，編不了 Windows 目標）。上機前的驗收程序、
/// 各層預期要修的地方都在 `WINDOWS.md`。
Future<void> runWindowsPetApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => appError('framework 例外', d.exception, d.stack);
  windowManager.ensureInitialized();
  // 透明、無邊框、頂置、不進工作列、**不搶焦點**（WS_EX_NOACTIVATE）這些在視窗「建立時」
  // 就設好才可靠，所以放在 windows/runner 的 C++（見 WINDOWS.md）。Dart 側只做插件做得到
  // 的部分，而且任何一項失敗都不該擋下寵物出現 —— 全部吞掉記 log。
  for (final step in <Future<void> Function()>[
    () => windowManager.setHasShadow(false),
    () => windowManager.setSkipTaskbar(true),
    () => windowManager.setAlwaysOnTop(true),
    () => windowManager.setResizable(false),
    () => windowManager.setBackgroundColor(const Color(0x00000000)),
  ]) {
    try {
      await step();
    } catch (e, st) {
      appError('Windows 視窗設定失敗（略過，寵物照樣開）', e, st);
    }
  }
  runZonedGuarded(
    () => runApp(const WindowsPetApp()),
    (e, st) => appError('未捕获例外', e, st),
  );
}

class WindowsPetApp extends StatelessWidget {
  const WindowsPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dNeko',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      home: const _PetShell(),
    );
  }
}

class _PetShell extends StatefulWidget {
  const _PetShell();

  @override
  State<_PetShell> createState() => _PetShellState();
}

class _PetShellState extends State<_PetShell> {
  static const _menuTimeout = Duration(seconds: 6);
  static const _controllerFactory = PetControllerFactory();

  /// 系統匣圖示；Windows 要 .ico 時改這裡（見 WINDOWS.md）
  static const _trayIconAsset = 'assets/images/icon.png';

  final _repository = AnimalRepository();
  final _settingsRepository = SettingsRepository();
  final _loader = AnimationLoader();
  final _sound = AudioPlayerSoundPlayer();

  PetSettings _settings = const PetSettings();
  ScreenMetrics _metrics = const ScreenMetrics(logicalSize: Size(1280, 720), devicePixelRatio: 1);
  AnimalResource? _resource;
  AnimalAnimationDefinition? _definition;
  PetController? _controller;
  OverlayPetDriver? _driver;
  final IOverlayWindow _window = const WindowsOverlayWindow();
  String? _animalId;
  AppLocalizations? _l10n;
  double _petSize = PetSettings.defaultPetSize;
  bool _trayReady = false;

  /// 選單開著時疊在同一顆視窗裡（Android 那边是第二顆視窗）
  WindowLayout? _menuLayout;
  MenuPayload _menuPayload = const MenuPayload(
    themeMode: 'system',
    languageCode: 'en',
    hunger: 0,
    hungryThreshold: PetStats.defaultHungryThreshold,
    bondValue: 0,
    labels: {},
  );
  late final MenuDirector _menu = MenuDirector(
    timeout: _menuTimeout,
    onPause: _pausePetForMenu,
    onResume: _resumePetAfterMenu,
    onHideWindow: _hideMenuWindow,
    onAction: _runMenuAction,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      // 視窗由 runner 建立但**沒有 Show()**（否則會先閃一塊 1280×720 的白），
      // 等寵物尺寸與位置都設定了才顯示。
      try {
        await windowManager.show();
      } catch (e, st) {
        appError('顯示視窗失敗', e, st);
      }
      await _setupTray();
    });
  }

  @override
  void dispose() {
    final controller = _controller;
    final id = _animalId;
    controller?.removeListener(_onTick);
    _driver?.dispose();
    controller?.dispose();
    unawaited(_sound.dispose());
    // dispose 只可能是整個 app 在收尾（Windows 版沒有「換頁」會拆掉這顆）：抓最後一筆餓度
    if (id != null && controller != null) {
      unawaited(_settingsRepository.stow(id, hunger: controller.stats.hunger).catchError((e, st) {
        appError('收尾存餓度失敗', e, st);
      }));
    }
    _destroyTray();
    super.dispose();
  }

  /// 螢幕的**邏輯**尺寸。用 Flutter 自己的 `PlatformDispatcher`（`view.display.size` 是實體
  /// 像素、`devicePixelRatio` 是縮放比），不必為這個拉 screen_retriever 進來。
  ///
  /// shortcut: 沒扣工作列（Flutter 在 Windows 沒給 visible bounds），「僅下方」那條帶可能
  /// 壓到工作列；要準就在 Windows 側取 workArea 換掉這裡 —— 上機看過再決定。
  ScreenMetrics _screenMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final dpr = view.display.devicePixelRatio;
    final physical = view.display.size;
    if (dpr <= 0 || physical.width <= 0 || physical.height <= 0) {
      return const ScreenMetrics(logicalSize: Size(1280, 720), devicePixelRatio: 1);
    }
    return ScreenMetrics(
      logicalSize: Size(physical.width / dpr, physical.height / dpr),
      devicePixelRatio: dpr,
    );
  }

  /// 讀設定 + 那隻動物的素材與存檔，重建 controller。設定變更（大小/範圍）也走這裡。
  Future<void> _load() async {
    PetSettings settings;
    try {
      settings = await _settingsRepository.load();
    } catch (e, st) {
      appError('讀設定失敗，改用預設值', e, st);
      settings = const PetSettings();
    }

    AnimalResource? resource;
    AnimalAnimationDefinition? definition;
    try {
      // resolveResource：DB（下載過的那份）優先，讀不到 DB 會退回內建素材 —— 與 overlay 同一條路
      resource = await _repository.resolveResource(settings.animalId);
      if (resource != null) definition = await _loader.load(resource);
    } catch (e, st) {
      appError('載入動物失敗（寵物會看不見，但程式不會倒）', e, st);
    }

    final petSize = settings.petSize;
    final metrics = _screenMetrics();
    final roam = Rect.fromLTRB(
      0,
      0,
      metrics.logicalSize.width - petSize,
      metrics.logicalSize.height - petSize,
    );
    final bounds = metrics.zoneBounds(
      roam,
      petSize,
      settings.zone,
      bottomBandFraction: settings.bottomBandFraction,
    );

    final old = _controller;
    final oldDriver = _driver;
    final oldId = _animalId;

    final animalId = resource?.animalId ?? settings.animalId;
    final now = DateTime.now();
    double hunger = 0;
    var startPosition = Offset(
      (bounds.left + bounds.right - petSize) / 2,
      (bounds.top + bounds.bottom - petSize) / 2,
    );
    try {
      // 各養各的：讀這隻自己的餓度/位置；「收起來過」的就不補飢餓（規則見 hungerOnWake）
      hunger = hungerOnWake(await _settingsRepository.loadHunger(animalId), now);
      startPosition = await _settingsRepository.loadPosition(animalId) ?? startPosition;
    } catch (e, st) {
      appError('讀寵物狀態失敗，改用預設值', e, st);
    }

    PetController? controller;
    OverlayPetDriver? driver;
    if (definition != null) {
      // 沒有 definition（素材壞掉）就單純不畫：與 overlay_main 的佔位行為一致，
      // 而且要 fake 一份 definition 得亂編 frameWidth 等欄位，不如讓它空著並留 log。
      controller = _controllerFactory.create(
        bounds: bounds,
        definition: definition,
        speedPerTick: settings.speedPerTick,
        stats: PetStats(initialHunger: hunger),
        position: startPosition,
      );
      driver = OverlayPetDriver(controller, _window);
      controller.addListener(_onTick);
      controller.start();
    }

    setState(() {
      _settings = settings;
      _metrics = metrics;
      _resource = resource;
      _definition = definition;
      _petSize = petSize;
      _animalId = animalId;
      _controller = controller;
      _driver = driver;
      _menuLayout = null;
    });

    // 舊的那隻收起來（餓度定格）再拆：順序反了會把新動物的餓度存進舊 id
    old?.removeListener(_onTick);
    old?.stop();
    oldDriver?.dispose();
    if (oldId != null && old != null && oldId != animalId) {
      try {
        await _settingsRepository.stow(oldId, hunger: old.stats.hunger);
      } catch (e, st) {
        appError('收起舊寵物失敗', e, st);
      }
    }
    old?.dispose();

    if (controller != null) {
      try {
        await _window.resize(width: petSize, height: petSize);
        await _window.moveTo(controller.position);
      } catch (e, st) {
        appError('設定視窗大小/位置失敗', e, st);
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  // ===================== 選單（疊在同一顆視窗）=====================

  void _pausePetForMenu() {
    _controller?.setPaused(true);
    _driver?.setEnabled(false);
  }

  void _resumePetAfterMenu() {
    _controller?.setPaused(false);
    _driver?.setEnabled(true);
  }

  Future<void> _hideMenuWindow() async {
    final layout = _menuLayout;
    if (layout == null) return;
    setState(() => _menuLayout = null);
    // 先縮回寵物大小、再搬回原位：順序反过来會看到選單那塊在錯誤位置閃一下
    final petTopLeft = Offset(
      layout.window.left + layout.petAt.dx,
      layout.window.top + layout.petAt.dy,
    );
    await _window.resize(width: _petSize, height: _petSize);
    await _window.moveTo(petTopLeft);
  }

  Future<void> _openMenu() async {
    final controller = _controller;
    if (controller == null) return;
    const menuSize = Size(FeedingMenu.contentWidth, FeedingMenu.contentHeight);
    try {
      await _menu.open(() async {
        final layout = layoutWithMenu(
          petPos: controller.position,
          petSize: _petSize,
          menuSize: menuSize,
          screen: Rect.fromLTWH(0, 0, _metrics.logicalSize.width, _metrics.logicalSize.height),
        );
        _menuPayload = _buildPayload(controller);
        setState(() => _menuLayout = layout);
        await _window.resize(width: layout.window.width, height: layout.window.height);
        await _window.moveTo(layout.window.topLeft);
      });
    } catch (e, st) {
      // 擺位、resize、moveTo 任一失敗都算開不成；MenuDirector 已負責把寵物解凍
      appError('選單開不起來', e, st);
    }
  }

  MenuPayload _buildPayload(PetController controller) {
    final l10n = _l10n;
    return MenuPayload(
      themeMode: _settings.themeMode,
      languageCode: _locale.languageCode,
      hunger: controller.stats.hunger,
      hungryThreshold: controller.stats.hungryThreshold,
      bondValue: controller.stats.bondValue.round(),
      labels: {
        if (l10n != null)
          ...{
            'feed': l10n.menuFeed,
            'pet': l10n.menuPet,
            'freeze': controller.frozen ? l10n.menuUnfreeze : l10n.menuFreeze,
            'close': l10n.menuClose,
            'quit': l10n.menuQuit,
            'feedUnfreezes': l10n.menuFeedUnfreezes,
            PetBehavior.lookAround.name: l10n.menuActionLookAround,
            PetBehavior.doze.name: l10n.menuActionDoze,
            PetBehavior.wobble.name: l10n.menuActionWobble,
            PetBehavior.hop.name: l10n.menuActionHop,
            PetBehavior.stretch.name: l10n.menuActionStretch,
            PetBehavior.circle.name: l10n.menuActionCircle,
            PetBehavior.beg.name: l10n.menuActionBeg,
            PetBehavior.faint.name: l10n.menuActionFaint,
          },
      },
    );
  }

  /// 選單那側（Android 是另一顆 engine，Windows 是同一顆視窗）都靠 [MenuDirector.onCommand]
  /// 的 JSON 協定進場；Windows 這側虽是直 call，仍走同一個協定 —— 兩邊行為才不會分岔。
  void _menuCommand(String action) => _menu.onCommand(jsonEncode({'action': action}));

  void _runMenuAction(String action) {
    final controller = _controller;
    if (controller == null) return;
    switch (action) {
      case 'feed':
        controller.feedAt(
          Offset(controller.position.dx + _petSize / 2, controller.position.dy + _petSize),
        );
      case 'pet':
        controller.pet();
      case 'freeze':
        controller.setFrozen(!controller.frozen);
      case 'quit':
        unawaited(_quit());
      case 'close':
        break; // 關選單是 MenuDirector 的事，這裡不用做事
      default:
        final behavior = PetBehavior.values.firstWhere(
          (b) => b.name == action,
          orElse: () => PetBehavior.idle,
        );
        if (behavior != PetBehavior.idle) controller.playFlourish(behavior);
    }
    _onTick();
  }

  Future<void> _quit() async {
    final id = _animalId;
    final controller = _controller;
    if (id != null && controller != null) {
      try {
        // 正常結束 = 「收起來」：餓度定格在此刻，下次開不補飢餓（各養各的那節的規則）
        await _settingsRepository.stow(id, hunger: controller.stats.hunger);
        await _settingsRepository.savePosition(id, controller.position);
      } catch (e, st) {
        appError('結束前存狀態失敗', e, st);
      }
    }
    _destroyTray();
    try {
      await windowManager.destroy();
    } catch (e, st) {
      appError('關視窗失敗', e, st);
    }
    exit(0);
  }

  // ===================== 系統匣 =====================

  /// 系統匣是目前 Windows 版唯一的設定入口（設定視窗還沒做，見 WINDOWS.md 的層級表）：
  /// 顯示/隱藏、大小、活動範圍、結束。
  /// 整段吞例外 —— 托盤建不起來（圖檔格式、原生端失敗）不該讓寵物不出現。
  Future<void> _setupTray() async {
    if (_trayReady) return;
    final l10n = _l10n;
    if (l10n == null) return;
    try {
      final tray = TrayManager.instance;
      await tray.setIcon(_trayIconAsset);
      await tray.setToolTip('dNeko');
      await tray.setContextMenu(
        Menu(
          items: [
            MenuItem(label: l10n.overlayShow, onClick: (_) => _show()),
            MenuItem(label: l10n.overlayHide, onClick: (_) => _hide()),
            MenuItem.separator(),
            // 穿透開了之後寵物就點不到（這是它的用途），所以**一定要留兩項**讓人關得回來；
            // 唯一退路是系統匣本身，所以這組放在最上面、且整段托盤失敗時會有 log。
            MenuItem(label: l10n.overlayClickThroughOn, onClick: (_) => _setClickThrough(true)),
            MenuItem(label: l10n.overlayClickThroughOff, onClick: (_) => _setClickThrough(false)),
            MenuItem.separator(),
            MenuItem.submenu(
              label: l10n.settingsSize,
              submenu: Menu(
                items: [
                  for (final size in const [PetSettings.minPetSize, PetSettings.defaultPetSize, PetSettings.maxPetSize])
                    MenuItem(
                      label: '${size.toInt()} px',
                      onClick: (_) => _updateSettings(_settings.copyWith(petSize: size)),
                    ),
                ],
              ),
            ),
            MenuItem.submenu(
              label: l10n.settingsZone,
              submenu: Menu(
                items: [
                  for (final zone in PetZone.values)
                    MenuItem(
                      label: _zoneLabel(zone),
                      onClick: (_) => _updateSettings(_settings.copyWith(zone: zone)),
                    ),
                ],
              ),
            ),
            MenuItem.separator(),
            MenuItem(label: l10n.menuQuit, onClick: (_) => _quit()),
          ],
        ),
      );
      _trayReady = true;
    } catch (e, st) {
      appError('系統匣設定失敗（寵物照樣可用，只是沒有托盤選單）', e, st);
    }
  }

  String _zoneLabel(PetZone zone) {
    final l10n = _l10n;
    if (l10n == null) return zone.name;
    return switch (zone) {
      PetZone.fullScreen => l10n.zoneFullScreen,
      PetZone.bottomBand => l10n.zoneBottomBand,
      PetZone.topLeft => l10n.zoneTopLeft,
      PetZone.topRight => l10n.zoneTopRight,
      PetZone.bottomLeft => l10n.zoneBottomLeft,
      PetZone.bottomRight => l10n.zoneBottomRight,
    };
  }

  /// 系統匣「顯示」。`PetController.start()` 本來就是冪等（`_timer ??= ...`），
  /// 所以不必自己記可見旗標；`restart()` 只是清 driver 的停止旗標，多叫無害。
  Future<void> _show() async {
    try {
      await windowManager.show();
    } catch (e, st) {
      appError('顯示視窗失敗', e, st);
      return;
    }
    _controller?.start();
  }

  /// 隱藏 = 也收起來（與 Android「關掉懸浮」同義）：**一定要連定時器一起停** ——
  /// 只 hide 視窗的話 16ms 的 tick 還在跳，寵物在看不見的地方散步、位置一直寫盤、
  /// CPU 白燒（Android 那边同樣的坑，那邊靠 moveTo 被連續拒絕才發現）。
  /// 餓度同時標成「收起來」，所以掛在背裡不會變餓。
  Future<void> _hide() async {
    final id = _animalId;
    final controller = _controller;
    if (id != null && controller != null) {
      try {
        await _settingsRepository.stow(id, hunger: controller.stats.hunger);
      } catch (e, st) {
        appError('隱藏前存餓度失敗', e, st);
      }
    }
    _controller?.stop();
    try {
      await windowManager.hide();
    } catch (e, st) {
      appError('隱藏視窗失敗', e, st);
    }
  }

  /// 滑鼠穿透：WS_EX_TRANSPARENT（window_manager 會連 WS_EX_LAYERED 一起給）
  Future<void> _setClickThrough(bool ignore) async {
    try {
      await windowManager.setIgnoreMouseEvents(ignore);
    } catch (e, st) {
      appError('切換滑鼠穿透失敗', e, st);
    }
  }

  void _destroyTray() {
    if (!_trayReady) return;
    _trayReady = false;
    try {
      TrayManager.instance.destroy();
    } catch (_) {
      // 收尾階段的托盤失敗沒有意義，丟掉
    }
  }

  Future<void> _updateSettings(PetSettings next) async {
    if (next == _settings) return;
    try {
      await _settingsRepository.save(next);
    } catch (e, st) {
      appError('存設定失敗', e, st);
    }
    await _load();
  }

  /// 選單打包用的語系；`languageCode == null` 是「跟隨系統」，此時標籤文字本來就是
  /// 由 build 當時的 AppLocalizations 翻好的，這個欄位只在 Android 那側（另一顆 engine）有意義。
  Locale get _locale => localeOfCode(_settings.languageCode ?? 'en');

  // ===================== 畫面 =====================

  @override
  Widget build(BuildContext context) {
    _l10n = AppLocalizations.of(context);
    final controller = _controller;
    final definition = _definition;
    final resource = _resource;
    final layout = _menuLayout;
    final petSize = _petSize;
    final starving = controller?.stats.isStarving ?? false;

    return Scaffold(
      // 視窗本身已由 runner 建為透明；Material 預設會鋪一層 scaffold 色，
      // 不壓掉就會看到寵物後面一塊灰底板。
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            left: layout?.petAt.dx ?? 0,
            top: layout?.petAt.dy ?? 0,
            width: petSize,
            height: petSize,
            child: controller == null || definition == null || resource == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.pet();
                      unawaited(_sound.play(
                        'assets/sounds/touch.mp3',
                        rate: starving ? 0.85 : 1.0,
                      ));
                    },
                    onDoubleTap: () => controller.feedAt(
                      Offset(
                        controller.position.dx + petSize / 2,
                        controller.position.dy + petSize,
                      ),
                    ),
                    onLongPress: _openMenu,
                    // 拖曳交回原生（startDragging）：自己算 mouseMove 再 setPosition 會
                    // 跟著 16ms 的 tick 抖，而且滑鼠放開的時機要在視窗外面才收得到
                    onPanStart: (_) {
                      unawaited(windowManager.startDragging());
                    },
                    child: AnimalAnimator(
                      resource: resource,
                      definition: definition,
                      action: controller.action,
                      loader: _loader,
                      displayWidth: petSize,
                      displayHeight: petSize,
                      starving: starving,
                    ),
                  ),
          ),
          if (layout != null)
            Positioned(
              left: layout.menuAt.dx,
              top: layout.menuAt.dy,
              width: FeedingMenu.contentWidth,
              child: Material(
                color: Colors.transparent,
                child: FeedingMenu(
                  feedLabel: _menuPayload.labelFor('feed'),
                  petLabel: _menuPayload.labelFor('pet'),
                  closeLabel: _menuPayload.labelFor('close'),
                  freezeLabel: _menuPayload.labelFor('freeze'),
                  quitLabel: _menuPayload.labelFor('quit'),
                  onFeed: () => _menuCommand('feed'),
                  onPet: () => _menuCommand('pet'),
                  onFreeze: () => _menuCommand('freeze'),
                  onClose: () => _menu.close(),
                  onQuit: () => _menuCommand('quit'),
                  onInteract: () => _menuCommand(MenuDirector.interactAction),
                  footnote: _menuPayload.labelFor('feedUnfreezes'),
                  tiles: [
                    for (final behavior in kFlourishBehaviors)
                      FeedingMenuTile(
                        icon: menuIconFor(behavior),
                        label: _menuPayload.labelFor(behavior.name),
                        onTap: () => _menuCommand(behavior.name),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
