import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'l10n/app_localizations.dart';
import 'data/repositories/animal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/animation_loader.dart';
import 'data/services/overlay_window.dart';
import 'data/models/animal_resource.dart';
import 'data/models/animation_definition.dart';
import 'data/models/animation_action.dart';
import 'domain/pet_settings.dart';
import 'domain/pet_stats.dart';
import 'domain/screen_metrics.dart';
import 'presentation/controllers/pet_controller.dart';
import 'presentation/controllers/pet_controller_factory.dart';
import 'presentation/controllers/overlay_pet_driver.dart';
import 'presentation/widgets/animal_animator.dart';
import 'presentation/widgets/feeding_menu.dart';

void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

enum _WindowState { collapsed, menu }

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  static const _controllerFactory = PetControllerFactory();

  /// 選單寬度至少要裝得下按鈕（140）＋ Card padding（24）
  double get _menuWidth => math.max(_settings.petSize, 164.0);
  double get _menuHeight => _settings.petSize + 176;

  /// 餵食時食物擲在牠旁邊多遠
  static const double _feedDropDistance = 120;

  /// 飢餓值落盤的節流間隔
  static const Duration _hungerSaveInterval = Duration(seconds: 60);

  final _repository = AnimalRepository();
  final _settingsRepository = SettingsRepository();
  final _loader = AnimationLoader();

  PetController? _controller;
  OverlayPetDriver? _driver;
  AnimalResource? _resource;
  AnimalAnimationDefinition? _definition;
  PetSettings _settings = const PetSettings();
  ScreenMetrics _metrics = const ScreenMetrics(
    logicalSize: Size(360, 720),
    devicePixelRatio: 1,
  );
  double _petSize = PetSettings.defaultPetSize;
  _WindowState _state = _WindowState.collapsed;
  Locale _locale = const Locale('en'); // overlay 自己的語系
  bool _loadFailed = false;
  DateTime _lastHungerSave = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen(_onData);
    unawaited(_loadDefaultAnimal());
  }

  Future<void> _loadDefaultAnimal() async {
    _settings = await _readOr(() => _settingsRepository.load(), const PetSettings());
    if (!mounted || _resource != null) return; // 主 app 的 payload 先到就別再用預設值重載
    await _loadAnimal(defaultAnimalId, _metrics);
  }

  /// overlay 是獨立 isolate，sqflite 在裡頭不一定可用：讀不到就用預設，
  /// 绝不能因為設定/餓度拉不到就让寵物消失。
  Future<T> _readOr<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _onData(dynamic data) async {
    if (data is! String || !mounted) return;
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final animalId = map['animalId'] as String?;
    if (animalId == null) return;

    final rawSettings = map['settings'];
    if (rawSettings is Map) {
      _settings = PetSettings.fromJson(Map<String, dynamic>.from(rawSettings));
    }
    final languageCode = map['languageCode'] as String? ?? 'en';
    _metrics = ScreenMetrics.fromJson(
      map['metrics'] as Map<String, dynamic>,
    );
    setState(() => _locale = Locale(languageCode));

    // 同一隻寵物 → 只把新設定套上去，不重載（重載會把位置與行為清零，很突兀）
    final controller = _controller;
    if (controller != null && animalId == _resource?.animalId) {
      await _applySettings();
      return;
    }
    await _loadAnimal(animalId, _metrics);
  }

  /// 設定頁改動後即時生效：速度、可漫遊範圍、視窗尺寸
  Future<void> _applySettings() async {
    setState(() => _petSize = _settings.petSize);
    _controller
      ?..setSpeedPerTick(_settings.speedPerTick)
      ..updateBounds(_metrics.zoneBounds(_settings.petSize, _settings.zone));
    if (_state == _WindowState.collapsed) await _resizePetWindow();
  }

  Future<void> _loadAnimal(String animalId, ScreenMetrics metrics) async {
    try {
      final resource = await _resolveResource(animalId);
      if (resource == null) {
        if (mounted) setState(() => _loadFailed = true);
        return;
      }
      final definition = await _loader.load(resource);
      if (!mounted) return;

      final bounds = metrics.zoneBounds(_settings.petSize, _settings.zone);
      const window = OverlayWindow();

      _driver?.dispose();
      _controller?.dispose();

      await _resizePetWindow();

      final hunger = await _readOr(() => _settingsRepository.loadHunger(), null);
      final controller = _controllerFactory.create(
        bounds: bounds,
        definition: definition,
        speedPerTick: _settings.speedPerTick,
        stats: PetStats(initialHunger: hunger ?? 0),
      )..start();
      final driver = OverlayPetDriver(controller, window);
      _watchHunger(controller);

      setState(() {
        _loadFailed = false;
        _resource = resource;
        _definition = definition;
        _controller = controller;
        _driver = driver;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _resizePetWindow() async {
    try {
      await const OverlayWindow().resize(width: _petSize, height: _petSize);
    } catch (_) {
      // resize 失敗時仍保留初始視窗，避免畫面完全消失。
    }
  }

  /// 餓度要能跨重開：變動時節流落盤（最多延後 _hungerSaveInterval）
  void _watchHunger(PetController controller) {
    controller.stats.addListener(() {
      final now = DateTime.now();
      if (now.difference(_lastHungerSave) < _hungerSaveInterval) return;
      _flushHunger(controller);
    });
  }

  void _flushHunger(PetController controller) {
    _lastHungerSave = DateTime.now();
    final hunger = controller.stats.hunger;
    unawaited(_writeHungerQuietly(hunger));
  }

  Future<void> _writeHungerQuietly(double hunger) async {
    try {
      await _settingsRepository.saveHunger(hunger);
    } catch (_) {
      // 同上：存不進去只是下次重開餓度回到舊值，不能影響執行期。
    }
  }

  Future<AnimalResource?> _resolveResource(String animalId) async {
    final builtInResource = _builtInResource(animalId);
    if (builtInResource != null) return builtInResource;

    return _repository.getById(animalId);
  }

  AnimalResource? _builtInResource(String animalId) {
    final displayName = switch (animalId) {
      'cat' => '小花貓',
      'dog' => '小柴犬',
      _ => null,
    };
    if (displayName == null) return null;

    return AnimalResource(
      animalId: animalId,
      displayName: displayName,
      localFolderPath: '',
      version: '1.0.0',
      isDownloaded: false,
      isBuiltIn: true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> _openMenu() async {
    _driver?.setEnabled(false);
    await const OverlayWindow().resize(width: _menuWidth, height: _menuHeight);
    setState(() => _state = _WindowState.menu);
  }

  Future<void> _closeMenu() async {
    await const OverlayWindow().resize(width: _petSize, height: _petSize);
    _driver?.setEnabled(true);
    setState(() => _state = _WindowState.collapsed);
  }

  Future<void> _feed() async {
    final controller = _controller;
    if (controller != null) {
      // 食物擲在牠旁邊 → goToFood → 走過去 → eat 動畫 → 飽食
      controller.feedAt(
        Offset(controller.position.dx + _feedDropDistance, controller.position.dy),
      );
      _flushHunger(controller);
    }
    await _closeMenu();
  }

  Future<void> _petAction() async {
    final controller = _controller;
    controller?.pet();
    if (controller != null) _flushHunger(controller);
    await _closeMenu();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale, // 套用使用者語系
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(
        color: Colors.transparent,
        child: Builder(builder: _buildContent),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final resource = _resource;
    final definition = _definition;
    final controller = _controller;
    if (resource == null || definition == null || controller == null) {
      return _buildFallbackPet();
    }

    final l10n = AppLocalizations.of(context)!;

    if (_state == _WindowState.menu) {
      return _buildMenu(l10n, resource, definition, controller);
    }
    return _buildPet(resource, definition, controller);
  }

  Widget _buildFallbackPet() {
    return GestureDetector(
      onTap: _openMenu,
      child: Center(
        child: SizedBox(
          width: _petSize,
          height: _petSize,
          child: CustomPaint(
            painter: _OverlayFallbackPainter(failed: _loadFailed),
          ),
        ),
      ),
    );
  }

  Widget _buildPet(
    AnimalResource resource,
    AnimalAnimationDefinition definition,
    PetController controller,
  ) {
    return GestureDetector(
      onTap: _openMenu,
      // 自己處理拖曳（showOverlay 的 enableDrag 已關）：拖完位置還在 PetController 手上，
      // 而且會被 zone 夾住，拖不進禁区。
      onPanDown: (_) => controller.beginDrag(),
      onPanUpdate: (d) => controller.dragTo(controller.position + d.delta),
      onPanEnd: (_) => controller.endDrag(),
      onPanCancel: () => controller.endDrag(),
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => AnimalAnimator(
            resource: resource,
            definition: definition,
            action: controller.action,
            loader: _loader,
            displayWidth: _petSize,
            displayHeight: _petSize,
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(
    AppLocalizations l10n,
    AnimalResource resource,
    AnimalAnimationDefinition definition,
    PetController controller,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: _petSize,
          height: _petSize,
          child: AnimalAnimator(
            resource: resource,
            definition: definition,
            action: AnimationAction.affectionate,
            loader: _loader,
            displayWidth: _petSize,
            displayHeight: _petSize,
          ),
        ),
        const SizedBox(height: 8),
        FeedingMenu(
          feedLabel: l10n.menuFeed,
          petLabel: l10n.menuPet,
          closeLabel: l10n.menuClose,
          onFeed: _feed,
          onPet: _petAction,
          onClose: _closeMenu,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _driver?.dispose();
    _controller?.dispose();
    super.dispose();
  }
}

class _OverlayFallbackPainter extends CustomPainter {
  final bool failed;

  const _OverlayFallbackPainter({required this.failed});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 32;
    final body = Paint()..color = failed ? const Color(0xFFD08770) : const Color(0xFF88C0D0);
    final shade = Paint()..color = const Color(0xFF2E3440);
    final eye = Paint()..color = const Color(0xFFECEFF4);
    final accent = Paint()..color = const Color(0xFFEBCB8B);

    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(
          x * scale,
          y * scale,
          w * scale,
          h * scale,
        );

    canvas.drawRect(r(7, 11, 18, 13), body);
    canvas.drawRect(r(10, 7, 12, 8), body);
    canvas.drawRect(r(8, 5, 4, 5), body);
    canvas.drawRect(r(20, 5, 4, 5), body);
    canvas.drawRect(r(24, 15, 5, 4), shade);
    canvas.drawRect(r(6, 23, 5, 3), shade);
    canvas.drawRect(r(21, 23, 5, 3), shade);
    canvas.drawRect(r(13, 11, 2, 2), eye);
    canvas.drawRect(r(19, 11, 2, 2), eye);
    canvas.drawRect(r(16, 14, 2, 1), accent);

    if (failed) {
      canvas.drawRect(r(10, 27, 12, 2), accent);
    }
  }

  @override
  bool shouldRepaint(_OverlayFallbackPainter oldDelegate) => oldDelegate.failed != failed;
}
