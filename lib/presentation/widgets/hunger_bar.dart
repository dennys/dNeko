import 'package:flutter/material.dart';
import '../../domain/pet_stats.dart';

/// 只負責：顯示飢餓值的進度列
class HungerBar extends StatelessWidget {
  final PetStats stats;

  const HungerBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final ratio = stats.hunger / PetStats.maxHunger;
    final color = stats.isHungry ? Colors.redAccent : Colors.green;

    return Row(
      children: [
        Icon(Icons.restaurant, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${stats.hunger.toInt()}'),
      ],
    );
  }
}