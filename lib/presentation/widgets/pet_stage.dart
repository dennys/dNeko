import 'package:flutter/material.dart';
import '../../data/models/animal_resource.dart';
import '../../data/models/animation_definition.dart';
import '../../data/services/animation_loader.dart';
import '../controllers/pet_controller.dart';
import '../controllers/pet_controller_factory.dart';
import '../widgets/animal_animator.dart';

class PetStage extends StatefulWidget {
  final AnimalResource resource;
  final AnimalAnimationDefinition definition;
  final AnimationLoader loader;

  const PetStage({
    super.key,
    required this.resource,
    required this.definition,
    required this.loader,
  });

  @override
  State<PetStage> createState() => _PetStageState();
}

class _PetStageState extends State<PetStage> {
  static const _controllerFactory = PetControllerFactory();
  PetController? _controller;
  Offset? _food;

  @override
  Widget build(BuildContext context) {
    final w = widget.definition.frameWidth.toDouble();
    final h = widget.definition.frameHeight.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 限定活動範圍：扣掉寵物尺寸，避免跑出邊界
        final bounds = Rect.fromLTRB(
          0, 0, constraints.maxWidth - w, constraints.maxHeight - h,
        );

        final controller = _controller ??= _controllerFactory.create(
          bounds: bounds,
          definition: widget.definition,
        )..start();

        controller.updateBounds(bounds);

        return GestureDetector(
          // 點空白處 → 放食物並餵食
          onTapDown: (d) {
            setState(() => _food = d.localPosition);
            controller.feedAt(d.localPosition);
          },
          child: Stack(
            children: [
              if (_food != null)
                Positioned(
                  left: _food!.dx - 8, top: _food!.dy - 8,
                  child: const Icon(Icons.cookie, size: 16),
                ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  return Positioned(
                    left: controller.position.dx,
                    top: controller.position.dy,
                    // 點寵物本身 → 撫摸
                    child: GestureDetector(
                      onTap: controller.pet,
                      child: AnimalAnimator(
                        resource: widget.resource,
                        definition: widget.definition,
                        action: controller.action,
                        loader: widget.loader,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
