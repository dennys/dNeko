import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../controllers/store_controller.dart';

class StorePage extends StatefulWidget {
  final StoreController controller;

  const StorePage({super.key, required this.controller});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storeTitle)),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = widget.controller.items;
          if (items.isEmpty) {
            return Center(child: Text(l10n.storeEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _StoreTile(
              state: items[index],
              l10n: l10n,
              onDownload: () =>
                  widget.controller.download(items[index].item),
              onRemove: () => widget.controller.remove(items[index].item),
            ),
          );
        },
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final StoreItemState state;
  final AppLocalizations l10n;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const _StoreTile({
    required this.state,
    required this.l10n,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.pets)),
      title: Text(state.item.displayName),
      subtitle: Text('v${state.item.version}'),
      trailing: _buildTrailing(),
    );
  }

  Widget _buildTrailing() {
    switch (state.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            value: state.progress == 0 ? null : state.progress,
            strokeWidth: 3,
          ),
        );
      case DownloadStatus.downloaded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.storeRemove,
              onPressed: onRemove,
            ),
          ],
        );
      case DownloadStatus.available:
        return TextButton.icon(
          icon: const Icon(Icons.download),
          label: Text(l10n.storeDownload),
          onPressed: onDownload,
        );
    }
  }
}