import 'package:flutter/material.dart';

import '../../data/models/animation_definition.dart';
import '../../data/models/animal_resource.dart';
import '../../data/repositories/i_animal_repository.dart';
import '../../data/services/animation_loader.dart';
import '../../domain/pet_settings.dart';
import '../../domain/pet_stats.dart';
import '../../domain/screen_metrics.dart';
import '../../utils/log.dart';
import '../controllers/pet_controller.dart';
import '../controllers/pet_controller_factory.dart';
import 'animal_animator.dart';

/// 主頁上方的預覽塊：跑與 overlay **同一套** `PetController`，改速度／大小即時看到結果。
///
/// 與 overlay 的三處刻意的不同：
/// 1. 餓度是**獨立沙箱**（自己 new 的 `PetStats`，不讀也不寫 DB）—— 否則在 app 裡餵一口，
///    懸浮那隻也飽了，而 overlay 沒開時的「缺席補算」會跟它打架，兩邊的餓度都變成假的。
/// 2. 不做長按選單：選單是 overlay 限定（README 已照實寫）。
/// 3. 忽略 `zone`：預覽塊沒有「全螢幕／僅下方／四角」的語意，硬套只會讓人以為設定壞了。
///
/// shortcut: app 進背景時 tick 仍舊在跑（`PetController` 沒有 pause，只有 dispose）；
/// 測試期可接受，真機 P-8 若測出明顯耗電/發熱再補 pause。
class PetPreview extends StatefulWidget {
  /// 高度容得下最大的寵物（+ 一點走動的餘地）
  static const double blockHeight = PetSettings.maxPetSize + 16;

  final PetSettings settings;
  final IAnimalRepository repository;

  /// 可注入（測試用）；沒給就由本 widget 自己建一個，見 `_loader`
  final AnimationLoader? loader;

  const PetPreview({
    super.key,
    required this.settings,
    required this.repository,
    this.loader,
  });

  @override
  State<PetPreview> createState() => _PetPreviewState();
}

class _PetPreviewState extends State<PetPreview> {
  static const _factory = PetControllerFactory();

  /// 食物擲在牠旁邊多遠（與 overlay 同一個距離，兩邊手感才一致）
  static const double _feedDropDistance = 120;

  PetController? _controller;
  AnimalResource? _resource;
  AnimalAnimationDefinition? _definition;
  bool _failed = false;

  /// 同 overlay：只有最新那次載入能寫狀態（換動物時兩重載會疊在一起）
  int _loadSeq = 0;

  /// 預覽塊實際尺寸，由 `LayoutBuilder` 填；`build` 裡拿它算 bounds
  Size _block = Size.zero;

  AnimationLoader? _ownLoader;
  AnimationLoader get _loader => widget.loader ?? (_ownLoader ??= AnimationLoader());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.settings;
    final prev = oldWidget.settings;

    if (next.animalId != prev.animalId) {
      _load();
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    // slider 拖動過程中每個像素都會重建（ HomePage 走 SettingsController.preview），
    // 這兩個 setter 只是換一個 MovementEngine / 記一個 Rect，不用等 onChangeEnd
    if (next.speedPxPerSecond != prev.speedPxPerSecond) {
      controller.setSpeedPerTick(next.speedPerTick);
    }
    if (next.petSize != prev.petSize) {
      controller.updateBounds(previewBounds(_block, next.petSize));
    }
  }

  @override
  void dispose() {
    _controller?.dispose(); // 沙箱 stats 由 controller 自己擁有、自己關
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    bool stale() => seq != _loadSeq;
    final animalId = widget.settings.animalId;

    AnimalResource? resource;
    AnimalAnimationDefinition? definition;
    try {
      resource = await widget.repository.resolveResource(animalId);
      if (stale()) return;
      if (resource == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      definition = await _loader.load(resource);
      if (stale() || !mounted) return;
    } catch (e, st) {
      appError('預覽塊載入失敗（$animalId）', e, st);
      if (!stale() && mounted) setState(() => _failed = true);
      return;
    }

    _controller?.dispose();
    final controller = _factory.create(
      bounds: previewBounds(_block, widget.settings.petSize),
      definition: definition,
      speedPerTick: widget.settings.speedPerTick,
      stats: PetStats(),
    )..start();

    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _failed = false;
      _resource = resource;
      _definition = definition;
      _controller = controller;
    });
  }

  void _pet() => _controller?.pet();

  void _feed() {
    final controller = _controller;
    if (controller == null) return;
    controller.feedAt(
      Offset(controller.position.dx + _feedDropDistance, controller.position.dy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resource = _resource;
    final definition = _definition;
    final controller = _controller;
    final petSize = widget.settings.petSize;

    return SizedBox(
      height: PetPreview.blockHeight,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _block = constraints.biggest;
            // 冪等：只有尺寸或寵物大小變了才是真的換了 Rect。放在 build 是因為
            // 區塊大小只有到這裡才知道，而 `updateBounds` 沒有別的副作用。
            controller?.updateBounds(previewBounds(_block, petSize));

            if (resource == null || definition == null || controller == null) {
              return _placeholder();
            }
            return GestureDetector(
              onTap: _pet, // 短按 = 撫摸（與 overlay 相同）
              onDoubleTap: _feed, // 雙擊 = 餵食（與 overlay 相同）
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Stack(
                  // expand：只有 Positioned 子節點的 Stack 會縮成零大小，那個時候
                  // GestureDetector 也一起變零大小 —— 「按精靈」會整個按不到。
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: controller.position.dx,
                      top: controller.position.dy,
                      width: petSize,
                      height: petSize,
                      child: AnimalAnimator(
                        resource: resource,
                        definition: definition,
                        action: controller.action,
                        loader: _loader,
                        displayWidth: petSize,
                        displayHeight: petSize,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 載入失敗／還在載：給一個可按的東西（按它重試），不硬塞文字，省得一組翻譯
  Widget _placeholder() {
    return Center(
      child: IconButton(
        iconSize: 48,
        color: Theme.of(context).colorScheme.outline,
        icon: const Icon(Icons.pets),
        onPressed: _failed ? _load : null,
      ),
    );
  }
}
