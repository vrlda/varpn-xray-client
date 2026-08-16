import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class RoutingDistributionPage extends ConsumerWidget {
  final String presetId;

  const RoutingDistributionPage({
    super.key,
    required this.presetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppTheme.colors(context);
    final routingSettings = ref.watch(settingsProvider).routingSettings;
    final preset =
        routingSettings.findPreset(presetId) ?? routingSettings.selectedPreset;

    return SettingsPageShell(
      title: l10n.proxySettings,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.proxySettings),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.globalProxyServer,
                  trailing: SettingsToggle(
                    value: preset.globalProxyEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).saveRoutingSettings(
                            routingSettings.updatePreset(
                              preset.copyWith(
                                globalProxyEnabled: value,
                              ),
                            ),
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
                l10n.globalProxyDescription,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 14,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SettingsSectionLabel(title: l10n.routingDistributionSettings),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.throughProxy,
                  onTap: () => context.push(
                    '/settings/routes/preset/$presetId/rules/proxy',
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.direct,
                  onTap: () => context.push(
                    '/settings/routes/preset/$presetId/rules/direct',
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.block,
                  onTap: () => context.push(
                    '/settings/routes/preset/$presetId/rules/block',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
