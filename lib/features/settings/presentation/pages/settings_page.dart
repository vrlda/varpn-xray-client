import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/server_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/usage_stats_provider.dart';
import '../../../../core/providers/vpn_provider.dart';
import '../../../../core/services/app_log_service.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _developerUnlockTaps = 0;

  void _handleTitleTap() {
    final settings = ref.read(settingsProvider);
    if (settings.developerToolsUnlocked) {
      return;
    }

    _developerUnlockTaps += 1;
    if (_developerUnlockTaps < 7) {
      return;
    }

    _developerUnlockTaps = 0;
    ref.read(settingsProvider.notifier).unlockDeveloperTools();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.developerToolsUnlocked),
        backgroundColor: AppTheme.colors(context).connected,
      ),
    );
  }

  Future<void> _resetAppData() async {
    final confirmed = await _showConfirmationDialog(
      context: context,
      title: context.l10n.resetAppTitle,
      message: context.l10n.resetAppMessage,
      confirmLabel: context.l10n.resetAppAction,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(vpnConnectionProvider.notifier).disconnect();
    } catch (_) {
      // Keep the reset flow moving even if the proxy runtime is already down.
    }

    ref.read(selectedServerProvider.notifier).clearSelection();
    ref.read(serverListProvider.notifier).clear();
    await ref.read(usageStatsProvider.notifier).reset();
    ref.read(appLogsProvider.notifier).clear();
    ref.read(settingsProvider.notifier).resetAll();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.resetCompleted),
        backgroundColor: AppTheme.colors(context).connected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final subscriptionLabel = _formatConnectionsLabel(settings, l10n);
    final pingLabel = _formatPingProtocolLabel(
      settings.pingSettings.protocol,
      l10n,
    );
    final showDeveloperControls =
        settings.developerToolsUnlocked || settings.devMode;
    final showProOnlyRows = settings.devMode;
    final xrayLabel = _formatXrayLabel(settings, l10n);
    const showTunnelRow = true;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 102, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(title: l10n.interfaceSection),
                        const SizedBox(height: 20),
                        _SettingsCard(
                          children: [
                            _SettingsRow(
                              title: l10n.language,
                              trailing: _ValueChevron(
                                value: l10n.languageName(settings.language),
                              ),
                              onTap: () async {
                                final selected = await _showSelectionDialog(
                                  context: context,
                                  title: l10n.languageSelectionTitle,
                                  options: [
                                    _SelectionOption(
                                      value: 'ru',
                                      label: l10n.languageName('ru'),
                                    ),
                                    _SelectionOption(
                                      value: 'en',
                                      label: l10n.languageName('en'),
                                    ),
                                  ],
                                  selectedValue: settings.language,
                                );
                                if (selected == null) {
                                  return;
                                }
                                ref
                                    .read(settingsProvider.notifier)
                                    .setLanguage(selected);
                              },
                            ),
                            const _SettingsDivider(),
                            _SettingsRow(
                              title: l10n.appearanceTheme,
                              trailing: _ValueChevron(
                                value: l10n.themeName(settings.theme),
                              ),
                              onTap: () async {
                                final selected = await _showSelectionDialog(
                                  context: context,
                                  title: l10n.themeSelectionTitle,
                                  options: [
                                    _SelectionOption(
                                      value: 'system',
                                      label: l10n.themeName('system'),
                                    ),
                                    _SelectionOption(
                                      value: 'light',
                                      label: l10n.themeName('light'),
                                    ),
                                    _SelectionOption(
                                      value: 'dark',
                                      label: l10n.themeName('dark'),
                                    ),
                                  ],
                                  selectedValue: settings.theme,
                                );
                                if (selected == null) {
                                  return;
                                }
                                ref.read(settingsProvider.notifier).setTheme(
                                      selected,
                                    );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionLabel(title: l10n.detailsSection),
                        const SizedBox(height: 20),
                        _SettingsCard(
                          children: [
                            _SettingsRow(
                              title: l10n.statistics,
                              onTap: () => context.push('/settings/statistics'),
                            ),
                            const _SettingsDivider(),
                            _SettingsRow(
                              title: l10n.faq,
                              onTap: () => context.push('/settings/faq'),
                            ),
                            const _SettingsDivider(),
                            _SettingsRow(
                              title: l10n.aboutApp,
                              onTap: () => context.push('/settings/about'),
                            ),
                            const _SettingsDivider(),
                            _SettingsRow(
                              title: l10n.reset,
                              onTap: _resetAppData,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDeveloperControls) ...[
                          const SizedBox(height: 20),
                          _SettingsCard(
                            children: [
                              _SettingsRow(
                                title: l10n.developerMode,
                                trailing: _CustomToggle(
                                  value: settings.devMode,
                                  onChanged: (value) => ref
                                      .read(settingsProvider.notifier)
                                      .setDevMode(value),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                        _SectionLabel(title: l10n.advancedSettings),
                        const SizedBox(height: 20),
                        _SettingsCard(
                          children: [
                            _SettingsRow(
                              title: l10n.routesAndRules,
                              trailing: _ValueChevron(
                                value: settings.routingSettings.enabled
                                    ? l10n.routingPresetName(
                                        settings.routingSettings.selectedPreset
                                            .name,
                                      )
                                    : l10n.off,
                              ),
                              onTap: () => context.push('/settings/routes'),
                            ),
                            const _SettingsDivider(),
                            if (showTunnelRow) ...[
                              _SettingsRow(
                                title: l10n.tunnel,
                                trailing: _ValueChevron(
                                  value: _formatTunnelLabel(settings, l10n),
                                ),
                                onTap: () => context.push('/settings/tunnel'),
                              ),
                              const _SettingsDivider(),
                            ],
                            _SettingsRow(
                              title: l10n.connections,
                              trailing: _ValueChevron(value: subscriptionLabel),
                              onTap: () =>
                                  context.push('/settings/connections'),
                            ),
                            if (showProOnlyRows) ...[
                              const _SettingsDivider(),
                              _SettingsRow(
                                title: l10n.xray,
                                trailing: _ValueChevron(value: xrayLabel),
                                onTap: () => context.push('/settings/xray'),
                              ),
                              const _SettingsDivider(),
                              _SettingsRow(
                                title: l10n.ping,
                                trailing: _ValueChevron(value: pingLabel),
                                onTap: () => context.push('/settings/ping'),
                              ),
                              const _SettingsDivider(),
                              _SettingsRow(
                                title: l10n.logs,
                                onTap: () => context.push('/settings/logs'),
                              ),
                            ],
                          ],
                        ),
                        if (!showDeveloperControls)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 12),
                            child: Text(
                              l10n.developerToolsHiddenHint,
                              style: TextStyle(
                                color: colors.mutedText,
                                fontSize: 13,
                                fontFamily: '.SF Pro Text',
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: _handleTitleTap,
              behavior: HitTestBehavior.translucent,
              child: Text(
                l10n.settingsTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w500,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: 24,
            child: _GlassBackButton(
              onTap: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatConnectionsLabel(SettingsState settings, AppLocalizations l10n) {
  final sources = settings.connectionSources;
  if (sources.isEmpty) {
    return l10n.notAdded;
  }

  final enabled = settings.enabledConnectionSources;
  if (enabled.length == 1 && sources.length == 1) {
    final name = enabled.first.resolvedName.trim();
    if (name.isNotEmpty) {
      return name;
    }
  }

  return l10n.enabledSourcesLabel(enabled.length, sources.length);
}

String _formatPingProtocolLabel(String protocol, AppLocalizations l10n) {
  return switch (protocol) {
    'proxy_get' => l10n.proxyGetMethod,
    'proxy_head' => l10n.proxyHeadMethod,
    'icmp' => l10n.icmpMethod,
    _ => l10n.tcpMethod,
  };
}

String _formatTunnelLabel(SettingsState settings, AppLocalizations l10n) {
  final tunnelSettings = settings.tunnelSettings;
  final dnsLabel = tunnelSettings.dnsMode == 'system'
      ? l10n.systemDnsMode
      : l10n.customDnsMode;
  final ipv6Label = tunnelSettings.ipv6Enabled ? 'IPv6' : 'IPv4';
  return '$ipv6Label • $dnsLabel';
}

String _formatXrayLabel(SettingsState settings, AppLocalizations l10n) {
  final xraySettings = settings.xraySettings;
  final transport = switch (xraySettings.transportOverride) {
    'tcp' => l10n.tcpTransport,
    'grpc' => l10n.grpcTransport,
    'xhttp' => l10n.xhttpTransport,
    _ => l10n.autoTransport,
  };
  final logLevel = switch (xraySettings.logLevel) {
    'error' => l10n.errorLogLevel,
    'info' => l10n.infoLogLevel,
    'debug' => l10n.debugLogLevel,
    _ => l10n.warningLogLevel,
  };
  return '$transport • $logLevel';
}

Future<String?> _showSelectionDialog({
  required BuildContext context,
  required String title,
  required List<_SelectionOption> options,
  required String selectedValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = AppTheme.colors(dialogContext);

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.text.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SelectionButton(
                    label: option.label,
                    isSelected: option.value == selectedValue,
                    onTap: () => Navigator.of(dialogContext).pop(option.value),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> _showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = AppTheme.colors(dialogContext);
      final l10n = dialogContext.l10n;

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.text.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 14,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DialogActionButton(
                      label: l10n.cancel,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogActionButton(
                      label: confirmLabel,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                      isPrimary: true,
                      isDestructive: isDestructive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassBackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            radius: 30,
            child: Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: AppTheme.glassPanel(
                      context,
                      radius: 22,
                      shape: BoxShape.circle,
                      baseColor: colors.card.withValues(alpha: 0.8),
                      glowColor: colors.ambientPrimary,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/chevron.left.svg',
                        width: 8,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          colors.text,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.colors(context).mutedText,
        fontSize: 18,
        fontFamily: '.SF Pro Text',
        fontWeight: FontWeight.w400,
        height: 1,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassPanel(
        context,
        radius: 22,
        baseColor: AppTheme.colors(context).card,
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    final content = SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: colors.mutedText,
                size: 18,
              ),
        ],
      ),
    );

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: content,
    );

    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.colors(context).divider,
      ),
    );
  }
}

class _ValueChevron extends StatelessWidget {
  final String value;

  const _ValueChevron({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 18,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w400,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right_rounded,
          color: colors.mutedText,
          size: 18,
        ),
      ],
    );
  }
}

class _CustomToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CustomToggle> createState() => _CustomToggleState();
}

class _CustomToggleState extends State<_CustomToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _knobAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
    _knobAnimation = Tween<double>(begin: 2, end: 20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _CustomToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 56,
            height: 26,
            decoration: BoxDecoration(
              color: Color.lerp(
                colors.chip,
                colors.connected,
                _controller.value,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: _knobAnimation.value,
                  top: 2,
                  child: Container(
                    width: 34,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.chipSelected : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.text,
            fontSize: 16,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SelectionOption {
  final String value;
  final String label;

  const _SelectionOption({
    required this.value,
    required this.label,
  });
}

class _DialogActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _DialogActionButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final backgroundColor = isPrimary
        ? (isDestructive ? colors.disconnected : colors.chipSelected)
        : colors.surfaceElevated;
    final textColor = isPrimary ? Colors.white : colors.text;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
