import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/usage_stats_provider.dart';
import '../../../../core/providers/vpn_provider.dart';
import '../../../../core/services/vpn_service.dart';
import '../widgets/settings_common.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _syncTick = 0;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(usageStatsProvider.notifier).syncTrafficStats());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      _syncTick += 1;
      if (_syncTick % 3 == 0) {
        unawaited(ref.read(usageStatsProvider.notifier).syncTrafficStats());
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = ref.watch(usageStatsProvider);
    final connectionStatus = ref.watch(vpnConnectionProvider);
    final currentSessionSeconds = stats.currentSessionStartedAt == null
        ? 0
        : _now
            .difference(stats.currentSessionStartedAt!)
            .inSeconds
            .clamp(0, 2147483647);
    final currentSessionTrafficBytes =
        stats.currentSessionUplinkBytes + stats.currentSessionDownlinkBytes;
    final totalTrafficBytes = stats.totalUplinkBytes + stats.totalDownlinkBytes;
    final lastSessionTrafficBytes =
        stats.lastSessionUplinkBytes + stats.lastSessionDownlinkBytes;

    return SettingsPageShell(
      title: l10n.statistics,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.currentSessionSection),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _StatsRow(
                  label: l10n.statusLabel,
                  value: _statusLabel(
                    l10n: l10n,
                    status: connectionStatus,
                  ),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.serverLabel,
                  value: stats.currentSessionServerName ??
                      stats.lastServerName ??
                      l10n.notAdded,
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.currentSessionLabel,
                  value: stats.currentSessionStartedAt == null
                      ? l10n.notConnectedLabel
                      : _formatDuration(currentSessionSeconds),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.sessionTrafficLabel,
                  value: _formatBytes(currentSessionTrafficBytes),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.uploadedLabel,
                  value: _formatBytes(stats.currentSessionUplinkBytes),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.downloadedLabel,
                  value: _formatBytes(stats.currentSessionDownlinkBytes),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SettingsSectionLabel(title: l10n.lifetimeSection),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _StatsRow(
                  label: l10n.totalTrafficLabel,
                  value: _formatBytes(totalTrafficBytes),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.uploadedLabel,
                  value: _formatBytes(stats.totalUplinkBytes),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.downloadedLabel,
                  value: _formatBytes(stats.totalDownlinkBytes),
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.lastSessionLabel,
                  value: lastSessionTrafficBytes > 0
                      ? _formatBytes(lastSessionTrafficBytes)
                      : l10n.neverLabel,
                ),
                const SettingsDivider(),
                _StatsRow(
                  label: l10n.lastConnectedLabel,
                  value:
                      _formatDateTime(stats.lastConnectedAt) ?? l10n.neverLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    final fractionDigits = unitIndex == 0 ? 0 : (value >= 100 ? 0 : 2);
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  String? _formatDateTime(DateTime? value) {
    if (value == null) {
      return null;
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _statusLabel({
    required AppLocalizations l10n,
    required ConnectionStatus status,
  }) {
    switch (status) {
      case ConnectionStatus.connected:
        return l10n.connected;
      case ConnectionStatus.connecting:
        return l10n.connecting;
      case ConnectionStatus.error:
        return l10n.error;
      case ConnectionStatus.disconnecting:
      case ConnectionStatus.disconnected:
        return l10n.disconnected;
    }
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatsRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SettingsRow(
      title: label,
      trailing: Text(
        value,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.72),
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
