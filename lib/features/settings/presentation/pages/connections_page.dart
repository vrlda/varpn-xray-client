import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/connection_source.dart';
import '../../../../core/providers/connection_source_refresh_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/subscription_parser.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  bool _isBusy = false;

  Future<void> _refreshSubscriptions() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final l10n = context.l10n;
    final colors = AppTheme.colors(context);
    final hasEnabledSubscriptions = ref
        .read(settingsProvider)
        .enabledConnectionSources
        .any((source) => source.type == ConnectionSourceType.subscription);

    try {
      await ref.read(connectionSourceRefreshProvider).refreshRemoteSources();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasEnabledSubscriptions
                ? l10n.subscriptionsUpdated
                : l10n.noSubscriptionsToUpdate,
          ),
          backgroundColor: colors.connected,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.refreshSubscriptionsFailed(error)),
          backgroundColor: colors.disconnected,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _addSource() async {
    final settings = ref.read(settingsProvider);
    final type = await _showSourceTypePicker(
      context,
      showManual: settings.devMode,
    );
    if (!mounted || type == null) {
      return;
    }

    final source = type == ConnectionSourceType.manual
        ? await showDialog<ConnectionSource>(
            context: context,
            builder: (_) => const _ManualConnectionDialog(),
          )
        : await showDialog<ConnectionSource>(
            context: context,
            builder: (_) => _ConnectionInputDialog(type: type),
          );

    if (!mounted || source == null) {
      return;
    }

    ref.read(settingsProvider.notifier).upsertConnectionSource(source);
  }

  Future<void> _editSource(ConnectionSource source) async {
    final settings = ref.read(settingsProvider);
    if (source.type == ConnectionSourceType.manual && !settings.devMode) {
      return;
    }

    final updated = source.type == ConnectionSourceType.manual
        ? await showDialog<ConnectionSource>(
            context: context,
            builder: (_) => _ManualConnectionDialog(existing: source),
          )
        : await showDialog<ConnectionSource>(
            context: context,
            builder: (_) => _ConnectionInputDialog(
              type: source.type,
              existing: source,
            ),
          );

    if (!mounted || updated == null) {
      return;
    }

    ref.read(settingsProvider.notifier).upsertConnectionSource(
          updated.copyWith(
            enabled: source.enabled,
            updatedAt: source.updatedAt,
            lastRefreshError: source.lastRefreshError,
          ),
        );
  }

  Future<void> _removeSource(ConnectionSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final colors = AppTheme.colors(dialogContext);
        return AlertDialog(
          backgroundColor: colors.card,
          title: Text(
            l10n.removeConnectionTitle,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            l10n.removeConnectionMessage(source.resolvedName),
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 15,
              fontFamily: '.SF Pro Text',
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.remove,
                style: TextStyle(color: colors.disconnected),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    ref.read(settingsProvider.notifier).removeConnectionSource(source.id);
  }

  void _toggleSource(ConnectionSource source, bool enabled) {
    ref
        .read(settingsProvider.notifier)
        .setConnectionSourceEnabled(source.id, enabled);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final sources = settings.connectionSources;

    return SettingsPageShell(
      title: l10n.connections,
      onBack: () => context.pop(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsCircleButton(
            onTap: _isBusy ? () {} : _refreshSubscriptions,
            child: Icon(
              Icons.refresh_rounded,
              color: colors.text,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          SettingsCircleButton(
            onTap: _isBusy ? () {} : _addSource,
            child: Icon(
              Icons.add_rounded,
              color: colors.text,
              size: 22,
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: l10n.connections),
            const SizedBox(height: 14),
            if (sources.isEmpty)
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                    child: Text(
                      l10n.noConnectionsAdded,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 15,
                        fontFamily: '.SF Pro Text',
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (var i = 0; i < sources.length; i++) ...[
                    _ConnectionSourceTile(
                      source: sources[i],
                      enabled: sources[i].enabled,
                      onToggle: (value) => _toggleSource(sources[i], value),
                      onEdit: () => _editSource(sources[i]),
                      onRemove: () => _removeSource(sources[i]),
                      allowEdit:
                          sources[i].type != ConnectionSourceType.manual ||
                              settings.devMode,
                    ),
                    if (i != sources.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSourceTile extends StatelessWidget {
  final ConnectionSource source;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool allowEdit;

  const _ConnectionSourceTile({
    required this.source,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    required this.allowEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final subtitle = _subtitleFor(source, l10n);
    final meta = _metaFor(source, l10n);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.72,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: AppTheme.glassPanel(
          context,
          radius: 22,
          baseColor: enabled
              ? Color.lerp(colors.card, colors.surfaceElevated, 0.16)
              : colors.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.resolvedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 18,
                            fontFamily: '.SF Pro Text',
                            fontWeight: FontWeight.w500,
                            height: 1,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TypePill(label: _typeLabel(source, l10n)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 14,
                      fontFamily: '.SF Pro Text',
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: source.lastRefreshError != null
                            ? colors.disconnected.withValues(alpha: 0.86)
                            : colors.mutedText.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontFamily: '.SF Pro Text',
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SourceToggle(
                        value: enabled,
                        onChanged: onToggle,
                      ),
                      const SizedBox(width: 12),
                      if (allowEdit)
                        _TileActionButton(
                          icon: Icons.edit_rounded,
                          onTap: onEdit,
                        ),
                      if (allowEdit) const SizedBox(width: 8),
                      _TileActionButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: onRemove,
                        color: colors.disconnected,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(ConnectionSource source, AppLocalizations l10n) {
    switch (source.type) {
      case ConnectionSourceType.subscription:
        return '${l10n.subscriptionSourceLabel} • ${_compactInput(source.input)}';
      case ConnectionSourceType.configLink:
        return '${l10n.configSourceLabel} • ${_compactInput(source.input)}';
      case ConnectionSourceType.manual:
        final config = source.manualConfig;
        if (config == null) {
          return l10n.manualSourceLabel;
        }
        return '${l10n.manualSourceLabel} • ${config.protocol.toUpperCase()} • ${config.server}:${config.port}';
    }
  }

  String _typeLabel(ConnectionSource source, AppLocalizations l10n) {
    return switch (source.type) {
      ConnectionSourceType.subscription => l10n.subscriptionSourceLabel,
      ConnectionSourceType.configLink => l10n.configSourceLabel,
      ConnectionSourceType.manual => l10n.manualSourceLabel,
    };
  }

  String? _metaFor(ConnectionSource source, AppLocalizations l10n) {
    if (source.lastRefreshError != null &&
        source.lastRefreshError!.trim().isNotEmpty) {
      return source.lastRefreshError!.trim();
    }

    final updatedAt = source.updatedAt;
    if (updatedAt == null) {
      return null;
    }

    return l10n.lastUpdatedLabel(_formatDateTime(updatedAt));
  }

  String _compactInput(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 72) {
      return trimmed;
    }
    return '${trimmed.substring(0, 69)}...';
  }
}

class _TypePill extends StatelessWidget {
  final String label;

  const _TypePill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 11,
          fontFamily: '.SF Pro Text',
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _TileActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _TileActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final isDestructive = color != null;
    final backgroundColor = isDestructive
        ? colors.disconnected.withValues(alpha: 0.14)
        : Color.lerp(colors.surfaceElevated, colors.card, 0.18) ??
            colors.surfaceElevated;
    final borderColor = isDestructive
        ? colors.disconnected.withValues(alpha: 0.26)
        : colors.panelStroke.withValues(alpha: 0.9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          icon,
          size: 19,
          color: color ?? colors.text.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _SourceToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SourceToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SourceToggle> createState() => _SourceToggleState();
}

class _SourceToggleState extends State<_SourceToggle>
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
  void didUpdateWidget(covariant _SourceToggle oldWidget) {
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

Future<ConnectionSourceType?> _showSourceTypePicker(
  BuildContext context, {
  required bool showManual,
}) {
  final l10n = context.l10n;
  final colors = AppTheme.colors(context);

  return showModalBottomSheet<ConnectionSourceType>(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PickerOption(
                title: l10n.subscriptionSourceLabel,
                subtitle: l10n.subscriptionSourceHint,
                onTap: () => Navigator.of(sheetContext).pop(
                  ConnectionSourceType.subscription,
                ),
              ),
              const SizedBox(height: 10),
              _PickerOption(
                title: l10n.configSourceLabel,
                subtitle: l10n.configSourceHint,
                onTap: () => Navigator.of(sheetContext).pop(
                  ConnectionSourceType.configLink,
                ),
              ),
              if (showManual) ...[
                const SizedBox(height: 10),
                _PickerOption(
                  title: l10n.manualSourceLabel,
                  subtitle: l10n.manualSourceHint,
                  onTap: () => Navigator.of(sheetContext).pop(
                    ConnectionSourceType.manual,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PickerOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickerOption({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: AppTheme.glassPanel(
          context,
          radius: 20,
          baseColor: colors.surfaceElevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 14,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionInputDialog extends StatefulWidget {
  final ConnectionSourceType type;
  final ConnectionSource? existing;

  const _ConnectionInputDialog({
    required this.type,
    this.existing,
  });

  @override
  State<_ConnectionInputDialog> createState() => _ConnectionInputDialogState();
}

class _ConnectionInputDialogState extends State<_ConnectionInputDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _inputController =
        TextEditingController(text: widget.existing?.input ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? SubscriptionParser.suggestSourceName(input)
        : _nameController.text.trim();

    Navigator.of(context).pop(
      ConnectionSource(
        id: widget.existing?.id ??
            'source_${DateTime.now().microsecondsSinceEpoch}_${input.hashCode.abs()}',
        type: widget.type,
        name: name,
        input: input,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final isSubscription = widget.type == ConnectionSourceType.subscription;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.panelStroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSubscription
                  ? l10n.subscriptionSourceLabel
                  : l10n.configSourceLabel,
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _DialogLabel(text: l10n.sourceNameLabel),
            const SizedBox(height: 8),
            _DialogField(
              controller: _nameController,
              hintText: l10n.sourceNameHint,
            ),
            const SizedBox(height: 16),
            _DialogLabel(text: l10n.sourceInputLabel),
            const SizedBox(height: 8),
            _DialogField(
              controller: _inputController,
              hintText: isSubscription
                  ? l10n.subscriptionSourceHint
                  : l10n.configSourceHint,
              maxLines: 6,
              minLines: 4,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.chipSelected,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.saveAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualConnectionDialog extends StatefulWidget {
  final ConnectionSource? existing;

  const _ManualConnectionDialog({
    this.existing,
  });

  @override
  State<_ManualConnectionDialog> createState() =>
      _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<_ManualConnectionDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _serverController;
  late final TextEditingController _portController;
  late final TextEditingController _credentialController;
  late final TextEditingController _encryptionController;
  late final TextEditingController _flowController;
  late final TextEditingController _sniController;
  late final TextEditingController _pathController;
  late final TextEditingController _hostController;
  late final TextEditingController _pubKeyController;
  late final TextEditingController _shortIdController;
  late final TextEditingController _fingerprintController;
  late final TextEditingController _alpnController;
  late final TextEditingController _extraJsonController;

  late String _protocol;
  late String _network;
  late String _security;
  bool _allowInsecure = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing?.manualConfig;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _serverController = TextEditingController(text: existing?.server ?? '');
    _portController = TextEditingController(
      text: (existing?.port ?? 443).toString(),
    );
    _credentialController = TextEditingController(
      text: existing?.credential ?? '',
    );
    _encryptionController = TextEditingController(
      text: existing?.encryption ?? 'none',
    );
    _flowController = TextEditingController(text: existing?.flow ?? '');
    _sniController = TextEditingController(text: existing?.sni ?? '');
    _pathController = TextEditingController(text: existing?.path ?? '');
    _hostController = TextEditingController(text: existing?.host ?? '');
    _pubKeyController = TextEditingController(
      text: existing?.realityPubKey ?? '',
    );
    _shortIdController = TextEditingController(
      text: existing?.realityShortId ?? '',
    );
    _fingerprintController = TextEditingController(
      text: existing?.fingerprint ?? '',
    );
    _alpnController = TextEditingController(text: existing?.alpn ?? '');
    _extraJsonController =
        TextEditingController(text: existing?.extraJson ?? '');
    _protocol = existing?.protocol ?? 'vless';
    _network = existing?.network ?? 'tcp';
    _security = existing?.security ?? 'none';
    _allowInsecure = existing?.allowInsecure ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _credentialController.dispose();
    _encryptionController.dispose();
    _flowController.dispose();
    _sniController.dispose();
    _pathController.dispose();
    _hostController.dispose();
    _pubKeyController.dispose();
    _shortIdController.dispose();
    _fingerprintController.dispose();
    _alpnController.dispose();
    _extraJsonController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final server = _serverController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;
    final credential = _credentialController.text.trim();
    if (name.isEmpty || server.isEmpty || port <= 0 || credential.isEmpty) {
      return;
    }

    final config = ManualConnectionConfig(
      name: name,
      protocol: _protocol,
      server: server,
      port: port,
      credential: credential,
      encryption: _encryptionController.text.trim().isEmpty
          ? 'none'
          : _encryptionController.text.trim(),
      network: _network,
      security: _security,
      flow: _flowController.text.trim(),
      sni: _sniController.text.trim(),
      path: _pathController.text.trim(),
      host: _hostController.text.trim(),
      realityPubKey: _pubKeyController.text.trim(),
      realityShortId: _shortIdController.text.trim(),
      fingerprint: _fingerprintController.text.trim(),
      alpn: _alpnController.text.trim(),
      extraJson: _extraJsonController.text.trim(),
      allowInsecure: _allowInsecure,
    );

    Navigator.of(context).pop(
      ConnectionSource(
        id: widget.existing?.id ??
            'manual_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}',
        type: ConnectionSourceType.manual,
        name: name,
        manualConfig: config,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.panelStroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.manualSourceLabel,
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  runSpacing: 14,
                  spacing: 14,
                  children: [
                    _WideField(
                      child: _DialogField(
                        controller: _nameController,
                        hintText: l10n.sourceNameHint,
                        label: l10n.sourceNameLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DropdownField(
                        label: l10n.protocolLabel,
                        value: _protocol,
                        items: const ['vless', 'vmess', 'trojan', 'ss'],
                        onChanged: (value) => setState(() => _protocol = value),
                      ),
                    ),
                    _HalfField(
                      child: _DropdownField(
                        label: l10n.networkLabel,
                        value: _network,
                        items: const ['tcp', 'xhttp', 'grpc', 'ws'],
                        onChanged: (value) => setState(() => _network = value),
                      ),
                    ),
                    _HalfField(
                      child: _DropdownField(
                        label: l10n.securityLabel,
                        value: _security,
                        items: const ['none', 'tls', 'reality'],
                        onChanged: (value) => setState(() => _security = value),
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _encryptionController,
                        hintText: 'none',
                        label: l10n.encryptionLabel,
                      ),
                    ),
                    _WideField(
                      child: _DialogField(
                        controller: _serverController,
                        hintText: 'server.example.com',
                        label: l10n.serverAddressLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _portController,
                        hintText: '443',
                        label: l10n.portLabel,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _credentialController,
                        hintText: l10n.credentialHint,
                        label: l10n.credentialLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _flowController,
                        hintText: 'xtls-rprx-vision',
                        label: l10n.flowLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _sniController,
                        hintText: 'example.com',
                        label: l10n.sniLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _pathController,
                        hintText: '/ or serviceName',
                        label: l10n.pathLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _hostController,
                        hintText: 'authority / host',
                        label: l10n.hostLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _pubKeyController,
                        hintText: l10n.publicKeyHint,
                        label: l10n.publicKeyLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _shortIdController,
                        hintText: 'short id',
                        label: l10n.shortIdLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _fingerprintController,
                        hintText: 'chrome',
                        label: l10n.fingerprintLabel,
                      ),
                    ),
                    _HalfField(
                      child: _DialogField(
                        controller: _alpnController,
                        hintText: 'h2,http/1.1',
                        label: l10n.alpnLabel,
                      ),
                    ),
                    _WideField(
                      child: _DialogField(
                        controller: _extraJsonController,
                        hintText: l10n.extraJsonHint,
                        label: l10n.extraJsonLabel,
                        minLines: 3,
                        maxLines: 5,
                      ),
                    ),
                    _WideField(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        title: Text(
                          l10n.allowInsecureLabel,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 16,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                        value: _allowInsecure,
                        onChanged: (value) =>
                            setState(() => _allowInsecure = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.chipSelected,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.saveAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  final String text;

  const _DialogLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.colors(context).mutedText,
        fontSize: 14,
        fontFamily: '.SF Pro Text',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;

  const _DialogField({
    required this.controller,
    required this.hintText,
    this.label,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          _DialogLabel(text: label!),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          minLines: minLines ?? 1,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontFamily: '.SF Pro Text',
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: colors.mutedText),
            filled: true,
            fillColor: colors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel(text: label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: colors.card,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _WideField extends StatelessWidget {
  final Widget child;

  const _WideField({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 512,
      child: child,
    );
  }
}

class _HalfField extends StatelessWidget {
  final Widget child;

  const _HalfField({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 249,
      child: child,
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}
