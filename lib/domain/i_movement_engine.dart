import 'dart:ui';

typedef MovementResult = ({Offset position, bool arrived});

abstract interface class IMovementEngine {
  MovementResult step({
    required Offset current,
    required Offset target,
    required Rect bounds,
  });
}