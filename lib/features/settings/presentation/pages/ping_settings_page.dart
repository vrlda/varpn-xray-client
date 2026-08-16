import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class PingSettingsPage extends ConsumerWidget {
  const PingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final pingSettings = settings.pingSettings;
    final l10n = context.l10n;

    void saveProtocol(String protocol) {
      ref.read(settingsProvider.notifier).savePingSettings(
            pingSettings.copyWith(protocol: protocol),
          );
    }

    return SettingsPageShell(
      title: l10n.ping,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.pingProtocols),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _ProtocolRow(
                  title: l10n.proxyGetMethod,
                  selected: pingSettings.protocol == 'proxy_get',
                  onTap: () => saveProtocol('proxy_get'),
                ),
                const SettingsDivider(),
                _ProtocolRow(
                  title: l10n.proxyHeadMethod,
                  selected: pingSettings.protocol == 'proxy_head',
                  onTap: () => saveProtocol('proxy_head'),
                ),
                const SettingsDivider(),
                _ProtocolRow(
                  title: l10n.tcpMethod,
                  selected: pingSettings.protocol == 'tcp',
                  onTap: () => saveProtocol('tcp'),
                ),
                const SettingsDivider(),
                _ProtocolRow(
                  title: l10n.icmpMethod,
                  selected: pingSettings.protocol == 'icmp',
                  onTap: () => saveProtocol('icmp'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.pingRefreshHint,
                style: TextStyle(
                  color: AppTheme.colors(context).mutedText,
                  fontSize: 14,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 26),
            SettingsSectionLabel(title: l10n.urlTestSettings),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: pingSettings.url,
                  onTap: () async {
                    final value = await showSettingsTextInputDialog(
                      context: context,
                      title: l10n.urlTestLink,
                      initialValue: pingSettings.url,
                    );
                    if (value == null || value.trim().isEmpty) {
                      return;
                    }
                    ref.read(settingsProvider.notifier).savePingSettings(
                          pingSettings.copyWith(url: value.trim()),
                        );
                  },
                  height: 58,
                ),
              ],
            ),
            const SizedBox(height: 26),
            SettingsSectionLabel(title: l10n.interfaceSection),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.displayMode,
                  trailing: SettingsValueChevron(
                    value: l10n.timeDisplayMode,
                  ),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.displayMode,
                      options: [
                        SelectionOption(
                          value: 'time',
                          label: l10n.timeDisplayMode,
                        ),
                      ],
                      selectedValue: pingSettings.displayMode,
                    );
                    if (selected == null) {
                      return;
                    }
                    ref.read(settingsProvider.notifier).savePingSettings(
                          pingSettings.copyWith(displayMode: selected),
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
}

class _ProtocolRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ProtocolRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: title,
      trailing: selected
          ? const Icon(
              Icons.check_rounded,
              color: Color(0xFF7A68FF),
              size: 22,
            )
          : const SizedBox(width: 22),
      onTap: onTap,
      height: 58,
    );
  }
}
