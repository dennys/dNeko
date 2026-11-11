import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'l10n/app_localizations.dart';
import 'data/repositories/animal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/animation_loader.dart';
import 'data/services/animal_sound.dart';
import 'data/services/overlay_window.dart';
import 'data/models/animal_resource.dart';
import 'data/models/animation_definition.dart';
import 'data/models/animation_action.dart';
import 'domain/drag_watch.dart';
import 'domain/pet_bond.dart';
import 'domain/pet_settings.dart';
import 'domain/locale_code.dart';
import 'domain/menu_placement.dart';
import 'domain/position_throttle.dart';
import 'domain/pet_stats.dart';
import 'domain/screen_metrics.dart';
import 'presentation/controllers/pet_controller.dart';
import 'presentation/controllers/pet_controller_factory.dart';
import 'presentation/controllers/overlay_pet_driver.dart';
import 'presentation/widgets/animal_animator.dart';
import 'presentation/widgets/feeding_menu.dart';
import 'presentation/widgets/hunger_bar.dart';
import 'utils/log.dart';

void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  // 與主 app 同一套：logcat 是唯一支持管道。zone 抓 async 例外，
  // FlutterError.onError 抓 framework/render 例外（它們走 reportError，不會 rethrow 進 zone）。
  FlutterError.onError = (details) => appError('overlay framework 例外', details.exception, details.stack);
  runZonedGuarded(
    () => runApp(const _OverlayApp()),
    (e, st) => appError('overlay 未捕获例外', e, st),
  );
}

