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
  final VoidCallback? onComplete; // 非 loop 動畫播完通知

  const AnimalAnimator({
    super.key,
    required this.resource,
    required this.definition,
    required this.action,
    required this.loader,
    this.onComplete,
  });

  @override
  State<AnimalAnimator> createState() => _AnimalAnimatorState();
}

class _AnimalAnimatorState extends State<AnimalAnimator>
    with SingleTickerProviderStateMixin {
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
    if (oldWidget.action != widget.action) {
      _controller.dispose();
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    _frameAnim = widget.definition.getAction(widget.action) ??
        widget.definition.actions.values.first;

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
      _controller.addStatusListener(_onStatus);
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

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
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
    final imageProvider =
        widget.loader.getFrameImage(widget.resource, frameName);

    return Image(
      image: imageProvider,
      width: widget.definition.frameWidth.toDouble(),
      height: widget.definition.frameHeight.toDouble(),
      filterQuality: FilterQuality.none, // pixel art 清晰顯示
      fit: BoxFit.contain,
    );
  }
}