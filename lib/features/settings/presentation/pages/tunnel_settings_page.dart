import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/tunnel_health.dart';
import '../../../../core/models/tunnel_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/vpn_provider.dart';
import '../widgets/settings_common.dart';

class TunnelSettingsPage extends ConsumerStatefulWidget {
  const TunnelSettingsPage({super.key});

  @override
  ConsumerState<TunnelSettingsPage> createState() => _TunnelSettingsPageState();
}

class _TunnelSettingsPageState extends ConsumerState<TunnelSettingsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final tunnelSettings = settings.tunnelSettings;

    return SettingsPageShell(
      title: l10n.tunnelSettingsTitle,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.tunnelBehavior),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.mtuLabel,
                  trailing: SettingsValueChevron(
                    value: tunnelSettings.mtu.toString(),
                  ),
                  onTap: () => _selectMtu(context, tunnelSettings),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.ipv6Label,
                  trailing: SettingsToggle(
                    value: tunnelSettings.ipv6Enabled,
                    onChanged: (value) => _save(
                      tunnelSettings.copyWith(ipv6Enabled: value),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.bypassLocalNetworks,
                  trailing: SettingsToggle(
                    value: tunnelSettings.bypassLocalNetworks,
                    onChanged: (value) => _save(
                      tunnelSettings.copyWith(bypassLocalNetworks: value),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.strictRoutingLabel,
                  trailing: SettingsToggle(
                    value: tunnelSettings.strictRouting,
                    onChanged: (value) => _save(
                      tunnelSettings.copyWith(strictRouting: value),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.dnsModeLabel,
                  trailing: SettingsValueChevron(
                    value: tunnelSettings.dnsMode == 'system'
                        ? l10n.systemDnsMode
                        : l10n.customDnsMode,
                  ),
                  onTap: () => _selectDnsMode(context, tunnelSettings),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.dnsServersLabel,
                  trailing: SettingsValueChevron(
                    value: tunnelSettings.dnsMode == 'system'
                        ? l10n.systemDnsMode
                        : tunnelSettings.dnsServers.join(', '),
                  ),
                  onTap: tunnelSettings.dnsMode == 'system'
                      ? null
                      : () => _editDnsServers(context, tunnelSettings),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SettingsSectionLabel(title: l10n.tunnelHealthSection),
            const SizedBox(height: 14),
            FutureBuilder<TunnelHealth?>(
              future: ref.read(vpnServiceProvider).readTunnelHealth(),
              builder: (context, snapshot) {
                final health = snapshot.data;
                if (health == null) {
                  return SettingsCard(
                    children: [
                      SettingsRow(
                        title: l10n.tunnelHealthUnavailable,
                        trailing: const SizedBox.shrink(),
                        height: 58,
                      ),
                    ],
                  );
                }

                return SettingsCard(
                  children: [
                    SettingsRow(
                      title: l10n.nativeStateLabel,
                      trailing: _InfoValue(value: health.nativeState),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.helperInstalledLabel,
                      trailing: _InfoValue(
                        value: health.helperInstalled ? l10n.connected : l10n.off,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.helperReachableLabel,
                      trailing: _InfoValue(
                        value: health.helperReachable ? l10n.connected : l10n.off,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.utunInterfaceLabel,
                      trailing: _InfoValue(
                        value: health.utunInterfaceName ?? l10n.off,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.routesConfiguredLabel,
                      trailing: _InfoValue(
                        value: health.routesConfigured ? l10n.connected : l10n.off,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.dnsConfiguredLabel,
                      trailing: _InfoValue(
                        value: health.dnsConfigured ? l10n.connected : l10n.off,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.memoryUsageLabel,
                      trailing: _InfoValue(
                        value: _formatBytes(health.residentMemoryBytes),
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.memoryPressureLabel,
                      trailing: _InfoValue(value: health.memoryPressure),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.lastRecoveryReasonLabel,
                      trailing: _InfoValue(
                        value: health.lastReconnectReason ?? l10n.neverLabel,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.lastRepairActionLabel,
                      trailing: _InfoValue(
                        value: health.lastRepairAction ?? l10n.neverLabel,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.lastCrashReasonLabel,
                      trailing: _InfoValue(
                        value: health.lastCrashReason ?? l10n.neverLabel,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: l10n.updatedAtLabel,
                      trailing: _InfoValue(
                        value: _formatDateTime(health.updatedAt) ??
                            l10n.neverLabel,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMtu(
    BuildContext context,
    TunnelSettings tunnelSettings,
  ) async {
    final selected = await showSettingsSelectionDialog(
      context: context,
      title: context.l10n.mtuLabel,
      options: const [
        SelectionOption(value: '1280', label: '1280'),
        SelectionOption(value: '1380', label: '1380'),
        SelectionOption(value: '1420', label: '1420'),
        SelectionOption(value: '1450', label: '1450'),
        SelectionOption(value: '1500', label: '1500'),
      ],
      selectedValue: tunnelSettings.mtu.toString(),
    );
    if (selected == null) {
      return;
    }

    _save(
      tunnelSettings.copyWith(
        mtu: int.tryParse(selected) ?? tunnelSettings.mtu,
      ),
    );
  }

  Future<void> _selectDnsMode(
    BuildContext context,
    TunnelSettings tunnelSettings,
  ) async {
    final l10n = context.l10n;
    final selected = await showSettingsSelectionDialog(
      context: context,
      title: l10n.dnsModeLabel,
      options: [
        SelectionOption(value: 'system', label: l10n.systemDnsMode),
        SelectionOption(value: 'custom', label: l10n.customDnsMode),
      ],
      selectedValue: tunnelSettings.dnsMode,
    );
    if (selected == null) {
      return;
    }

    _save(tunnelSettings.copyWith(dnsMode: selected));
  }

  Future<void> _editDnsServers(
    BuildContext context,
    TunnelSettings tunnelSettings,
  ) async {
    final rawValue = await showSettingsTextInputDialog(
      context: context,
      title: context.l10n.dnsServersDialogTitle,
      initialValue: tunnelSettings.dnsServers.join('\n'),
      minLines: 4,
      maxLines: 6,
    );
    if (rawValue == null) {
      return;
    }

    final servers = rawValue
        .split(RegExp(r'[\n,]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    if (servers.isEmpty) {
      return;
    }

    _save(tunnelSettings.copyWith(dnsServers: servers));
  }

  void _save(TunnelSettings next) {
    ref.read(settingsProvider.notifier).saveTunnelSettings(next);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String? _formatDateTime(DateTime? value) {
    if (value == null) {
      return null;
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

class _InfoValue extends StatelessWidget {
  final String value;

  const _InfoValue({required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: colors.onSurface.withValues(alpha: 0.72),
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        fontWeight: FontWeight.w400,
        height: 1,
      ),
    );
  }
}
