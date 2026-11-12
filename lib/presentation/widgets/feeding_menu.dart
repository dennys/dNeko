import 'package:flutter/material.dart';

/// 動作網格的一格（icon + 單行標籤），標籤由外部注入以保持本元件無狀態。
class FeedingMenuTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FeedingMenuTile({required this.icon, required this.label, required this.onTap});
}

/// 精靈（精靈出巡）式的緊湊彈出選單：icon 列一條一條，中間是 2 欄動作網格，結束在最後（error 色）。
/// 顏色全部跟 theme（Card/TextButton 預設色），深色模式不用另外處理。
class FeedingMenu extends StatelessWidget {
  static const double contentWidth = 184;
  static const double _tileWidth = contentWidth / 2;
  static const double _tileHeight = 52;
  static const int _gridRows = 3;

  /// Card 內容高度（5 列 × 44 + 分隔線 + 3 行網格 + 分隔線 + 上下 padding）；overlay 靠它算視窗高度
  static const double contentHeight = 5 * 44 + 1 + _gridRows * _tileHeight + 1 + 16;

  final String feedLabel;
  final String petLabel;
  final String closeLabel;
  final String freezeLabel;
  final String quitLabel;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onFreeze;
  final VoidCallback onClose;
  final VoidCallback onQuit;

  /// 動作網格（必須正好 6 格，對應 contentHeight 的 3 行 × 2 欄）
  final List<FeedingMenuTile> tiles;

  /// 任一列被按到时通知外面（用來重置自動關閉計時器）
  final VoidCallback? onInteract;

  const FeedingMenu({
    super.key,
    required this.feedLabel,
    required this.petLabel,
    required this.closeLabel,
    required this.freezeLabel,
    required this.quitLabel,
    required this.onFeed,
    required this.onPet,
    required this.onFreeze,
    required this.onClose,
    required this.onQuit,
    required this.tiles,
    this.onInteract,
  }) : assert(tiles.length == _gridRows * 2);

  @override
  Widget build(BuildContext context) {
    void tap(VoidCallback action) {
      onInteract?.call();
      action();
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(icon: Icons.restaurant, label: feedLabel, onTap: () => tap(onFeed)),
            _MenuRow(icon: Icons.favorite, label: petLabel, onTap: () => tap(onPet)),
            _MenuRow(
              icon: Icons.pause_circle_outline,
              label: freezeLabel,
              onTap: () => tap(onFreeze),
            ),
            _MenuRow(icon: Icons.keyboard_arrow_up, label: closeLabel, onTap: () => tap(onClose)),
            const Divider(height: 1, indent: 14, endIndent: 14),
            SizedBox(
              width: contentWidth,
              child: Wrap(
                children: [
                  for (final tile in tiles)
                    _GridTile(
                      icon: tile.icon,
                      label: tile.label,
                      onTap: () => tap(tile.onTap),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            _MenuRow(
              icon: Icons.power_settings_new,
              label: quitLabel,
              onTap: () => tap(onQuit),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GridTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: FeedingMenu._tileWidth,
        height: FeedingMenu._tileHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: FeedingMenu.contentWidth,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
