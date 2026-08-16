import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/routing_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class RoutesRulesPage extends ConsumerWidget {
  const RoutesRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routingSettings = ref.watch(settingsProvider).routingSettings;
    final colors = AppTheme.colors(context);

    return SettingsPageShell(
      title: l10n.routesAndRules,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.useRouting,
                  trailing: SettingsToggle(
                    value: routingSettings.enabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).saveRoutingSettings(
                            routingSettings.copyWith(enabled: value),
                          );
                    },
                  ),
                  height: 58,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.routingDescription,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 14,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SettingsSectionLabel(title: l10n.selectRoutingPreset),
                SettingsTextAction(
                  label: l10n.edit,
                  onTap: () => context.push('/settings/routes/presets'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                for (var i = 0; i < routingSettings.presets.length; i++) ...[
                  _PresetRow(
                    preset: routingSettings.presets[i],
                    isSelected: routingSettings.selectedPresetId ==
                        routingSettings.presets[i].id,
                    onTap: () {
                      final nextState = routingSettings.selectPreset(
                        routingSettings.presets[i].id,
                      );
                      ref.read(settingsProvider.notifier).saveRoutingSettings(
                            nextState,
                          );
                      context.push(
                        '/settings/routes/preset/${routingSettings.presets[i].id}',
                      );
                    },
                  ),
                  if (i != routingSettings.presets.length - 1)
                    const SettingsDivider(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  final RoutingPresetConfig preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetRow({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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
            Expanded(
              child: Text(
                context.l10n.routingPresetName(preset.name),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
