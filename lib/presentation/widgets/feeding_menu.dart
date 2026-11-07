import 'package:flutter/material.dart';

class FeedingMenu extends StatelessWidget {
  final String feedLabel;
  final String petLabel;
  final String closeLabel;
  final String freezeLabel;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onFreeze;
  final VoidCallback onClose;

  const FeedingMenu({
    super.key,
    required this.feedLabel,
    required this.petLabel,
    required this.closeLabel,
    required this.freezeLabel,
    required this.onFeed,
    required this.onPet,
    required this.onFreeze,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuButton(icon: Icons.restaurant, label: feedLabel, onTap: onFeed),
            const SizedBox(height: 8),
            _MenuButton(icon: Icons.favorite, label: petLabel, onTap: onPet),
            const SizedBox(height: 8),
            _MenuButton(icon: Icons.pause, label: freezeLabel, onTap: onFreeze),
            const SizedBox(height: 8),
            _MenuButton(icon: Icons.close, label: closeLabel, onTap: onClose),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}