enum _WindowState { collapsed, menu }

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  static const _controllerFactory = PetControllerFactory();

  /// 選單寬度至少要裝得下選單列，否則跟寵物同寬
  double get _menuWidth => math.max(_petSize, FeedingMenu.contentWidth);

  /// 寵物 + 間距 + 餓度列 + 選單 + 底部留白
  static const double _hungerBarBlock = 20 + 8;

  double get _menuHeight =>
      _petSize + 8 + _hungerBarBlock + FeedingMenu.contentHeight + 8;

  /// 飢餓值落盤的節流間隔
  static const Duration _hungerSaveInterval = Duration(seconds: 60);

  /// 位置寫盤的節流（判定本身是純邏輯，住在 [PositionThrottle]）
  final PositionThrottle _positionThrottle = PositionThrottle();

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

  /// 已經完整套過一次的 payload（去重用，見 `_onData`）
  String? _lastAppliedPayload;
  // 寵物與選單共用同一個動畫元件（GlobalKey 讓狀態跨切換保留，避免開關選單時重載幀）
  final _animatorKey = GlobalKey();
  // 收過主 app 的 payload 就不再讓預設值（讀 DB）覆蓋設定
  bool _hasPayload = false;
  AnimalAnimationDefinition? _definition;
  PetSettings _settings = const PetSettings();
  ScreenMetrics _metrics = const ScreenMetrics(
    logicalSize: Size(360, 720),
    devicePixelRatio: 1,
  );
  double _petSize = PetSettings.defaultPetSize;
  _WindowState _state = _WindowState.collapsed;

  /// 選單開著一段時間沒動就自己關掉（overlay 視窗收不到視窗外的點擊，
  /// 懸浮視窗也沒有「點外面」這種事件，定時器是唯一能自動脫身的办法）
  Timer? _menuTimer;
  static const _menuTimeout = Duration(seconds: 6);

  /// 實測出的視窗頂端座標可達範圍（含狀態列/導航列的安全區；見 [_measureRoam]）
  Rect? _roam;
  double? _roamPetSize;

  /// [_roam] 是不是實測值（false = fallback 頂著，下次一定要重新量）。
  /// fallback 不能當校準結果快取：選單開著時 _applySettings 會設 fallback，
  /// 若關選單不清掉，下次開選單的擺位就吃未校準值（A-4b 的 bug 換個形式回來）。
  bool _roamCalibrated = false;

  /// 選單開在寵物上方（下方空間不夠時），決定 [_buildMenu] 的擺法
  bool _menuAbove = false;
  Locale _locale = const Locale('en'); // overlay 自己的語系
  bool _loadFailed = false;
  DateTime _lastHungerSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// 原生拖曳追蹤：onPanDown 後開始輪詢視窗座標；判定本身是純邏輯，住在 [DragWatch]
  Timer? _dragTimer;
  DragWatch? _dragWatch;
  bool _polling = false;

  final ISoundPlayer _sound = AudioPlayerSoundPlayer();

  static const _pollInterval = Duration(milliseconds: 50);

  /// 走動的寵物會被 driver 搬著視窗跑，視窗與 controller 位置之間還有通道延遲，
  /// 門檻要蓋得過這段落差，真拖曳則很快就會超過。
  static const _dragThresholdPx = 16.0;

  void _startDragWatch(PetController controller) {
    if (_dragTimer != null) return;
    _dragWatch = DragWatch(moveThresholdPx: _dragThresholdPx);
    _dragTimer = Timer.periodic(_pollInterval, (_) => unawaited(_pollDrag(controller)));
  }

  Future<void> _pollDrag(PetController controller) async {
    if (_polling) return;
    _polling = true;
    try {
      final p = await const OverlayWindow().currentPosition();
      // await 期間 controller 可能被換掉或 dispose（換動物 / overlay 關閉）；
      // 碰已 dispose 的 ChangeNotifier 會觸發 debug 斷言
      final watch = _dragWatch;
      if (!mounted || watch == null || !identical(controller, _controller)) return;
      switch (watch.step(p, expected: controller.position)) {
        case DragStep.keepWaiting:
          break;
        case DragStep.startDrag:
          _driver?.setEnabled(false); // 暫停 driver，避免把舊座標推回視窗
          controller.beginDrag();
          controller.syncFromWindow(p);
        case DragStep.dragging:
          controller.syncFromWindow(p);
        case DragStep.stop:
          _stopDragWatch(controller);
      }
    } catch (_) {
      if (mounted && identical(controller, _controller)) _stopDragWatch(controller);
    } finally {
      _polling = false;
    }
  }

  void _stopDragWatch(PetController controller) {
    final wasDragging = _dragWatch?.dragging ?? false;
    _dragTimer?.cancel();
    _dragTimer = null;
    _dragWatch = null;
    if (wasDragging) {
      _driver?.setEnabled(true);
      controller.endDrag();
    }
  }

  /// 點擊 / 餵食 / 開選單會由 app 自己搬視窗；那段移動不是使用者拖曳，
  /// 若 onPanDown 留下的監看還在，會被誤判成拖曳而蓋掉 goToFood 目標。
  /// 真的在拖曳中就不動它。
  void _cancelIdleDragWatch(PetController controller) {
    if (_dragWatch?.dragging ?? false) return;
    _stopDragWatch(controller);
  }

  /// 本地 fork（packages/flutter_overlay_window）在視窗被點到外面時從原生打進來的 channel
  /// （插件原生端的 OVERLAY_TAG；原版這名字只用在 Dart→原生方向，不會跟我們搶 handler）
  static const _nativeChannel = MethodChannel('x-slayer/overlay');

  @override
  void initState() {
    super.initState();
    // 這條訂閱之前沒有人 cancel（也不存成欄位），overlay isolate 结束前就一直吊著
    // state 與整條控制器鏈。
    _eventSub = FlutterOverlayWindow.overlayListener.listen(_onData);
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOutsideTap' && _state == _WindowState.menu) {
        await _closeMenu();
      }
    });
    unawaited(_loadDefaultAnimal());
  }

  Future<void> _loadDefaultAnimal() async {
    final saved = await _readOr(() => _settingsRepository.load(), const PetSettings());
    // 主 app 的 payload 先到就以它為準：讀回來的舊值（或讀取失敗的預設 120）不能蓋掉它，
    // 否则寵物尺寸會被重設成預設值
    if (!mounted || _hasPayload || _resource != null) return;
    _settings = saved;
    await _loadAnimal(_settings.animalId);
  }

  /// overlay 是獨立 isolate，sqflite 在裡頭不一定可用：讀不到就用預設，
  /// 绝不能因為設定/餓度拉不到就让寵物消失。
  Future<T> _readOr<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (e, st) {
      // 吞掉異常是對的（不能讓寵物因為讀不到設定就消失），但不能吞到無跡可尋：
      // 「DB 異常」與「真的沒存過」在外面的表現一模一樣，餓度會不會被憑空餵飽就靠這行分。
      appError('overlay 讀取失敗，改用預設值', e, st);
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
    _hasPayload = true;

    // 同一份 payload 重複送是 `_shareStartupData` 的延遲重送（視窗可能還沒訂閱），
    // 不是設定改了：每收一次就跑一趟 `_applySettings`（含 resize、必要時重校準），
    // 寵物剛出現時會看得見地抖一下。套過的就直接丟。
    //
    // 例外：close→restart 時 engine 是 cached 的（Dart state 全保留），showOverlay 會
    // 重建視窗但 Flutter view 不一定跟著 resize，動物會停在舊尺寸（size slider 大、
    // 動物小）。所以重複 payload 也要補跑一次 `_resizePetWindow` 把視窗尺寸對齊。
    if (data == _lastAppliedPayload) {
      await _resizePetWindow();
      return;
    }

    final rawSettings = map['settings'];
    if (rawSettings is Map) {
      _settings = PetSettings.fromJson(Map<String, dynamic>.from(rawSettings));
    }
    final languageCode = map['languageCode'] as String? ?? 'en';
    // payload 少了 metrics 時不能把整個 handler 炸掉（這是 stream callback，例外會變成
    // unhandled error，寵物就卡在原來的位置）；沿用舊的範圍就好。
    final rawMetrics = map['metrics'];
    if (rawMetrics is Map) {
      final metrics = ScreenMetrics.fromJson(Map<String, dynamic>.from(rawMetrics));
      // 轉屏（或切手機/平板）後可用範圍整個翻轉，舊校準值必須作廢重量
      if (metrics.logicalSize != _metrics.logicalSize ||
          metrics.devicePixelRatio != _metrics.devicePixelRatio) {
        _roam = null;
        _roamCalibrated = false;
      }
      _metrics = metrics;
    }
    setState(() => _locale = localeOfCode(languageCode));

    // 同一隻寵物 → 只把新設定套上去，不重載（重載會把位置與行為清零，很突兀）
    final controller = _controller;
    if (controller != null && animalId == _resource?.animalId) {
      await _applySettings();
      _lastAppliedPayload = data;
      return;
    }
    await _loadAnimal(animalId);
    _lastAppliedPayload = data;
  }

  /// 設定頁改動後即時生效：速度、可漫遊範圍、視窗尺寸
  Future<void> _applySettings() async {
    final controller = _controller;
    final sizeChanged = _petSize != _settings.petSize;
    setState(() => _petSize = _settings.petSize);
    if (_state == _WindowState.collapsed) {
      await _resizePetWindow();
      // 校準结果跟視窗邊長綁在一起，尺寸換了要重量
      if (sizeChanged) _roam = null;
    } else if (sizeChanged) {
      // 選單開著，視窗目前是選單尺寸，量了也不是寵物的可用範圍，先用回退值頂著
      _roam = _metrics.fallbackRoam(_settings.petSize);
      _roamPetSize = _settings.petSize;
      _roamCalibrated = false;
    }
    if (controller == null) return;
    final bounds = zoneBounds(
      await _roamFor(_settings.petSize, anchor: controller.position),
      _settings.petSize,
      _settings.zone,
    );
    // await 期間 `_loadAnimal` 可能已經把 controller 換掉並 dispose 了（cascade 只在開頭
    // 讀一次欄位，之後都打在那個死掉的物件上）。本檔其他處都用 stale() 防這類競態，
    // 這裡用同一個手法：同一個實例才准套設定。
    if (!identical(controller, _controller)) return;
    controller
      ..setSpeedPerTick(_settings.speedPerTick)
      ..updateBounds(bounds)
      ..stats.setHungryThreshold(
        PetStats.hungryThresholdForMinutes(_settings.hungerMinutesUntilHungry),
      );
  }

  /// 視窗在尺寸 [petSize] 下真正可到達的頂端座標範圍。
  ///
  /// 原生 WindowManager 會把視窗夾進它自己的安全區（狀態列以下、導航列以上，
  /// 換算用真實 px），主 app MediaQuery 算出來的 Rect 跟它常對不上（限定下方時
  /// 實際底部多一條空、頂部貼不上去就是这个原因）。所以直接搬到極端再讀回來：
  /// 插件回傳的永远是被 clamp 後的實際位置，量出來的一定是真實可用的範圍。
  /// 只在尺寸改變後量一次，之後都吃快取。
  Future<Rect> _roamFor(double petSize, {Offset? anchor}) async {
    final cached = _roam;
    if (cached != null && _roamPetSize == petSize && _roamCalibrated) return cached;
    const window = OverlayWindow();
    try {
      await window.moveTo(Offset.zero);
      final min = await window.currentPosition();
      await window.moveTo(const Offset(100000, 100000));
      final max = await window.currentPosition();
      if (max.dx <= min.dx || max.dy <= min.dy) throw Exception('校準失敗: $min ~ $max');
      final rect = Rect.fromLTRB(min.dx, min.dy, max.dx, max.dy);
      // 校準期間視窗被搬去角落，量完立刻搬回來，不要讓寵物停在螢幕角上。
      // 首次載入時 controller 還不存在，一定要由呼叫端把錨點傳進來（REVIEW #1）。
      final back = anchor ?? _controller?.position;
      if (back != null) await window.moveTo(back);
      _roam = rect;
      _roamPetSize = petSize;
      _roamCalibrated = true;
      return rect;
    } catch (_) {
      final fallback = _metrics.fallbackRoam(petSize);
      _roam = fallback;
      _roamPetSize = petSize;
      _roamCalibrated = false; // 校準失敗：fallback 不能當實測值快取，下次再量
      return fallback;
    }
  }

  Future<void> _loadAnimal(String animalId) async {
    final seq = ++_loadSeq;
    // 中途被更新的載入請求超過：這裡已經 await 過好几次，絕對不能再寫狀態；
    // 之前 dispose 舊控制器是在 await 之前做的，兩重載疊在一起時會留下一個
    // 沒人接手、但 timer 仍在跑的 PetController。
    bool stale() => seq != _loadSeq;

    try {
      final resource = await _repository.resolveResource(animalId);
      if (stale()) return;
      if (resource == null) {
        if (mounted) setState(() => _loadFailed = true);
        return;
      }
      final definition = await _loader.load(resource);
      if (stale()) return;
      if (!mounted) return;

      const window = OverlayWindow();

      // 先對齊尺寸再 resize/校準，否則視窗尺寸跟 PetController 吃的 petSize 會錯開
      setState(() => _petSize = _settings.petSize);
      await _resizePetWindow();
      if (stale()) return;

      // 寵物這一刻在哪裡，只有視窗自己知道：主 app 的 startPosition 已把上次存的位置還原
      // 到視窗上，但 PetController 沒讀它，第一次 tick 就從 bounds.center 開始 —— 所以
      // 「記位置」長年整個是假的（REVIEW #1）。校準會把視窗搬到兩個角落，因此必須在
      // [_roamFor] 之前讀；讀不到就退回原本的中央預設。
      final windowPosition = await _readWindowPosition();
      if (stale()) return;
      final bounds = zoneBounds(
        await _roamFor(_settings.petSize, anchor: windowPosition),
        _settings.petSize,
        _settings.zone,
      );
      if (stale()) return;

      final saved = await _readOr(() => _settingsRepository.loadHunger(), null);
      // 親讀不到就從 0 開始（人類的決定：不管舊安裝）；讀到就用存的那份（含今天的計分額度）
      final bond = await _readOr(() => _settingsRepository.loadBond(animalId), const PetBond());
      // 懸浮沒開的時候沒有 tick，但時間還在走：依「距上次存盤多久」補算餓度，
      // 否則關掉 app 三天再打開，寵物還是三天前那個飽飽的樣子。
      final hunger = saved == null
          ? 0.0
          : PetStats.hungerAfterAbsence(saved.hunger, DateTime.now().difference(saved.savedAt));
      // 最後一道閘：過了這行就一定會把新控制器掛上去，不能再被舊請求搶先。
      if (stale() || !mounted) return;

      // 舊的這一套要等新的一整套備妥了才關：先關再 await 的話，一旦這次載入失敗
      // 或被作廢，畫面就卡在那個已經 dispose 的舊 controller 上（拖不動也不會動）。
      // 換動物時保留定格與位置（A-9a）：抓下來再 dispose，掛到新 controller 上。
      // 拖曳輪詢也要先停：finger 還按在寵物上時換動物，timer 會繼續對已 dispose 的
      // controller 呼叫 beginDrag/syncFromWindow（debug 斷言；release 則新 driver 已
      // 啟用、tick 跟手勢打架，寵物抖動）。
      final oldController = _controller;
      if (oldController != null) _stopDragWatch(oldController);
      final oldFrozen = oldController?.frozen ?? false;
      final oldPosition = oldController?.position ?? windowPosition;
      _driver?.dispose();
      oldController?.dispose();
      _stats?.dispose(); // 上層自己 new 的 stats，注入給 controller 所以它不會替我們關

      final stats = PetStats(
        initialHunger: hunger,
        initialBond: bond,
        hungryThreshold: PetStats.hungryThresholdForMinutes(_settings.hungerMinutesUntilHungry),
      );
      final controller = _controllerFactory.create(
        bounds: bounds,
        definition: definition,
        speedPerTick: _settings.speedPerTick,
        stats: stats,
        position: oldPosition,
        frozen: oldFrozen,
      )..start();
      final driver = OverlayPetDriver(controller, window);
      // 吃進去的計分點在 controller 抵達食物那一刻（不是丟食物那一刻），所以掛回調在這裡。
      // 只有懸浮掛 —— 預覽塊不掛，app 裡餵食不該養出親密度。
      controller.onFed = () {
        if (controller.stats.awardFeed(DateTime.now())) {
          unawaited(_saveBond(animalId, controller));
        }
      };
      _watchPet(controller);

      // 載入把狀態壓回 collapsed，選單定時器也要一起關：否則它會在 6 秒後醒過來，
      // 對新的 controller 跑一趟多餘的 moveAndResize（狀態與畫面就不一致了）。
      _menuTimer?.cancel();
      _menuTimer = null;

      setState(() {
        _loadFailed = false;
        // 載入把視窗縮回寵物尺寸了，選單開著也會被壓扁 —— 狀態要跟著回collapsed，
        // 否則之後按誰都叫不回 _closeMenu
        _state = _WindowState.collapsed;
        _stats = stats;
        _resource = resource;
        _definition = definition;
        _controller = controller;
        _driver = driver;
      });

      // 校準把視窗搬去兩個角落過，用夾進 zone 後的實際位置對齊一次。不能交給 driver：
      // 它只在 notify 時才搬，而「位置沒變」是不會 notify 的，視窗就會停在角落。
      await _moveWindowQuietly(controller.position);
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

  /// 讀視窗實際左上角；讀不到回 null，讓呼叫端決定退到哪裡（不能讓寵物因為讀不到座標就消失）
  Future<Offset?> _readWindowPosition() async {
    try {
      return await const OverlayWindow().currentPosition();
    } catch (e, st) {
      appError('讀視窗位置失敗，寵物改用預設的畫面中央', e, st);
      return null;
    }
  }

  Future<void> _moveWindowQuietly(Offset p) async {
    try {
      await const OverlayWindow().moveTo(p);
    } catch (_) {
      // 對齊失敗不影響執行期：下一次位置變動 driver 會再搬一次
    }
  }

  /// 餓度要能跨重開：變動時節流落盤（最多延後 _hungerSaveInterval）
  ///
  /// 另外即時 push 給主 app（不節流）：stats notify 頻率本就低（1 點粒度＝最多
  /// 1 次/分鐘＋餵食＋跨門檻），主頁那行才能即時跟上，不用等 60s 落盤＋20s 輪詢。
  void _watchPet(PetController controller) {
    controller.stats.addListener(() {
      _pushHunger(controller.stats.hunger);
      final now = DateTime.now();
      if (now.difference(_lastHungerSave) < _hungerSaveInterval) return;
      _flushHunger(controller);
    });
    // 位置由 overlay 存：只有這邊知道寵物在哪，主 app 只看得見視窗左上角（選單開著時那是
    // 選單的位置，比寵物高一大截）。而且不能只在「關閉那一刻」存 —— overlay 被主 app 直接
    // 關掉時這個 isolate 說沒就沒，dispose 裡的存盤未必趕得上，所以走動時就節流留檔。
    controller.addListener(() => unawaited(_rememberPosition(controller.position)));
  }

  /// 存寵物位置（節流）。[force] 給「收選單」與「結束」這種確定要留檔的時刻。
  Future<void> _rememberPosition(Offset p, {bool force = false}) async {
    final now = DateTime.now();
    if (!force && !_positionThrottle.shouldSave(p, now)) return;
    _positionThrottle.didSave(p, now);
    await _writeWithRetry(
      'overlay 位置存盤失敗（下次開懸浮會回到舊位置）',
      () => _settingsRepository.savePosition(p),
    );
  }

  /// 餓度即時推給主 app（fire-and-forget；主 app 沒活著時沒人收，不影響執行期）
  void _pushHunger(double hunger) {
    unawaited(
      FlutterOverlayWindow.shareData(jsonEncode({'cmd': 'hunger', 'value': hunger}))
          .catchError((_) {}),
    );
  }

  void _flushHunger(PetController controller) {
    _lastHungerSave = DateTime.now();
    final hunger = controller.stats.hunger;
    unawaited(_writeHungerQuietly(hunger));
  }

  Future<void> _writeHungerQuietly(double hunger) => _writeWithRetry(
        'overlay 餓度存盤失敗（下次重開會回到舊值）',
        () => _settingsRepository.saveHunger(hunger),
      );

  /// DB 寫入的共通防呆：主 app 與 overlay isolate 各開一條連線寫同一個 DB 檔，併發寫可能
  /// 撞 SQLITE_BUSY —— 重試一次；仍失敗就只記 log（存不進去只是下次重開回到舊值，
  /// 不能影響執行期）。
  Future<void> _writeWithRetry(String failure, Future<void> Function() write) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await write();
        return;
      } catch (e, st) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        appError(failure, e, st);
      }
    }
  }

  /// 開選單：動物不動，選單往空間比較多的方向長。
  ///
  /// 之前只把視窗放大、位置交給 WindowManager clamp —— 寵物貼著螢幕下方時整個視窗
  /// 被推上去，動物就「跳上去」讓位。現在自己算視窗左上角：下方夠就朝下長；
  /// 不夠就往上長（動物固定在視窗底部）；變寬的視窗也置中回動物原本的位置。
  Future<void> _openMenu() async {
    final controller = _controller;
    if (controller != null) _cancelIdleDragWatch(controller);
    _driver?.setEnabled(false);
    _controller?.setPaused(true);
    const window = OverlayWindow();
    // 先讀位置再校準：[_roamFor] 把視窗搬到角落過，事後讀到的就不是寵物待的地方了
    final pos = await window.currentPosition();
    final roam = await _roamFor(_petSize, anchor: pos);
    final placement = placeMenu(
      petPos: pos,
      roam: roam,
      petSize: _petSize,
      menuWidth: _menuWidth,
      menuHeight: _menuHeight,
    );
    _menuAbove = placement.above;

    await window.moveAndResize(
      position: placement.topLeft,
      width: _menuWidth,
      height: _menuHeight,
      enableDrag: false,
    );
    _armMenuTimer();
    setState(() => _state = _WindowState.menu);
  }

  void _armMenuTimer() {
    _menuTimer?.cancel();
    _menuTimer = Timer(_menuTimeout, () => unawaited(_closeMenu()));
  }

  Future<void> _closeMenu() async {
    _menuTimer?.cancel();
    _menuTimer = null;
    _controller?.setPaused(false);
    const window = OverlayWindow();
    // resize 以視窗左上角為錨點；選單開在上方時錨點不在動物身上，要搬回動物的位置。
    // 位置與尺寸同一次寫入，不先縮再搬
    final controller = _controller;
    if (controller != null) {
      await window.moveAndResize(
        position: controller.position,
        width: _petSize,
        height: _petSize,
        enableDrag: true,
      );
      // 選單開著時視窗左上角是選單的位置，主 app 那邊存到的從來就不是寵物 ——
      // 收選單是「寵物回到正常狀態」的時刻，在這裡把正確位置留檔。
      unawaited(_rememberPosition(controller.position, force: true));
    } else {
      await window.resize(width: _petSize, height: _petSize);
    }
    _driver?.setEnabled(true);
    // 選單開著時 _applySettings 可能把 _roam 設成 fallbackRoam（未校準）：
    // 未校準的才清掉（下次 _openMenu/_loadAnimal 重新量真實 roam 範圍，A-4b）；
    // 實測值保留 —— 重新量會把視窗搬到兩個角落，寵物看得見地瞬移。
    if (!_roamCalibrated) {
      _roam = null;
      _roamPetSize = null;
    }
    setState(() => _state = _WindowState.collapsed);
  }

  /// 餵食：不开关选单，供双击直接呼叫
  void _feedNow() {
    final controller = _controller;
    if (controller == null) return;
    _cancelIdleDragWatch(controller);
    controller.feedAt(
      Offset(controller.position.dx + feedDropDistance, controller.position.dy),
    );
    _flushHunger(controller);
  }

  Future<void> _feed() async {
    final controller = _controller;
    if (controller != null) {
      // 食物擲在牠旁邊 → goToFood → 走過去 → eat 動畫 → 飽食
      controller.feedAt(
        Offset(controller.position.dx + feedDropDistance, controller.position.dy),
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
    _cancelIdleDragWatch(controller);
    // 定格時 pet() 回 false（那一下根本沒反應）→ 不該計分，否則又是「做了沒反應卻偷偷漲」
    if (!controller.pet()) return;
    _playTouchSound();
    if (controller.stats.awardPet(DateTime.now())) {
      // _controller 與 _resource 在同一個 setState 裡一起換（見 _loadAnimal 尾端），
      // 所以這裡的 id 必然就是這個 controller 所屬那隻動物的 id。
      final id = _resource?.animalId;
      if (id != null) unawaited(_saveBond(id, controller));
    }
    _flushHunger(controller);
  }

  /// 撫摸叫聲：設定開著且這隻動物有音效才播
  void _playTouchSound() {
    if (!_settings.soundEnabled) return;
    final animalId = _resource?.animalId;
    final asset = animalId == null ? null : touchSoundFor(animalId);
    if (asset == null) return;
    unawaited(_sound.play(asset));
  }

  /// 親密度落盤。一天最多 +16 分（PetBond 的額度），寫盤頻率天生就低，不必節流。
  Future<void> _saveBond(String animalId, PetController controller) => _writeWithRetry(
        'overlay 親密度存盤失敗（下次重開會回到舊值）',
        () => _settingsRepository.saveBond(animalId, controller.stats.bond),
      );

  /// 結束整個程式：先存**寵物**位置（選單開著時視窗左上角是選單的位置，比寵物高約
  /// 200px，存視窗位置會讓下次啟動的寵物偏高被夾到螢幕頂），再知會主 app（還活著的話
  /// 它會連自己一起關掉），再關懸浮服務。主 app 已被使用者划掉時 shareData 沒人收，
  /// 但 closeOverlay 一樣把服務殺掉。
  Future<void> _quitApp() async {
    // 存位置一定要在送 quit 之前：主 app 一收到 quit 就關服務，存盤還在飛會被中斷
    try {
      final p = _controller?.position ??
          await const OverlayWindow().currentPosition().timeout(const Duration(milliseconds: 500));
      await _rememberPosition(p, force: true).timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    unawaited(FlutterOverlayWindow.shareData(jsonEncode({'cmd': 'quit'})).catchError((_) {}));
    try {
      await const OverlayWindow().close();
    } catch (_) {}
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
      // 選單是 Card/InkWell，要跟主 app 一樣支援深色模式
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      themeMode: switch (_settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
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
      onTap: () => unawaited(_loadAnimal(_resource?.animalId ?? defaultAnimalId)),
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
      // 拖曳是**原生**做的（showOverlay 的 enableDrag = true，插件用 rawX/rawY 把視窗拖走），
      // 這邊只在 onPanDown 起輪詢跟上去讀座標 —— 所以判定基準是視窗自己（見 [DragWatch]）。
      // 拖完位置還在 PetController 手上，而且會被 zone 夾住，拖不進禁區。
      onPanDown: (_) => _startDragWatch(controller),
      // 原生拖曳開始時插件會取消 Flutter 的手勢，不能在這裡結束拖曳（由輪詢判定）
      onPanCancel: () {},
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => AnimalAnimator(
            key: _animatorKey,
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
    final petView = GestureDetector(
      // 選單開著時按寵物 = 收起來（視窗外的點擊收不到，這是範圍內最接近「按外面關掉」的手勢）
      onTap: () => unawaited(_closeMenu()),
      child: SizedBox(
        width: _petSize,
        height: _petSize,
        child: AnimalAnimator(
          key: _animatorKey, // 與 _buildPet 共用：開/關選單時動畫狀態不重建，不會重載幀造成閃爍
          resource: resource,
          definition: definition,
          action: AnimationAction.affectionate,
          loader: _loader,
          displayWidth: _petSize,
          displayHeight: _petSize,
        ),
      ),
    );
    final menu = FeedingMenu(
      onInteract: _armMenuTimer, // 有動就重新計時
      feedLabel: l10n.menuFeed,
      petLabel: l10n.menuPet,
      closeLabel: l10n.menuClose,
      freezeLabel: controller.frozen ? l10n.menuUnfreeze : l10n.menuFreeze,
      quitLabel: l10n.menuQuit,
      onFeed: _feed,
      onPet: _petAction,
      onFreeze: _freezeAction,
      onClose: _closeMenu,
      onQuit: () => unawaited(_quitApp()),
    );
    const gap = SizedBox(height: 8);
    // 餓度列紧跟選單上方：開選單就是來看牠狀態的，还要另外開主頁就白做這個選單了
    // （而且在此之前 HungerBar 全專案零個使用者，餓度根本无处可看）。
    final hunger = SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // 親密度就掛在餓度旁：愛心 + 數字，不另開區塊、不新增字串（要加文字標籤時補 l10n key）
        child: Row(
          children: [
            Expanded(
              child: HungerBar(
                  hunger: controller.stats.hunger,
                  threshold: controller.stats.hungryThreshold),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.favorite, size: 13, color: Color(0xFFE91E63)),
            const SizedBox(width: 2),
            Text('${controller.stats.bondValue.round()}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
    // 錨定而不是置中：選單開在下面→動物貼視窗頂；開在上面→動物貼視窗底。
    // 開/關選單時動物都穩穩待在同一个位置。
    return Column(
      mainAxisAlignment: _menuAbove ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: _menuAbove
          ? [hunger, gap, menu, gap, petView]
          : [petView, gap, hunger, gap, menu],
    );
  }

  @override
  void dispose() {
    unawaited(_eventSub?.cancel());
    _eventSub = null;
    _menuTimer?.cancel();
    _loadSeq++; // 讓還在飛的載入流程全部作廢（它們回來時只會看到過期的顺序號）
    _dragTimer?.cancel();
    _driver?.dispose();
    _controller?.dispose();
    _stats?.dispose();
    _stats = null;
    unawaited(_sound.dispose());
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
