import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/domain/i_overlay_window.dart';
import 'package:desktop_pet/presentation/controllers/pet_controller.dart';
import 'package:desktop_pet/presentation/controllers/overlay_pet_driver.dart';

/// 測試替身：記錄被移動到哪裡
class _FakeWindow implements IOverlayWindow {
  final List<Offset> moves = [];
  @override
  Future<void> moveTo(Offset position) async => moves.add(position);
  @override
  Future<void> resize({required double width, required double height}) async {}
  @override
  Future<void> close() async {}
}

void main() {
  const bounds = Rect.fromLTWH(0, 0, 200, 200);

  group('OverlayPetDriver', () {
    test('位置變化時移動視窗', () {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow();
      OverlayPetDriver(controller, window);

      controller.dragTo(const Offset(50, 60)); // 觸發 notifyListeners

      expect(window.moves, isNotEmpty);
      expect(window.moves.last, const Offset(50, 60));
    });

    test('停用時不移動視窗', () {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow();
      final driver = OverlayPetDriver(controller, window);

      driver.setEnabled(false);
      controller.dragTo(const Offset(30, 30));

      expect(window.moves, isEmpty);
    });
  });
}