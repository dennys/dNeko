import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/models/animation_action.dart';
import '../../data/models/animation_definition.dart';
import '../../data/models/animal_resource.dart';
import '../../data/services/animation_loader.dart';
import 'hunger_bubble.dart';

/// 沒有專用素材的小動作：在坐著的幀上加程式化動作。t 為控制器進度（0..1，一輪循環），
/// height 是寵物顯示高度（logical px，需要按比例移動的動作用它，免得上調寵物尺寸就縮成一團）。
typedef _Motion = Widget Function(double t, double height, Widget child);

const double _hopHeight = 8;
const double _wobbleAmplitude = 4;
const double _nodAngle = 0.08;

// 餓昏那兩格（借幀時的備援演出，素材到位就不會走到這裡）
const double _begDip = 6; // 作揖的伏身量（重心向下，比 hop 的向上跳矮才像在拜）
const double _begTilt = 0.07;
const double _faintAngle = 1.4; // ≈80°，倒平但不要完全翻成一條線
const double _faintDropFraction = 0.26; // 翻同時往下坐，才不會整個飄在半空
const double _fallFraction = 0.55; // 一輪的前 55% 用來倒，之後就攤著不動

_Motion? _motionFor(AnimationAction action, {required bool hasOwnFrames}) => switch (action) {
      AnimationAction.hop => (t, _, child) => Transform.translate(
            offset: Offset(0, -_hopHeight * math.sin(t * 2 * math.pi).abs()),
            child: child,
          ),
      AnimationAction.wobble => (t, _, child) => Transform.translate(
            offset: Offset(_wobbleAmplitude * math.sin(t * 4 * math.pi), 0),
            child: child,
          ),
      AnimationAction.doze => (t, _, child) => Transform.rotate(
            angle: _nodAngle * math.sin(t * 2 * math.pi),
            child: child,
          ),
      AnimationAction.lookAround => (t, _, child) => Transform.flip(flipX: t >= 0.5, child: child),
      // 討食：一伏一伏地作揖，5 秒下來看起來就一直在拜（借的是 sit 那兩幀，loop:true）。
      AnimationAction.beg when !hasOwnFrames => (t, _, child) => Transform.translate(
            offset: Offset(0, _begDip * math.sin(t * 4 * math.pi).abs()),
            child: Transform.rotate(
              angle: _begTilt * math.sin(t * 2 * math.pi),
              child: child,
            ),
          ),
      // 裝死：前 55% 倒下去（越掉越快），之後就攤著 —— hold 剩下的時間停在「躺平」那一格，
      // 那正是笑點。繞中心翻而不是繞腳翻：繞腳會把頭甩出寵物框，而懸浮視窗只有寵物大小
      // （同一件事讓求助氣泡也必須畫在框內，見 hunger_bubble.dart）。
      AnimationAction.faint when !hasOwnFrames => (t, height, child) {
          final p = (t / _fallFraction).clamp(0.0, 1.0);
          final fall = p * p;
          return Transform.translate(
            offset: Offset(0, _faintDropFraction * height * fall),
            child: Transform.rotate(angle: _faintAngle * fall, child: child),
          );
        },
      _ => null,
    };

class AnimalAnimator extends StatefulWidget {
  final AnimalResource resource;
  final AnimalAnimationDefinition definition;
  final AnimationAction action;
  final AnimationLoader loader;
  final double? displayWidth;
  final double? displayHeight;

  /// 餓昏：頭頂多一顆求助氣泡（素材有沒有到位都畫得出來，見 [HungerBubble]）。
  final bool starving;

  const AnimalAnimator({
    super.key,
    required this.resource,
    required this.definition,
    required this.action,
    required this.loader,
    this.displayWidth,
    this.displayHeight,
    this.starving = false,
  });

  @override
  State<AnimalAnimator> createState() => _AnimalAnimatorState();
}

class _AnimalAnimatorState extends State<AnimalAnimator> with TickerProviderStateMixin {
  // 不是 SingleTicker：換動作時 didUpdateWidget 會 dispose 舊的 AnimationController
  // 再用同一個 vsync 建一個新的，SingleTickerProviderStateMixin 第二次就斷言失敗
  // （debug 模式下 overlay 換動作的瞬間就會炸；release 只是剛好沒斷言，ticker 也漏在
  //  mixin 的記錄之外）。

  late AnimationController _controller;
  late FrameAnimation _frameAnim;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(AnimalAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换动物时 action 常不变（两动物都 sit 起手）：frame 清单与 duration 都要换，
    // 否则画面仍用旧动物帧（AnimalAnimator 是同一 position in tree，State 不 rebuild）。
    if (oldWidget.action != widget.action ||
        oldWidget.definition != widget.definition ||
        oldWidget.resource != widget.resource) {
      _controller.dispose();
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    _frameAnim = widget.definition.getAction(widget.action) ?? widget.definition.actions.values.first;

    _currentFrame = 0;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: _frameAnim.frameDurationMs * _frameAnim.frames.length,
      ),
    );

    _controller.addListener(_onTick);

