import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/xray_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../widgets/settings_common.dart';

class XraySettingsPage extends ConsumerWidget {
  const XraySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final xraySettings = settings.xraySettings;

    return SettingsPageShell(
      title: l10n.xraySettingsTitle,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.coreBehavior),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.logLevelLabel,
                  trailing: SettingsValueChevron(
                    value: _logLevelLabel(xraySettings.logLevel, l10n),
                  ),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.logLevelLabel,
                      options: [
                        SelectionOption(
                          value: 'error',
                          label: l10n.errorLogLevel,
                        ),
                        SelectionOption(
                          value: 'warning',
                          label: l10n.warningLogLevel,
                        ),
                        SelectionOption(
                          value: 'info',
                          label: l10n.infoLogLevel,
                        ),
                        SelectionOption(
                          value: 'debug',
                          label: l10n.debugLogLevel,
                        ),
                      ],
                      selectedValue: xraySettings.logLevel,
                    );
                    if (selected == null) {
                      return;
                    }
                    _save(
                      ref,
                      xraySettings.copyWith(logLevel: selected),
                    );
                  },
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.sniffingLabel,
                  trailing: SettingsToggle(
                    value: xraySettings.sniffingEnabled,
                    onChanged: (value) => _save(
                      ref,
                      xraySettings.copyWith(sniffingEnabled: value),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.allowInsecureLabel,
                  trailing: SettingsToggle(
                    value: xraySettings.allowInsecure,
                    onChanged: (value) => _save(
                      ref,
                      xraySettings.copyWith(allowInsecure: value),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.transportOverrideLabel,
                  trailing: SettingsValueChevron(
                    value:
                        _transportLabel(xraySettings.transportOverride, l10n),
                  ),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.transportOverrideLabel,
                      options: [
                        SelectionOption(
                          value: 'auto',
                          label: l10n.autoTransport,
                        ),
                        SelectionOption(
                          value: 'tcp',
                          label: l10n.tcpTransport,
                        ),
                        SelectionOption(
                          value: 'grpc',
                          label: l10n.grpcTransport,
                        ),
                        SelectionOption(
                          value: 'xhttp',
                          label: l10n.xhttpTransport,
                        ),
                      ],
                      selectedValue: xraySettings.transportOverride,
                    );
                    if (selected == null) {
                      return;
                    }
                    _save(
                      ref,
                      xraySettings.copyWith(transportOverride: selected),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save(WidgetRef ref, XraySettings next) {
    ref.read(settingsProvider.notifier).saveXraySettings(next);
  }

  String _logLevelLabel(String logLevel, AppLocalizations l10n) {
    return switch (logLevel) {
      'error' => l10n.errorLogLevel,
      'info' => l10n.infoLogLevel,
      'debug' => l10n.debugLogLevel,
      _ => l10n.warningLogLevel,
    };
  }

  String _transportLabel(String value, AppLocalizations l10n) {
    return switch (value) {
      'tcp' => l10n.tcpTransport,
      'grpc' => l10n.grpcTransport,
      'xhttp' => l10n.xhttpTransport,
      _ => l10n.autoTransport,
    };
  }
}
