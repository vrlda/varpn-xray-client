import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/routing_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class RoutingPresetManagerPage extends ConsumerWidget {
  const RoutingPresetManagerPage({super.key});

  Future<void> _addPreset(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider).routingSettings;
    final name = await showSettingsTextInputDialog(
      context: context,
      title: context.l10n.newPreset,
      initialValue: '',
    );

    if (name == null || name.trim().isEmpty || !context.mounted) {
      return;
    }

    ref.read(settingsProvider.notifier).saveRoutingSettings(
          settings.addPreset(
            name: name.trim(),
            sourcePreset: settings.selectedPreset,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.presetAdded)),
    );
  }

  void _removePreset(
    BuildContext context,
    WidgetRef ref,
    RoutingPresetConfig preset,
  ) {
    final settings = ref.read(settingsProvider).routingSettings;
    if (settings.presets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotRemoveLastPreset)),
      );
      return;
    }

    ref.read(settingsProvider.notifier).saveRoutingSettings(
          settings.removePreset(preset.id),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.presetRemoved)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routingSettings = ref.watch(settingsProvider).routingSettings;
    final l10n = context.l10n;

    return SettingsPageShell(
      title: l10n.routingPresets,
      onBack: () => context.pop(),
      trailing: SettingsTextAction(
        label: l10n.addPreset,
        onTap: () => _addPreset(context, ref),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: SettingsCard(
          children: [
            for (var i = 0; i < routingSettings.presets.length; i++) ...[
              _PresetManagerRow(
                preset: routingSettings.presets[i],
                isSelected: routingSettings.selectedPresetId ==
                    routingSettings.presets[i].id,
                onSelect: () {
                  ref.read(settingsProvider.notifier).saveRoutingSettings(
                        routingSettings.selectPreset(
                          routingSettings.presets[i].id,
                        ),
                      );
                },
                onDelete: () => _removePreset(
                  context,
                  ref,
                  routingSettings.presets[i],
                ),
              ),
              if (i != routingSettings.presets.length - 1)
                const SettingsDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetManagerRow extends StatelessWidget {
  final RoutingPresetConfig preset;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _PresetManagerRow({
    required this.preset,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSelect,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? colors.chipSelected : colors.mutedText,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.routingPresetName(preset.name),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colors.mutedText,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
