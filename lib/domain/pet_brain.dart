import 'dart:math';
import 'dart:ui';
import 'i_pet_brain.dart';
import 'pet_behavior.dart';
import 'pet_bond.dart';
import 'pet_decision.dart';

/// 只負責：依飢餓狀態隨機決定寵物的下一個自主行為
class PetBrain implements IPetBrain {
  final Random _random;

  PetBrain([Random? random]) : _random = random ?? Random();

  /// 親密度滿值時「主動撒嬌」能佔掉的比例上限，其餘三種行為按原比例縮。
  /// 壓在 20%：再高就會蓋掉散步，看起來像隻只會撒嬌的布偶。
  static const double _maxAffectionShare = 0.20;

  @override
  PetDecision decideNext(Rect bounds, {bool isHungry = false, double bond = 0}) {
    // 餓的時候不睡覺，且更傾向到處走動找東西。**親密度在這裡無效** —— 餓到死也要先找食物
    if (isHungry) {
      return _random.nextDouble() < 0.7
          ? PetDecision(PetBehavior.wander, target: _randomPoint(bounds))
          : PetDecision(
              PetBehavior.idle,
              holdTime: Duration(seconds: 1 + _random.nextInt(2)),
            );
    }

    // 親密度唯一的後果：越高越容易**主動撒嬌**（沒有後果的數值只是計數器，不配叫親密度）。
    // bond=0 → affe=0，門檻退回 0.45/0.75，與加這欄位之前完全相同（pet_bond_test 鎖住這條）。
    final affe = (bond.clamp(0.0, PetBond.maxBond) / PetBond.maxBond) * _maxAffectionShare;
    final rest = 1 - affe;
    final roll = _random.nextDouble();

    if (roll < affe) {
      // holdTime 不在這裡給：撒嬌該播多久取決於素材有幾幀，是 PetController._affectionateHold 的事
      return const PetDecision(PetBehavior.affectionate);
    }
    if (roll < affe + 0.45 * rest) {
      return PetDecision(PetBehavior.wander, target: _randomPoint(bounds));
    }
    if (roll < affe + 0.75 * rest) {
      return PetDecision(
        PetBehavior.idle,
        holdTime: Duration(seconds: 2 + _random.nextInt(3)),
      );
    }
    return PetDecision(
      PetBehavior.sleep,
      holdTime: Duration(seconds: 4 + _random.nextInt(4)),
    );
  }

  Offset _randomPoint(Rect b) => Offset(
        b.left + _random.nextDouble() * b.width,
        b.top + _random.nextDouble() * b.height,
      );
}