import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

@pragma('vm:entry-point')
void overlayMain() {
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

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen(_onData);
  }

  Future<void> _onData(dynamic data) async {
    if (data is! String) return;
    final map = jsonDecode(data) as Map<String, dynamic>;

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
    final resource = await _repository.getById(animalId);
    if (resource == null) return;
    final definition = await _loader.load(resource);
    if (!mounted) return;

    final bounds = metrics.roamingBounds(_petSize);
    final window = OverlayWindow(metrics);

    _driver?.dispose();
    _controller?.dispose();

    final controller = _controllerFactory.create(
      bounds: bounds,
      definition: definition,
    )..start();
    final driver = OverlayPetDriver(controller, window);

    setState(() {
      _resource = resource;
      _definition = definition;
      _controller = controller;
      _driver = driver;
    });
  }

  Future<void> _openMenu() async {
    _driver?.setEnabled(false);
    await OverlayWindow(_currentMetrics())
        .resize(width: _menuWidth, height: _menuHeight);
    setState(() => _state = _WindowState.menu);
  }

  Future<void> _closeMenu() async {
    await OverlayWindow(_currentMetrics())
        .resize(width: _petSize, height: _petSize);
    _driver?.setEnabled(true);
    setState(() => _state = _WindowState.collapsed);
  }

  // 注意：resize 也需要 metrics 換算，這裡保留最近一次的 metrics
  ScreenMetrics _lastMetrics =
      const ScreenMetrics(logicalSize: Size.zero, devicePixelRatio: 1);
  ScreenMetrics _currentMetrics() => _lastMetrics;

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
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    if (_state == _WindowState.menu) {
      return _buildMenu(l10n, resource, definition, controller);
    }
    return _buildPet(resource, definition, controller);
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