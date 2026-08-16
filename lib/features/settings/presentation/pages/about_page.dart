import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppTheme.colors(context);
    final settings = ref.watch(settingsProvider);
    final developerToolsState =
        settings.developerToolsUnlocked ? l10n.unlockedLabel : l10n.hiddenLabel;

    return SettingsPageShell(
      title: l10n.aboutApp,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Text(
                    l10n.aboutSummary,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 15,
                      fontFamily: '.SF Pro Text',
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SettingsSectionLabel(title: l10n.aboutApp),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _InfoRow(
                  label: l10n.aboutVersionLabel,
                  value: '1.0.0',
                ),
                const SettingsDivider(),
                _InfoRow(
                  label: l10n.aboutRuntimeLabel,
                  value: Platform.isMacOS ? l10n.proxyModeLabel : l10n.tunnel,
                ),
                const SettingsDivider(),
                _InfoRow(
                  label: l10n.aboutStorageLabel,
                  value: l10n.aboutStorageValue,
                ),
                const SettingsDivider(),
                _InfoRow(
                  label: l10n.aboutDeveloperToolsLabel,
                  value: developerToolsState,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return SettingsRow(
      title: label,
      trailing: Text(
        value,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 16,
          fontFamily: '.SF Pro Text',
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
      height: 54,
    );
  }
}
