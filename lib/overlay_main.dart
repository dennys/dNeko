import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'l10n/app_localizations.dart';
import 'data/repositories/animal_repository.dart';
import 'data/services/animation_loader.dart';
import 'data/services/overlay_service.dart';
import 'data/services/overlay_window.dart';
import 'data/models/animal_resource.dart';
import 'data/models/animation_definition.dart';
import 'data/models/animation_action.dart';
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
  static const double _menuWidth = 180;
  static const double _menuHeight = 240;
  static const _controllerFactory = PetControllerFactory();

  final _repository = AnimalRepository();
  final _loader = AnimationLoader();

  PetController? _controller;
  OverlayPetDriver? _driver;
  AnimalResource? _resource;
  AnimalAnimationDefinition? _definition;
  double _petSize = OverlayService.collapsedSize;
  _WindowState _state = _WindowState.collapsed;
  Locale _locale = const Locale('en'); // overlay 自己的語系
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen(_onData);
    unawaited(_loadDefaultAnimal());
  }

  Future<void> _loadDefaultAnimal() async {
    const fallbackMetrics = ScreenMetrics(
      logicalSize: Size(360, 720),
      devicePixelRatio: 1,
    );
    await _loadAnimal('cat', fallbackMetrics);
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

    _petSize = (map['petSize'] as num?)?.toDouble() ?? _petSize;
    final languageCode = map['languageCode'] as String? ?? 'en';
    final metrics = ScreenMetrics.fromJson(
      map['metrics'] as Map<String, dynamic>,
    );
    setState(() => _locale = Locale(languageCode));
    await _loadAnimal(animalId, metrics);
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

      final bounds = metrics.roamingBounds(_petSize);
      const window = OverlayWindow();

      _driver?.dispose();
      _controller?.dispose();

      await _resizePetWindow();

      final controller = _controllerFactory.create(
        bounds: bounds,
        definition: definition,
      )..start();
      final driver = OverlayPetDriver(controller, window);

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
    _controller?.stats.feed();
    _controller?.pet();
    await _closeMenu();
  }

  Future<void> _petAction() async {
    _controller?.pet();
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
