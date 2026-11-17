import 'package:flutter/material.dart';

/// 動作網格的一格（icon + 單行標籤），標籤由外部注入以保持本元件無狀態。
class FeedingMenuTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FeedingMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// 精靈（精靈出巡）式的緊湊彈出選單：icon 列一條一條，中間是 2 欄動作網格，結束在最後（error 色）。
/// 顏色全部跟 theme（Card/TextButton 預設色），深色模式不用另外處理。
class FeedingMenu extends StatelessWidget {
  static const double contentWidth = 184;
  static const double _tileWidth = contentWidth / 2;
  static const double _tileHeight = 52;
  static const int _gridRows = 4; // 8 格 = 4 行 × 2 欄（與 kFlourishBehaviors 同長度）

  /// 底部那行小字的區塊高度
  static const double _footnoteHeight = 18;

  /// Card 內容高度（5 列 × 44 + 分隔線 + 4 行網格 + 分隔線 + 小字 + 上下 padding）；
  /// 選單視窗高度由它算出來（`menu_main.kMenuWindowSize`），改這行視窗會跟著變
  /// （`test/feeding_menu_test.dart` 會驗 overflow）。
  static const double contentHeight =
      5 * 44 + 1 + _gridRows * _tileHeight + 1 + _footnoteHeight + 16;

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

  /// 動作網格（必須正好 `_gridRows * 2` 格，對應 contentHeight 算出來的行數）
  final List<FeedingMenuTile> tiles;

  /// 任一列被按到时通知外面（用來重置自動關閉計時器）
  final VoidCallback? onInteract;

  /// 網格下方那行小字（例如「餵食會解除定格」）；null／空 = 不畫，但高度照樣保留
  /// （視窗尺寸是 kMenuWindowSize 固定的，有無小字不該讓它跳）
  final String? footnote;

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
    this.footnote,
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
            SizedBox(
              height: _footnoteHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    footnote ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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

  const _GridTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
