import 'package:flutter/material.dart';
import '../../data/models/animation_action.dart';
import '../../data/models/animation_definition.dart';
import '../../data/models/animal_resource.dart';
import '../../data/services/animation_loader.dart';

class AnimalAnimator extends StatefulWidget {
  final AnimalResource resource;
  final AnimalAnimationDefinition definition;
  final AnimationAction action;
  final AnimationLoader loader;
  final double? displayWidth;
  final double? displayHeight;

  const AnimalAnimator({
    super.key,
    required this.resource,
    required this.definition,
    required this.action,
    required this.loader,
    this.displayWidth,
    this.displayHeight,
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

    if (_frameAnim.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

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

    if (!mirrored) return image;
    return Transform.flip(flipX: true, child: image);
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
