import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/routing_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

enum RuleEditorKind {
  proxy,
  direct,
  block,
}

extension RuleEditorKindParsing on RuleEditorKind {
  static RuleEditorKind fromPath(String? value) {
    switch (value) {
      case 'direct':
        return RuleEditorKind.direct;
      case 'block':
        return RuleEditorKind.block;
      case 'proxy':
      default:
        return RuleEditorKind.proxy;
    }
  }

  String toPath() {
    return switch (this) {
      RuleEditorKind.proxy => 'proxy',
      RuleEditorKind.direct => 'direct',
      RuleEditorKind.block => 'block',
    };
  }
}

class RuleEditorPage extends ConsumerStatefulWidget {
  final String presetId;
  final RuleEditorKind kind;

  const RuleEditorPage({
    super.key,
    required this.presetId,
    required this.kind,
  });

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final routingSettings = ref.read(settingsProvider).routingSettings;
    final preset = routingSettings.findPreset(widget.presetId) ??
        routingSettings.selectedPreset;
    _controller = TextEditingController(
      text: _currentRules(preset),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(settingsProvider.notifier);
    final routingSettings = ref.read(settingsProvider).routingSettings;
    final preset = routingSettings.findPreset(widget.presetId) ??
        routingSettings.selectedPreset;
    final draft = _controller.text.trim();

    final updated = switch (widget.kind) {
      RuleEditorKind.proxy => preset.copyWith(proxyRules: draft),
      RuleEditorKind.direct => preset.copyWith(directRules: draft),
      RuleEditorKind.block => preset.copyWith(blockRules: draft),
    };

    notifier.saveRoutingSettings(routingSettings.updatePreset(updated));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.saved),
      ),
    );
  }

  Future<void> _showTags({
    required String title,
    required List<String> tags,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = AppTheme.colors(dialogContext);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(24),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: tags.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          tag,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 15,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(tag),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    final current = _controller.text.trim();
    final lines = current
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (lines.contains(selected)) {
      return;
    }

    _controller.text = lines.isEmpty ? selected : '$current\n$selected';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;

    return SettingsPageShell(
      title: _title(l10n),
      onBack: () => Navigator.of(context).maybePop(),
      trailing: SettingsTextAction(
        label: l10n.save,
        onTap: _save,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionLabel(title: _subtitle(l10n).toUpperCase()),
            const SizedBox(height: 14),
            Container(
              height: 368,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.none,
                expands: true,
                maxLines: null,
                minLines: null,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: _placeholder(),
                  hintStyle: TextStyle(
                    color: colors.mutedText.withValues(alpha: 0.28),
                    fontSize: 16,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SettingsCard(
              children: [
                SettingsRow(
                  title: l10n.showGeositeTags,
                  trailing: Icon(
                    Icons.info_outline_rounded,
                    color: colors.chipSelected,
                    size: 18,
                  ),
                  onTap: () => _showTags(
                    title: l10n.geositeTagsTitle,
                    tags: RoutingSuggestions.geositeTags,
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  title: l10n.showGeoipTags,
                  trailing: Icon(
                    Icons.info_outline_rounded,
                    color: colors.chipSelected,
                    size: 18,
                  ),
                  onTap: () => _showTags(
                    title: l10n.geoipTagsTitle,
                    tags: RoutingSuggestions.geoipTags,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _currentRules(RoutingPresetConfig preset) {
    return switch (widget.kind) {
      RuleEditorKind.proxy => preset.proxyRules,
      RuleEditorKind.direct => preset.directRules,
      RuleEditorKind.block => preset.blockRules,
    };
  }

  String _title(AppLocalizations l10n) {
    return switch (widget.kind) {
      RuleEditorKind.proxy => l10n.throughProxy,
      RuleEditorKind.direct => l10n.direct,
      RuleEditorKind.block => l10n.block,
    };
  }

  String _subtitle(AppLocalizations l10n) {
    return switch (widget.kind) {
      RuleEditorKind.proxy => l10n.proxyRuleInputLabel,
      RuleEditorKind.direct => l10n.directRuleInputLabel,
      RuleEditorKind.block => l10n.blockRuleInputLabel,
    };
  }

  String _placeholder() {
    final preset = RoutingPresetConfig.defaultRu();
    return switch (widget.kind) {
      RuleEditorKind.proxy => preset.proxyRules,
      RuleEditorKind.direct => preset.directRules,
      RuleEditorKind.block => preset.blockRules,
    };
  }
}
