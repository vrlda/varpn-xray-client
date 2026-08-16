import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/routing_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/geodata_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class RoutingPresetPage extends ConsumerStatefulWidget {
  final String presetId;

  const RoutingPresetPage({
    super.key,
    required this.presetId,
  });

  @override
  ConsumerState<RoutingPresetPage> createState() => _RoutingPresetPageState();
}

class _RoutingPresetPageState extends ConsumerState<RoutingPresetPage> {
  bool _isRefreshingGeodata = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMetadataIfNeeded();
    });
  }

  Future<void> _syncMetadataIfNeeded() async {
    final current = ref.read(settingsProvider).routingSettings;
    if (current.geositeUpdatedAt != null && current.geoipUpdatedAt != null) {
      return;
    }

    try {
      final updated = await GeodataService.fetchLatestMetadata(current);
      ref.read(settingsProvider.notifier).saveRoutingSettings(updated);
    } catch (_) {
      // Keep bundled geodata metadata empty if GitHub is unreachable.
    }
  }

  void _savePreset(RoutingPresetConfig preset) {
    final settings = ref.read(settingsProvider).routingSettings;
    ref.read(settingsProvider.notifier).saveRoutingSettings(
          settings.updatePreset(preset),
        );
  }

  Future<void> _editTextSetting({
    required String title,
    required String initialValue,
    required RoutingPresetConfig preset,
    required RoutingPresetConfig Function(String value) update,
  }) async {
    final value = await showSettingsTextInputDialog(
      context: context,
      title: title,
      initialValue: initialValue,
    );

    if (value == null || !mounted) {
      return;
    }

    _savePreset(update(value));
  }

  Future<void> _refreshGeodata(RoutingSettings settings) async {
    if (_isRefreshingGeodata) {
      return;
    }

    setState(() {
      _isRefreshingGeodata = true;
    });

    try {
      final updated = await GeodataService.refreshGeodata(settings);
      ref.read(settingsProvider.notifier).saveRoutingSettings(updated);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.geodataUpdated)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.refreshFailed(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingGeodata = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).routingSettings;
    final preset =
        settings.findPreset(widget.presetId) ?? settings.selectedPreset;

    return SettingsPageShell(
      title: l10n.routingPresetName(preset.name),
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.resourcesSection),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _GeodataRow(
                  title: 'geosite',
                  sizeLabel: _formatBytes(settings.geositeBytes),
                  url: settings.geositeUrl,
                  lastUpdatedLabel:
                      _formatDateTime(context, settings.geositeUpdatedAt),
                  isRefreshing: _isRefreshingGeodata,
                  onRefresh: () => _refreshGeodata(settings),
                ),
                const SettingsDivider(),
                _GeodataRow(
                  title: 'geoip',
                  sizeLabel: _formatBytes(settings.geoipBytes),
                  url: settings.geoipUrl,
                  lastUpdatedLabel:
                      _formatDateTime(context, settings.geoipUpdatedAt),
                  isRefreshing: _isRefreshingGeodata,
                  onRefresh: () => _refreshGeodata(settings),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsSectionLabel(title: l10n.editRules),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.trimGeofiles,
                  trailing: SettingsToggle(
                    value: preset.trimGeofiles,
                    onChanged: (value) =>
                        _savePreset(preset.copyWith(trimGeofiles: value)),
                  ),
                  height: 58,
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.editRules,
                  onTap: () => context.push(
                    '/settings/routes/preset/${preset.id}/distribution',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsSectionLabel(title: l10n.domainSettings),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.enableFakeDns,
                  trailing: SettingsToggle(
                    value: preset.fakeDnsEnabled,
                    onChanged: (value) =>
                        _savePreset(preset.copyWith(fakeDnsEnabled: value)),
                  ),
                  height: 58,
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.domainStrategyLabel,
                  trailing: SettingsValueChevron(value: preset.domainStrategy),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.domainStrategyLabel,
                      options: const [
                        SelectionOption(value: 'AsIs', label: 'AsIs'),
                        SelectionOption(
                          value: 'IPIfNonMatch',
                          label: 'IPIfNonMatch',
                        ),
                        SelectionOption(
                          value: 'IPOnDemand',
                          label: 'IPOnDemand',
                        ),
                      ],
                      selectedValue: preset.domainStrategy,
                    );
                    if (selected == null || !mounted) {
                      return;
                    }
                    _savePreset(preset.copyWith(domainStrategy: selected));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsSectionLabel(title: l10n.remoteDns),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.dnsType,
                  trailing: SettingsValueChevron(value: preset.remoteDnsType),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.dnsType,
                      options: const [
                        SelectionOption(value: 'DoH', label: 'DoH'),
                        SelectionOption(value: 'DoU', label: 'DoU'),
                        SelectionOption(value: 'Plain', label: 'Plain'),
                      ],
                      selectedValue: preset.remoteDnsType,
                    );
                    if (selected == null || !mounted) {
                      return;
                    }
                    _savePreset(preset.copyWith(remoteDnsType: selected));
                  },
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.dnsAddress,
                  trailing: SettingsValueChevron(value: preset.remoteDnsValue),
                  onTap: () => _editTextSetting(
                    title: l10n.dnsAddress,
                    initialValue: preset.remoteDnsValue,
                    preset: preset,
                    update: (value) => preset.copyWith(remoteDnsValue: value),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.dnsBootstrapIp,
                  trailing: SettingsValueChevron(value: preset.remoteDnsIp),
                  onTap: () => _editTextSetting(
                    title: l10n.dnsBootstrapIp,
                    initialValue: preset.remoteDnsIp,
                    preset: preset,
                    update: (value) => preset.copyWith(remoteDnsIp: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsSectionLabel(title: l10n.domesticDns),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.dnsType,
                  trailing: SettingsValueChevron(value: preset.domesticDnsType),
                  onTap: () async {
                    final selected = await showSettingsSelectionDialog(
                      context: context,
                      title: l10n.dnsType,
                      options: const [
                        SelectionOption(value: 'DoH', label: 'DoH'),
                        SelectionOption(value: 'DoU', label: 'DoU'),
                        SelectionOption(value: 'Plain', label: 'Plain'),
                      ],
                      selectedValue: preset.domesticDnsType,
                    );
                    if (selected == null || !mounted) {
                      return;
                    }
                    _savePreset(preset.copyWith(domesticDnsType: selected));
                  },
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.dnsAddress,
                  trailing: SettingsValueChevron(
                    value: preset.domesticDnsValue,
                  ),
                  onTap: () => _editTextSetting(
                    title: l10n.dnsAddress,
                    initialValue: preset.domesticDnsValue,
                    preset: preset,
                    update: (value) => preset.copyWith(domesticDnsValue: value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '--';
    }

    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(2)} MB';
  }

  String _formatDateTime(BuildContext context, DateTime? value) {
    if (value == null) {
      return '--';
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return context.l10n.lastUpdatedLabel(formatter.format(value.toLocal()));
  }
}

class _GeodataRow extends StatelessWidget {
  final String title;
  final String sizeLabel;
  final String url;
  final String lastUpdatedLabel;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _GeodataRow({
    required this.title,
    required this.sizeLabel,
    required this.url,
    required this.lastUpdatedLabel,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontFamily: '.SF Pro Text',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      sizeLabel,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 14,
                        fontFamily: '.SF Pro Text',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lastUpdatedLabel,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 13,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.chipSelected,
                      ),
                    ),
                  )
                : Icon(
                    Icons.sync_rounded,
                    color: colors.mutedText,
                  ),
          ),
        ],
      ),
    );
  }
}
