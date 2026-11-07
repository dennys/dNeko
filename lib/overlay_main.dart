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
  double get _menuHeight => _settings.petSize + 232;

  /// 餵食時食物擲在牠旁邊多遠
  static const double _feedDropDistance = 120;

  /// 飢餓值落盤的節流間隔
  static const Duration _hungerSaveInterval = Duration(seconds: 60);

  final _repository = AnimalRepository();
  final _settingsRepository = SettingsRepository();
  final _loader = AnimationLoader();

  PetController? _controller;
  OverlayPetDriver? _driver;
  PetStats? _stats;
  StreamSubscription<dynamic>? _eventSub;

  /// 載入請求的顺序號。主 isolate 送 payload 過來時是 fire-and-forget，而這裡的
  /// handler 中間有好幾個 await；連續「啟動→停止→啟動」或兩份 payload 擠在一起時，
  /// 先到的那份會在後到的之後才醒過來，把舊動物蓋回去、還留下一個 timer 一直在跑的
  /// PetController（`if (!mounted) return` 拦不住兩個都還活著的情況）。
  /// 只有最後進入的那次載入可以寫入狀態。
  int _loadSeq = 0;
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

  /// 原生拖曳追蹤：onPanDown 後開始輪詢視窗座標，位置有變才視為拖曳
  Timer? _dragTimer;
  bool _dragging = false;
  bool _polling = false;
  int _polls = 0;
  int _idlePolls = 0;
  Offset? _lastWin;

  static const _pollInterval = Duration(milliseconds: 50);
  static const _maxIdlePolls = 8; // 400 ms 不動 = 放手（或單純點擊）
  static const _maxPreDragPolls = 8; // 400 ms 內沒開始移動 = 只是點擊，停止追蹤

  void _startDragWatch(PetController controller) {
    if (_dragTimer != null) return;
    _dragging = false;
    _polls = 0;
    _idlePolls = 0;
    _lastWin = null;
    _dragTimer = Timer.periodic(_pollInterval, (_) => unawaited(_pollDrag(controller)));
  }

  Future<void> _pollDrag(PetController controller) async {
    if (_polling) return;
    _polling = true;
    try {
      final p = await const OverlayWindow().currentPosition();
      if (!_dragging) {
        _polls++;
        if ((p - controller.position).distance < 2) {
          if (_polls >= _maxPreDragPolls) _stopDragWatch(controller);
          return;
        }
        _dragging = true;
        _driver?.setEnabled(false); // 暫停 driver，避免把舊座標推回視窗
        controller.beginDrag();
      }
      if (p == _lastWin) {
        if (++_idlePolls >= _maxIdlePolls) _stopDragWatch(controller);
        return;
      }
      _idlePolls = 0;
      _lastWin = p;
      controller.syncFromWindow(p);
    } catch (_) {
      _stopDragWatch(controller);
    } finally {
      _polling = false;
    }
  }

  void _stopDragWatch(PetController controller) {
    _dragTimer?.cancel();
    _dragTimer = null;
    if (_dragging) {
      _dragging = false;
      _driver?.setEnabled(true);
      controller.endDrag();
    }
  }

  @override
  void initState() {
    super.initState();
    // 這條訂閱之前沒有人 cancel（也不存成欄位），overlay isolate 结束前就一直吊著
    // state 與整條控制器鏈。
    _eventSub = FlutterOverlayWindow.overlayListener.listen(_onData);
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
    // payload 少了 metrics 時不能把整個 handler 炸掉（這是 stream callback，例外會變成
    // unhandled error，寵物就卡在原來的位置）；沿用舊的範圍就好。
    final rawMetrics = map['metrics'];
    if (rawMetrics is Map) {
      _metrics = ScreenMetrics.fromJson(Map<String, dynamic>.from(rawMetrics));
    }
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
    final seq = ++_loadSeq;
    // 中途被更新的載入請求超過：這裡已經 await 過好几次，絕對不能再寫狀態；
    // 之前 dispose 舊控制器是在 await 之前做的，兩重載疊在一起時會留下一個
    // 沒人接手、但 timer 仍在跑的 PetController。
    bool stale() => seq != _loadSeq;

    try {
      final resource = await _resolveResource(animalId);
      if (stale()) return;
      if (resource == null) {
        if (mounted) setState(() => _loadFailed = true);
        return;
      }
      final definition = await _loader.load(resource);
      if (stale()) return;
      if (!mounted) return;

      final bounds = metrics.zoneBounds(_settings.petSize, _settings.zone);
      const window = OverlayWindow();

      await _resizePetWindow();
      if (stale()) return;

      final saved = await _readOr(() => _settingsRepository.loadHunger(), null);
      // 懸浮沒開的時候沒有 tick，但時間還在走：依「距上次存盤多久」補算餓度，
      // 否則關掉 app 三天再打開，寵物還是三天前那個飽飽的樣子。
      final hunger = saved == null
          ? 0.0
          : PetStats.hungerAfterAbsence(saved.hunger, DateTime.now().difference(saved.savedAt));
      // 最後一道閘：過了這行就一定會把新控制器掛上去，不能再被舊請求搶先。
      if (stale() || !mounted) return;

      // 舊的這一套要等新的一整套備妥了才關：先關再 await 的話，一旦這次載入失敗
      // 或被作廢，畫面就卡在那個已經 dispose 的舊 controller 上（拖不動也不會動）。
      _driver?.dispose();
      _controller?.dispose();
      _stats?.dispose(); // 上層自己 new 的 stats，注入給 controller 所以它不會替我們關

      final stats = PetStats(initialHunger: hunger);
      final controller = _controllerFactory.create(
        bounds: bounds,
        definition: definition,
        speedPerTick: _settings.speedPerTick,
        stats: stats,
      )..start();
      final driver = OverlayPetDriver(controller, window);
      _watchHunger(controller);

      setState(() {
        _loadFailed = false;
        _stats = stats;
        _resource = resource;
        _definition = definition;
        _controller = controller;
        _driver = driver;
      });
    } catch (_) {
      if (stale()) return;
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
    // 順序很重要：先問 DB，讓「下載過/改過」的那份資料贏過過時的內建定義
    // （之前是內建優先，等於 cat/dog 永遠無視 DB 裡的記錄）。DB 沒有這一列（使用者刪掉了）
    // 才退回內建 —— 素材是隨 app 打包的，不該因為一列被刪就整個變成佔位圓。
    final stored = await _repository.getById(animalId);
    return stored ?? AnimalRepository.builtIn(animalId);
  }

  Future<void> _openMenu() async {
    _driver?.setEnabled(false);
    await const OverlayWindow().resize(width: _menuWidth, height: _menuHeight, enableDrag: false);
    setState(() => _state = _WindowState.menu);
  }

  Future<void> _closeMenu() async {
    await const OverlayWindow().resize(width: _petSize, height: _petSize);
    _driver?.setEnabled(true);
    setState(() => _state = _WindowState.collapsed);
  }

  /// 餵食：不开关选单，供双击直接呼叫
  void _feedNow() {
    final controller = _controller;
    if (controller == null) return;
    controller.feedAt(
      Offset(controller.position.dx + _feedDropDistance, controller.position.dy),
    );
    _flushHunger(controller);
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
    _petNow();
    await _closeMenu();
  }

  /// 撫摸：不开关选单，供单击直接呼叫
  void _petNow() {
    final controller = _controller;
    if (controller == null) return;
    controller.pet();
    _flushHunger(controller);
  }

  Future<void> _freezeAction() async {
    final controller = _controller;
    controller?.setFrozen(!(controller.frozen));
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

  /// 載入失敗（或還載入中）時的佔位畫面。
  ///
  /// 這裡不能走 `_openMenu`：`_buildContent` 在 resource/definition/controller 任一為 null 時
  /// 一律回傳這個佔位畫面，所以「開選單」只會把視窗放大到選單尺寸、內容卻還是那顆圓，
  /// 而 `_closeMenu` 再也叫不回來 —— 使用者卡在那個大視窗上，而且（沒有控制器）也拖不動。
  /// 佔位狀態唯一有意義的動作是重試；真的要收掉寵物，是在主頁把懸浮關掉。
  Widget _buildFallbackPet() {
    return GestureDetector(
      onTap: () => unawaited(_loadAnimal(_resource?.animalId ?? defaultAnimalId, _metrics)),
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
      onTap: _petNow, // 短按 = 撫摸
      onDoubleTap: _feedNow, // 雙擊 = 餵食
      onLongPress: _openMenu, // 長按 = 開選單
      // 自己處理拖曳（showOverlay 的 enableDrag 已關）：拖完位置還在 PetController 手上，
      // 而且會被 zone 夾住，拖不進禁区。
      onPanDown: (_) => _startDragWatch(controller),
      // 原生拖曳開始時插件會取消 Flutter 的手勢，不能在這裡結束拖曳（由輪詢判定）
      onPanCancel: () {},
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
          freezeLabel: controller.frozen ? l10n.menuUnfreeze : l10n.menuFreeze,
          onFeed: _feed,
          onPet: _petAction,
          onFreeze: _freezeAction,
          onClose: _closeMenu,
        ),
      ],
    );
  }

  @override
  void dispose() {
    unawaited(_eventSub?.cancel());
    _eventSub = null;
    _loadSeq++; // 讓還在飛的載入流程全部作廢（它們回來時只會看到過期的顺序號）
    _dragTimer?.cancel();
    _driver?.dispose();
    _controller?.dispose();
    _stats?.dispose();
    _stats = null;
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
