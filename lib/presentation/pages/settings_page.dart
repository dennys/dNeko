import 'package:flutter/material.dart';
import '../../domain/i_overlay_service.dart';
import '../../domain/pet_settings.dart';
import '../../domain/screen_metrics.dart';
import '../../l10n/app_localizations.dart';
import '../controllers/settings_controller.dart';

/// 只負責：速度 / 大小 / 活動範圍三個控制項。
/// 改動即存檔，並推給已經開著的 overlay（同一條 shareData 通道，不必重開視窗）。
class SettingsPage extends StatelessWidget {
  final SettingsController controller;
  final IOverlayService overlayService;

  const SettingsPage({
    super.key,
    required this.controller,
    required this.overlayService,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final settings = controller.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.settingsSpeed),
              Slider(
                value: settings.speedPxPerSecond,
                min: PetSettings.minSpeedPerSecond,
                max: PetSettings.maxSpeedPerSecond,
                divisions: (PetSettings.maxSpeedPerSecond - PetSettings.minSpeedPerSecond) ~/ 10,
                label: '${settings.speedPxPerSecond.round()} px/s',
                onChanged: (v) => controller.preview(_copy(settings, speed: v)),
                onChangeEnd: (v) => _update(context, _copy(settings, speed: v)),
              ),
              const SizedBox(height: 16),
              Text(l10n.settingsSize),
              Slider(
                value: settings.petSize,
                min: PetSettings.minPetSize,
                max: PetSettings.maxPetSize,
                divisions: ((PetSettings.maxPetSize - PetSettings.minPetSize) / 10).round(),
                label: '${settings.petSize.round()} dp',
                onChanged: (v) => controller.preview(_copy(settings, size: v)),
                onChangeEnd: (v) => _update(context, _copy(settings, size: v)),
              ),
              const SizedBox(height: 16),
              Text(l10n.settingsZone),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final zone in PetZone.values)
                    ChoiceChip(
                      label: Text(_zoneLabel(l10n, zone)),
                      selected: settings.zone == zone,
                      onSelected: (_) => _update(context, _copy(settings, zone: zone)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PetSettings _copy(PetSettings s, {double? speed, double? size, PetZone? zone}) => PetSettings(
        speedPxPerSecond: speed ?? s.speedPxPerSecond,
        petSize: size ?? s.petSize,
        zone: zone ?? s.zone,
      );

  String _zoneLabel(AppLocalizations l10n, PetZone zone) => switch (zone) {
        PetZone.fullScreen => l10n.zoneFullScreen,
        PetZone.bottomBand => l10n.zoneBottomBand,
        PetZone.topLeft => l10n.zoneTopLeft,
        PetZone.topRight => l10n.zoneTopRight,
        PetZone.bottomLeft => l10n.zoneBottomLeft,
        PetZone.bottomRight => l10n.zoneBottomRight,
      };

  Future<void> _update(BuildContext context, PetSettings next) async {
    // await 之前先抓妥 context 相關值，避免 use_build_context_synchronously
    final mq = MediaQuery.of(context);
    final metrics = ScreenMetrics(
      logicalSize: mq.size,
      devicePixelRatio: mq.devicePixelRatio,
      bottomInset: mq.padding.bottom,
    );
    final languageCode = Localizations.localeOf(context).languageCode;

    await controller.update(next);
    if (!await overlayService.isActive()) return;
    await overlayService.pushSettings(
      animalId: defaultAnimalId,
      settings: next,
      metrics: metrics,
      languageCode: languageCode,
    );
  }
}