    // 借幀裝死不能循環：借來的是 loop:true 的 sit 幀，一路 repeat 會變成「每秒重新倒一次」。
    // 素材自己宣告了 Faint 就照素材的 loop（作者說循環就循環）。
    final repeats = _frameAnim.loop && !(_borrowsFrames && widget.action == AnimationAction.faint);
    if (repeats) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  /// 這個動作有沒有專屬素材（還是走 `_missingFrameAlias` 借來的幀）。
  /// 借來的才需要程式化作動與上面的「裝死只播一次」；素材到位就由素材自己演，
  /// 不能再疊一層（會變成「真素材在倒 + 又被轉 80 度」）。
  bool get _borrowsFrames => !widget.definition.actions.containsKey(widget.action);

  void _onTick() {
    final totalFrames = _frameAnim.frames.length;
    final progress = _controller.value;
    final newFrame = (progress * totalFrames).floor().clamp(0, totalFrames - 1);

    if (newFrame != _currentFrame) {
      setState(() => _currentFrame = newFrame);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameName = _frameAnim.frames[_currentFrame];
    final imageProvider = widget.loader.getFrameImage(widget.resource, frameName);
    final width = widget.displayWidth ?? widget.definition.frameWidth.toDouble();
    final height = widget.displayHeight ?? widget.definition.frameHeight.toDouble();
    final mirrored = widget.definition.mirrorsSideFor(widget.action);

    final image = Image(
      image: imageProvider,
      width: width,
      height: height,
      filterQuality: FilterQuality.none, // pixel art 清晰顯示
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _FallbackPetPainter(
            action: widget.action,
            frame: _currentFrame,
          ),
        ),
      ),
    );

    final child = mirrored ? Transform.flip(flipX: true, child: image) : image;

    final motion = _motionFor(widget.action, hasOwnFrames: !_borrowsFrames);
    final pet = motion == null
        ? child
        : AnimatedBuilder(
            animation: _controller,
            child: child,
            builder: (context, c) => motion(_controller.value, height, c!),
          );
    if (!widget.starving) return pet;

    // 氣泡摆在**框內**右上角而不是視窗上方：懸浮視窗只有寵物大小（「移動小視窗」技巧），
    // 畫到框外會被視窗裁掉；素材畫布上方本來就留了約 23% 的空白頭部空間，放得下。
    return Stack(
      children: [
        pet,
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: width * 0.42,
            height: width * 0.42,
            child: const HungerBubble(),
          ),
        ),
      ],
    );
  }
}

class _FallbackPetPainter extends CustomPainter {
  final AnimationAction action;
  final int frame;

  const _FallbackPetPainter({required this.action, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 32;
    final body = Paint()..color = const Color(0xFF2E3440);
    final shade = Paint()..color = const Color(0xFF4C566A);
    final eye = Paint()..color = const Color(0xFFECEFF4);
    final blush = Paint()..color = const Color(0xFFEBCB8B);
    final sleep = Paint()..color = const Color(0xFF81A1C1);

    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale);

    final bob = _isMoving
        ? frame.isEven
            ? 0.0
            : 1.0
        : 0.0;

    canvas.drawRect(r(8, 12 + bob, 16, 12), body);
    canvas.drawRect(r(10, 8 + bob, 12, 8), body);
    canvas.drawRect(r(8, 6 + bob, 4, 5), body);
    canvas.drawRect(r(20, 6 + bob, 4, 5), body);
    canvas.drawRect(r(24, 15 + bob, 5, 4), shade);
    canvas.drawRect(r(6, 22 + bob, 5, 3), shade);
    canvas.drawRect(r(21, 22 + bob, 5, 3), shade);

    if (action == AnimationAction.sleep) {
      canvas.drawRect(r(13, 12 + bob, 3, 1), sleep);
      canvas.drawRect(r(18, 12 + bob, 3, 1), sleep);
      canvas.drawRect(r(23, 5, 2, 1), sleep);
      canvas.drawRect(r(25, 3, 3, 1), sleep);
      return;
    }

    canvas.drawRect(r(13, 11 + bob, 2, 2), eye);
    canvas.drawRect(r(19, 11 + bob, 2, 2), eye);
    canvas.drawRect(r(16, 14 + bob, 2, 1), blush);

    if (action == AnimationAction.affectionate) {
      canvas.drawRect(r(11, 15 + bob, 2, 1), blush);
      canvas.drawRect(r(21, 15 + bob, 2, 1), blush);
    }
  }

  bool get _isMoving => switch (action) {
        AnimationAction.walkUp ||
        AnimationAction.walkDown ||
        AnimationAction.walkLeft ||
        AnimationAction.walkRight ||
        AnimationAction.walkUpLeft ||
        AnimationAction.walkUpRight ||
        AnimationAction.walkDownLeft ||
        AnimationAction.walkDownRight =>
          true,
        _ => false,
      };

  @override
  bool shouldRepaint(_FallbackPetPainter oldDelegate) => oldDelegate.action != action || oldDelegate.frame != frame;
}
